'''
Usage:
  python docs_compare.py /path/to/internal/docs /path/to/metricbeat/docs
'''
from docs_compare_util import check_parity

def handle_special_case_index_recovery(internal_doc, metricbeat_doc):
    # Normalize `index_recovery.shards` array field to have only one object in it.
    internal_doc["index_recovery"]["shards"] = [ internal_doc["index_recovery"]["shards"][0] ]
    metricbeat_doc["index_recovery"]["shards"] = [ metricbeat_doc["index_recovery"]["shards"][0] ]

def handle_special_case_cluster_stats(internal_doc, metricbeat_doc):
    # We expect the node ID to be different in the internally-collected vs. metricbeat-collected
    # docs because the tests spin up a fresh 1-node cluster prior to each type of collection.
    # So we normalize the node names.
    new_node_name = '__normalized__'

    orig_node_name = internal_doc['cluster_state']['master_node']
    internal_doc['cluster_state']['master_node'] = new_node_name
    internal_doc['cluster_state']['nodes'][new_node_name] = internal_doc['cluster_state']['nodes'][orig_node_name]
    del internal_doc['cluster_state']['nodes'][orig_node_name]

    orig_node_name = metricbeat_doc['cluster_state']['master_node']
    metricbeat_doc['cluster_state']['master_node'] = new_node_name
    metricbeat_doc['cluster_state']['nodes'][new_node_name] = metricbeat_doc['cluster_state']['nodes'][orig_node_name]
    del metricbeat_doc['cluster_state']['nodes'][orig_node_name]

    # When Metricbeat-based monitoring is used, Metricbeat will setup an ILM policy for
    # metricbeat-* indices. Obviously this policy is not present when internal monitoring is
    # used, since Metricbeat is not running in that case. So we normalize by removing the
    # usage stats associated with the Metricbeat-created ILM policy.
    policy_stats = metricbeat_doc["stack_stats"]["xpack"]["ilm"]["policy_stats"]

    # The Metricbeat ILM policy is the one with exactly one phase: hot
    new_policy_stats = []
    for policy_stat in policy_stats:
      policy_phases = list(policy_stat["phases"].keys())
      num_phases = len(policy_phases)
      if num_phases != 1:
        new_policy_stats.append(policy_stat)
        continue
      if policy_phases[0] != 'hot':
        new_policy_stats.append(policy_stat)
        continue

    metricbeat_doc["stack_stats"]["xpack"]["ilm"]["policy_stats"] = new_policy_stats
    metricbeat_doc["stack_stats"]["xpack"]["ilm"]["policy_count"] = len(new_policy_stats)

    # Metricbeat modules will automatically strip out keys that contain a null value
    # and `license.max_resource_units` is only available on certain license levels.
    # The `_cluster/stats` api will return a `null` entry for this key if the license level
    # does not have a `max_resouce_units` which causes Metricbeat to strip it out
    # If that happens, just assume parity between the two
    if 'max_resource_units' in internal_doc['license'] and internal_doc['license']['max_resource_units'] == None:
      internal_doc['license'].pop('max_resource_units')


    # The `field_types` field returns a list of what field types exist in all existing mappings
    # When running the parity tests, it is likely that the indices change between when we query
    # internally collected documents versus when we query Metricbeat collected documents. These
    # two may or may not match as a result. 
    # To get around this, we know that the parity tests query internally collected documents first
    # so we will ensure that all `field_types` that exist from that source also exist in the 
    # Metricbeat `field_types` (It is very likely the Metricbeat `field_types` will contain more)
    internal_contains_all_in_metricbeat = True
    for field_type in internal_doc["stack_stats"]["xpack"]["index"]["mappings"]["field_types"]:
      if not field_type in metricbeat_doc["stack_stats"]["xpack"]["index"]["mappings"]["field_types"]:
        internal_contains_all_in_metricbeat = False
        break
    
    if internal_contains_all_in_metricbeat:
      internal_doc["stack_stats"]["xpack"]["index"]["mappings"]["field_types"] = metricbeat_doc["stack_stats"]["xpack"]["index"]["mappings"]["field_types"]

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
    if doc_type == "cluster_stats":
        handle_special_case_cluster_stats(internal_doc, metricbeat_doc)
    if doc_type == 'node_stats':
        handle_special_case_node_stats(internal_doc, metricbeat_doc)
    if doc_type == 'shards':
        handle_special_case_shards(internal_doc, metricbeat_doc)

check_parity(handle_special_cases)