'''
Usage:
  python docs_compare.py /path/to/internal/docs /path/to/metricbeat/docs
'''

from docs_compare_util import check_parity

def handle_special_case_index_recovery(internal_doc, metricbeat_doc):
    # Normalize `index_recovery.shards` array field to have only one object in it.
    internal_doc["index_recovery"]["shards"] = [ internal_doc["index_recovery"]["shards"][0] ]
    metricbeat_doc["index_recovery"]["shards"] = [ metricbeat_doc["index_recovery"]["shards"][0] ]

def handle_special_case_node_stats(internal_doc, metricbeat_doc):
    # Metricbeat-indexed docs of `type:node_stats` fake the `source_node` field since its required
    # by the UI. However, it only fakes the `source_node.uuid`, `source_node.name`, and
    # `source_node.transport_address` fields since those are the only ones actually used by
    # the UI. So we normalize by removing all but those three fields from the internally-indexed
    # doc.
    source_node = internal_doc['source_node']
    internal_doc['source_node'] = {
      'uuid': source_node['uuid'],
      'name': source_node['name'],
      'transport_address': source_node['transport_address']
    }

def handle_special_case_shards(internal_doc, metricbeat_doc):
    # Metricbeat-indexed docs of `type:shard` fake the `source_node` field since its required
    # by the UI. However, it only fakes the `source_node.uuid` and `source_node.name` fields
    # since those are the only ones actually used by the UI. So we normalize by removing all
    # but those two fields from the internally-indexed doc.
    source_node = internal_doc['source_node']
    internal_doc['source_node'] = {
      'uuid': source_node['uuid'],
      'name': source_node['name']
    }

    # Internally-indexed docs of `type:shard` will set `shard.relocating_node` to `null`, if
    # the shard is not relocating. However, Metricbeat-indexed docs of `type:shard` will simply
    # not send the `shard.relocating_node` field if the shard is not relocating. So we normalize
    # by deleting the `shard.relocating_node` field from the internally-indexed doc if the shard
    # is not relocating.
    if 'relocating_node' in internal_doc['shard'] and internal_doc['shard']['relocating_node'] == None:
        internal_doc['shard'].pop('relocating_node')

def handle_special_cases(doc_type, internal_doc, metricbeat_doc):
    if doc_type == "index_recovery":
        handle_special_case_index_recovery(internal_doc, metricbeat_doc)
    if doc_type == 'node_stats':
        handle_special_case_node_stats(internal_doc, metricbeat_doc)
    if doc_type == 'shards':
        handle_special_case_shards(internal_doc, metricbeat_doc)

check_parity(handle_special_cases)
