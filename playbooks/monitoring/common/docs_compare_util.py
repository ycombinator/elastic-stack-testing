import os
import sys
import json

def log_ok(message):
    sys.stdout.write("OK: " + message + "\n")

def log_error(message):
    sys.stderr.write("ERROR: " + message + "\n")

def log_parity_error(message):
    log_error(message)
    sys.exit(21)
    
def check_usage():
  if (len(sys.argv) < 3):
      log_error("Usage: python docs_compare.py /path/to/internal/docs /path/to/metricbeat/docs\n")
      sys.exit(1)

def get_internal_docs_path():
  internal_docs_path = sys.argv[1]
  if not os.path.exists(internal_docs_path):
    log_error("Internally-indexed documents path does not exist: " + internal_docs_path + "\n")
    sys.exit(11)
  return internal_docs_path

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

def check_num_doc_types(internal_doc_types, metricbeat_doc_types):
  if len(internal_doc_types) > len(metricbeat_doc_types):
      diff_elements = set(internal_doc_types) - set(metricbeat_doc_types)
      log_parity_error("Found more internally-indexed document types than metricbeat-indexed document types.\n \
              Document types indexed by internal collection but not by Metricbeat collection: {}".format(pprint.pformat(diff_elements)))

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

