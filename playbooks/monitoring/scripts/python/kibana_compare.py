'''
Usage:
  python kibana_compare.py /path/to/internal/docs /path/to/metricbeat/docs
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
    return data

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

if (len(sys.argv) < 3):
    sys.stderr.write("Usage: kibana_compare /path/to/internal/docs /path/to/metricbeat/docs\n")
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

    difference = diff(internal_doc, metricbeat_doc, syntax='explicit', load=True, marshal=True)

    # Expect there to be exactly one top-level deletion from metricbeat-indexed doc: source_node
    deletions = difference.get('$delete')
    if deletions == None or len(deletions) < 1:
        log_parity_error("Metricbeat-indexed doc for type='" + doc_type + "' has no deletions. Expected 'source_node' to be deleted.")

    if len(deletions) > 1:
        log_parity_error("Metricbeat-indexed doc for type='" + doc_type + "' has too many deletions: " + json.dumps(deletions))

    if deletions[0] != 'source_node':
        log_parity_error("Metricbeat-indexed doc for type='" + doc_type + "' does not have 'source_node' deleted.")

    difference.pop('$delete') 

    # Inserts and updates are okay in metricbeat-indexed docs, but deletions are not
    if has_deletions_recursive(difference):
        log_parity_error("Metricbeat-indexed doc for type='" + doc_type + "' has unexpected deletions. Difference: " + json.dumps(difference, indent=2))

    log_ok("Metricbeat-indexed doc for type='" + doc_type + "' has expected parity with internally-indexed doc.")