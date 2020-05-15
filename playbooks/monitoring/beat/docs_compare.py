'''
Usage:
  python docs_compare.py /path/to/legacy/docs /path/to/metricbeat/docs
'''

from docs_compare_util import check_parity

def handle_special_case_beats_stats(legacy_doc, metricbeat_doc):
  # When Metricbeat monitors Filebeat, it encounters a different set of file IDs in 
  # `type:beats_stats` documents than when legacy collection monitors Filebeat. However,
  # we expect the _number_ of files being harvested by Filebeat in either case to match. 
  # If the numbers match we normalize the file lists in `type:beats_stats` docs collected
  # by both methods so their parity comparison succeeds.
  legacy_files = legacy_doc["beats_stats"]["metrics"]["filebeat"]["harvester"]["files"]
  metricbeat_files = metricbeat_doc["beats_stats"]["metrics"]["filebeat"]["harvester"]["files"]

  if len(legacy_files) != len(metricbeat_files):
    return

  legacy_doc["beats_stats"]["metrics"]["filebeat"]["harvester"]["files"] = []
  metricbeat_doc["beats_stats"]["metrics"]["filebeat"]["harvester"]["files"] = []

def handle_special_cases(doc_type, legacy_doc, metricbeat_doc):
  if doc_type == "beats_stats":
    handle_special_case_beats_stats(legacy_doc, metricbeat_doc)

check_parity(handle_special_cases)
