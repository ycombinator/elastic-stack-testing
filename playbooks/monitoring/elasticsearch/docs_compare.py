'''
Usage:
  python docs_compare.py /path/to/internal/docs /path/to/metricbeat/docs
'''

import os
import sys
from jsondiff import diff
import json

def get_doc_types(docs_path):
    files = os.listdir(docs_path)
    doc_types = []
    for doc_type_filename in (f for f in files if os.path.isfile(os.path.join(docs_path, f))):
        name, ext = doc_type_filename.split('.')
        doc_types.append(name)
    return doc_types

def get_doc(docs_path, doc_type):
    with open(os.path.join(docs_path, doc_type + ".json")) as f:
        data = f.read()
    f.closed
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

def log_ok(message):
    sys.stdout.write("OK: " + message + "\n")

def log_error(message):
    sys.stderr.write("ERROR: " + message + "\n")

def log_parity_error(message):
    log_error(message)
    sys.exit(11)

def handle_special_case_index_recovery(internal_doc, metricbeat_doc):
    # Normalize `index_recovery.shards` array field to have only one object in it.
    internal_doc["index_recovery"]["shards"] = [ internal_doc["index_recovery"]["shards"][0] ]
    metricbeat_doc["index_recovery"]["shards"] = [ metricbeat_doc["index_recovery"]["shards"][0] ]

def handle_special_cases(doc_type, internal_doc, metricbeat_doc):
    if doc_type == "index_recovery":
        handle_special_case_index_recovery(internal_doc, metricbeat_doc)


if (len(sys.argv) < 3):
    sys.stderr.write("Usage: docs_compare /path/to/internal/docs /path/to/metricbeat/docs\n")
    sys.exit(1)

internal_docs_path = sys.argv[1]
metricbeat_docs_path = sys.argv[2]

if not os.path.exists(internal_docs_path):
    sys.stderr.write("Internally-indexed documents path does not exist: " + internal_docs_path + "\n")
    sys.exit(2)

if not os.path.exists(metricbeat_docs_path):
    sys.stderr.write("Metricbeat-indexed documents path does not exist: " + metricbeat_docs_path + "\n")
    sys.exit(3)

internal_doc_types = get_doc_types(internal_docs_path)
metricbeat_doc_types = get_doc_types(metricbeat_docs_path)

if len(internal_doc_types) > len(metricbeat_doc_types):
    log_parity_error("Found more internally-indexed document types than metricbeat-indexed document types")

for doc_type in internal_doc_types:
    internal_doc = get_doc(internal_docs_path, doc_type)
    metricbeat_doc = get_doc(metricbeat_docs_path, doc_type)

    handle_special_cases(doc_type, internal_doc, metricbeat_doc)

    difference = diff(internal_doc, metricbeat_doc, syntax='explicit', marshal=True)

    # Expect there to be exactly seven top-level insertions to the metricbeat-indexed doc: service, ecs, agent, @timestamp, host, event, and metricset
    allowed_insertions = [ "service", "ecs", "agent", "@timestamp", "host", "event", "metricset" ]
    insertions = difference.get('$insert')
    if insertions == None or len(insertions) < 1:
        log_parity_error("Metricbeat-indexed doc for type='" + doc_type + "' has no insertions. Expected 'beat', '@timestamp', 'host', and 'metricset' to be inserted.")

    if len(insertions) > len(allowed_insertions):
        log_parity_error("Metricbeat-indexed doc for type='" + doc_type + "' has too many insertions: " + json.dumps(insertions))

    difference.pop('$insert') 

    # Expect there to be exactly one top-level deletion from metricbeat-indexed doc: source_node
    deletions = difference.get('$delete')
    if deletions == None or len(deletions) < 1:
        log_parity_error("Metricbeat-indexed doc for type='" + doc_type + "' has no deletions. Expected 'source_node' to be deleted.")

    if len(deletions) > 1:
        log_parity_error("Metricbeat-indexed doc for type='" + doc_type + "' has too many deletions: " + json.dumps(deletions))

    if deletions[0] != 'source_node':
        log_parity_error("Metricbeat-indexed doc for type='" + doc_type + "' does not have 'source_node' deleted.")

    difference.pop('$delete') 

    # Updates are okay in metricbeat-indexed docs, but insertions and deletions are not
    if has_insertions_recursive(difference):
        log_parity_error("Metricbeat-indexed doc for type='" + doc_type + "' has unexpected insertions. Difference: " + json.dumps(difference, indent=2))

    if has_deletions_recursive(difference):
        log_parity_error("Metricbeat-indexed doc for type='" + doc_type + "' has unexpected deletions. Difference: " + json.dumps(difference, indent=2))

    log_ok("Metricbeat-indexed doc for type='" + doc_type + "' has expected parity with internally-indexed doc.")