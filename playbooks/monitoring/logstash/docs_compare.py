'''
Usage:
  python docs_compare.py /path/to/internal/docs /path/to/metricbeat/docs
'''

from docs_compare_util import check_parity

def handle_special_case_logstash_stats(internal_doc, metricbeat_doc):
    # Normalize `logstash_stats.pipelines[0].vertices` array in both docs to be sorted by vertex ID
    internal_doc["logstash_stats"]["pipelines"][0]["vertices"].sort(key=lambda pipeline: pipeline["id"])
    metricbeat_doc["logstash_stats"]["pipelines"][0]["vertices"].sort(key=lambda pipeline: pipeline["id"])

def handle_special_cases(doc_type, internal_doc, metricbeat_doc):
    if doc_type == "logstash_stats":
        handle_special_case_logstash_stats(internal_doc, metricbeat_doc)

check_parity(handle_special_cases)
