'''
Usage:
  python docs_compare.py /path/to/internal/docs /path/to/metricbeat/docs
'''

from docs_compare_util import *
from jsondiff import diff
import json

def handle_special_case_logstash_stats(internal_doc, metricbeat_doc):
    # Normalize `logstash_stats.pipelines[0].vertices` array in both docs to be sorted by vertex ID
    internal_doc["logstash_stats"]["pipelines"][0]["vertices"].sort(key=lambda pipeline: pipeline["id"])
    metricbeat_doc["logstash_stats"]["pipelines"][0]["vertices"].sort(key=lambda pipeline: pipeline["id"])

def handle_special_cases(doc_type, internal_doc, metricbeat_doc):
    if doc_type == "logstash_stats":
        handle_special_case_logstash_stats(internal_doc, metricbeat_doc)

check_usage()

internal_docs_path = get_internal_docs_path()
metricbeat_docs_path = get_metricbeat_docs_path()

internal_doc_types = get_doc_types(internal_docs_path)
metricbeat_doc_types = get_doc_types(metricbeat_docs_path)

check_num_doc_types(internal_doc_types, metricbeat_doc_types)

for doc_type in internal_doc_types:
    internal_doc = get_doc(internal_docs_path, doc_type)
    metricbeat_doc = get_doc(metricbeat_docs_path, doc_type)

    handle_special_cases(doc_type, internal_doc, metricbeat_doc)

    difference = diff(internal_doc, metricbeat_doc, syntax='explicit', marshal=True)

    # Expect there to be exactly seven top-level insertions to the metricbeat-indexed doc: service, beat, agent, @timestamp, host, event, and metricset
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