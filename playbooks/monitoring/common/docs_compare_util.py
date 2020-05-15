import os
import sys
import json
import pprint
from dictdiffer import diff

allowed_insertions_in_metricbeat_docs = [
  # 'path.to.field'
  'service',
  '@timestamp',
  'agent',
  'event',
  'host',
  'ecs',
  'metricset'
]

allowed_deletions_from_metricbeat_docs = [
  # 'path.to.field'
  'source_node',
]

def log_ok(message):
    sys.stdout.write("OK: " + message + "\n")

def log_error(message):
    sys.stderr.write("ERROR: " + message + "\n")

def log_parity_error(message):
    log_error(message)
    
def check_usage():
  if (len(sys.argv) < 3):
      log_error("Usage: python docs_compare.py /path/to/legacy/docs /path/to/metricbeat/docs\n")
      sys.exit(1)

def get_legacy_docs_path():
  legacy_docs_path = sys.argv[1]
  if not os.path.exists(legacy_docs_path):
    log_error("Legacy-indexed documents path does not exist: " + legacy_docs_path + "\n")
    sys.exit(11)
  return legacy_docs_path

def get_metricbeat_docs_path():
  metricbeat_docs_path = sys.argv[2]
  if not os.path.exists(metricbeat_docs_path):
    log_error("Metricbeat-indexed documents path does not exist: " + metricbeat_docs_path + "\n")
    sys.exit(12)
  return metricbeat_docs_path

def get_doc_types(docs_path):
    files = os.listdir(docs_path)
    doc_types = []
    for doc_type_filename in (f for f in files if os.path.isfile(os.path.join(docs_path, f))):
        name, _ext = doc_type_filename.split('.')
        doc_types.append(name)
    return doc_types

def check_num_doc_types(legacy_doc_types, metricbeat_doc_types):
  if len(legacy_doc_types) > len(metricbeat_doc_types):
      diff_elements = set(legacy_doc_types) - set(metricbeat_doc_types)
      log_parity_error("Found more legacy-indexed document types than metricbeat-indexed document types.\n \
              Document types indexed by legacy collection but not by Metricbeat collection: {}".format(pprint.pformat(diff_elements)))

def get_doc(docs_path, doc_type):
    with open(os.path.join(docs_path, doc_type + ".json")) as f:
        data = f.read()
    return json.loads(data)

def remove_field(doc, field):
    field_path_segments = field.split(".")
    last_segment = field_path_segments.pop()

    d = doc
    for segment in field_path_segments:
        if segment in d:
            d = d[segment]

    d.pop(last_segment, None)

def remove_optional_fields(doc, fields):
    for field in fields:
        remove_field(doc, field)

def has_insertions_recursive(obj):
    obj_type = type(obj)

    if obj_type is dict:
        keys = obj.keys()
        if '$insert' in keys:
            return True

        for key in keys:
            if has_insertions_recursive(obj[key]):
                return True
    elif obj_type is list:
        for el in obj:
            if has_insertions_recursive(el):
                return True
    else:
        return False

def has_deletions_recursive(obj):
    obj_type = type(obj)

    if obj_type is dict:
        keys = obj.keys()
        if '$delete' in keys:
            return True

        for key in keys:
            if has_deletions_recursive(obj[key]):
                return True
    elif obj_type is list:
        for el in obj:
            if has_deletions_recursive(el):
                return True
    else:
        return False

def make_diff_path(diff_path):
  if isinstance(diff_path, list):
    path = ''
    for item in diff_path:
      path = path + '.' + str(item)
    return path.strip('.')
  else:
    return diff_path

def check_diff(diff_item, allowed_diffs_in_metricbeat_docs):
  unexpected_diff_paths = []

  diff_parent_path = make_diff_path(diff_item[1])
  diff_children = diff_item[2]

  for diff_child in diff_children:
    diff_path = diff_parent_path + '.' + str(diff_child[0])
    diff_path = diff_path.strip('.')

    if diff_path not in allowed_diffs_in_metricbeat_docs:
      unexpected_diff_paths.append(diff_path)

  return unexpected_diff_paths

def check_parity(handle_special_cases = lambda t, i, m: None, allowed_insertions_in_metricbeat_docs_extra = [], allowed_deletions_from_metricbeat_docs_extra = []):
  allowed_insertions_in_metricbeat_docs.extend(allowed_insertions_in_metricbeat_docs_extra)
  allowed_deletions_from_metricbeat_docs.extend(allowed_deletions_from_metricbeat_docs_extra)

  check_usage()

  legacy_docs_path = get_legacy_docs_path()
  metricbeat_docs_path = get_metricbeat_docs_path()

  legacy_doc_types = get_doc_types(legacy_docs_path)
  metricbeat_doc_types = get_doc_types(metricbeat_docs_path)

  check_num_doc_types(legacy_doc_types, metricbeat_doc_types)

  num_errors = 0
  for doc_type in legacy_doc_types:
      legacy_doc = get_doc(legacy_docs_path, doc_type)
      metricbeat_doc = get_doc(metricbeat_docs_path, doc_type)

      handle_special_cases(doc_type, legacy_doc, metricbeat_doc)

      unexpected_insertions = []
      unexpected_deletions = []
      for diff_item in diff(legacy_doc, metricbeat_doc):
        diff_type = diff_item[0]

        if diff_type == 'add':
          unexpected_insertions.extend(check_diff(diff_item, allowed_insertions_in_metricbeat_docs))

        if diff_type == 'remove':
          unexpected_deletions.extend(check_diff(diff_item, allowed_deletions_from_metricbeat_docs))

      if len(unexpected_insertions) == 0 and len(unexpected_deletions) == 0:
        log_ok("Metricbeat-indexed doc for type='" + doc_type + "' has expected parity with legacy-indexed doc.")
        continue

      if len(unexpected_insertions) > 0:
        for insertion in unexpected_insertions:
          log_parity_error("Metricbeat-indexed doc for type='" + doc_type + "' has unexpected insertion: " + insertion)
          num_errors = num_errors + 1

      if len(unexpected_deletions) > 0:
        for deletion in unexpected_deletions:
          log_parity_error("Metricbeat-indexed doc for type='" + doc_type + "' has unexpected deletion: " + deletion)
          num_errors = num_errors + 1

      print("*** Legacy-indexed doc for type='" + doc_type + "': ***")
      print(legacy_doc)

      print("*** Metricbeat-indexed doc for type='" + doc_type + "': ***")
      print(metricbeat_doc)

  if num_errors > 0:
      exit(100 + num_errors)
