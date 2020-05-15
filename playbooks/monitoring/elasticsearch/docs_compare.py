'''
Usage:
  python docs_compare.py /path/to/legacy/docs /path/to/metricbeat/docs
'''
from docs_compare_util import check_parity

def handle_special_case_index_recovery(legacy_doc, metricbeat_doc):
    # Normalize `index_recovery.shards` array field to have only one object in it.
    legacy_doc["index_recovery"]["shards"] = [ legacy_doc["index_recovery"]["shards"][0] ]
    metricbeat_doc["index_recovery"]["shards"] = [ metricbeat_doc["index_recovery"]["shards"][0] ]

def handle_special_case_cluster_stats(legacy_doc, metricbeat_doc):
    # We expect the node ID to be different in the legacy-collected vs. metricbeat-collected
    # docs because the tests spin up a fresh 1-node cluster prior to each type of collection.
    # So we normalize the node names.
    new_node_name = '__normalized__'

    orig_node_name = legacy_doc['cluster_state']['master_node']
    legacy_doc['cluster_state']['master_node'] = new_node_name
    legacy_doc['cluster_state']['nodes'][new_node_name] = legacy_doc['cluster_state']['nodes'][orig_node_name]
    del legacy_doc['cluster_state']['nodes'][orig_node_name]

    orig_node_name = metricbeat_doc['cluster_state']['master_node']
    metricbeat_doc['cluster_state']['master_node'] = new_node_name
    metricbeat_doc['cluster_state']['nodes'][new_node_name] = metricbeat_doc['cluster_state']['nodes'][orig_node_name]
    del metricbeat_doc['cluster_state']['nodes'][orig_node_name]

    # When Metricbeat-based monitoring is used, Metricbeat will setup an ILM policy for
    # metricbeat-* indices. Obviously this policy is not present when legacy monitoring is
    # used, since Metricbeat is not running in that case. So we normalize by removing the
    # usage stats associated with the Metricbeat-created ILM policy.
    policy_stats = metricbeat_doc["stack_stats"]["xpack"]["ilm"]["policy_stats"]

    new_policy_stats = []
    for policy_stat in policy_stats:
      policy_phases = list(policy_stat["phases"].keys())

      # This will capture the ILM policy introduced by running Metricbeat
      if len(policy_phases) == 1 and policy_phases[0] == 'hot' and policy_stat["indices_managed"] == 1:
        continue
      
      new_policy_stats.append(policy_stat)

    metricbeat_doc["stack_stats"]["xpack"]["ilm"]["policy_stats"] = new_policy_stats
    metricbeat_doc["stack_stats"]["xpack"]["ilm"]["policy_count"] = len(new_policy_stats)

    # Metricbeat modules will automatically strip out keys that contain a null value
    # and `license.max_resource_units` is only available on certain license levels.
    # The `_cluster/stats` api will return a `null` entry for this key if the license level
    # does not have a `max_resouce_units` which causes Metricbeat to strip it out
    # If that happens, just assume parity between the two
    if 'max_resource_units' in legacy_doc['license'] and legacy_doc['license']['max_resource_units'] == None:
      legacy_doc['license'].pop('max_resource_units')


    # The `field_types` field returns a list of what field types exist in all existing mappings
    # When running the parity tests, it is likely that the indices change between when we query
    # legacy collected documents versus when we query Metricbeat collected documents. These
    # two may or may not match as a result. 
    # To get around this, we know that the parity tests query legacy collected documents first
    # so we will ensure that all `field_types` that exist from that source also exist in the 
    # Metricbeat `field_types` (It is very likely the Metricbeat `field_types` will contain more)
    legacy_contains_all_in_metricbeat = True
    if 'cluster_stats' in legacy_doc:
      for field_type in legacy_doc["cluster_stats"]["indices"]["mappings"]["field_types"]:
        legacy_field_type_name = field_type["name"]
        found = False
        for field_type in metricbeat_doc["cluster_stats"]["indices"]["mappings"]["field_types"]:
          if field_type["name"] == legacy_field_type_name:
            found = True
        
        if (not found):
          legacy_contains_all_in_metricbeat = False
      
      if legacy_contains_all_in_metricbeat:
        legacy_doc["cluster_stats"]["indices"]["mappings"]["field_types"] = metricbeat_doc["cluster_stats"]["indices"]["mappings"]["field_types"]

def handle_special_case_node_stats(legacy_doc, metricbeat_doc):
    # Metricbeat-indexed docs of `type:node_stats` fake the `source_node` field since its required
    # by the UI. However, it only fakes the `source_node.uuid`, `source_node.name`, and
    # `source_node.transport_address` fields since those are the only ones actually used by
    # the UI. So we normalize by removing all but those three fields from the legacy-indexed
    # doc.
    source_node = legacy_doc['source_node']
    legacy_doc['source_node'] = {
      'uuid': source_node['uuid'],
      'name': source_node['name'],
      'transport_address': source_node['transport_address']
    }

def handle_special_case_shards(legacy_doc, metricbeat_doc):
    # Metricbeat-indexed docs of `type:shard` fake the `source_node` field since its required
    # by the UI. However, it only fakes the `source_node.uuid` and `source_node.name` fields
    # since those are the only ones actually used by the UI. So we normalize by removing all
    # but those two fields from the legacy-indexed doc.
    source_node = legacy_doc['source_node']
    legacy_doc['source_node'] = {
      'uuid': source_node['uuid'],
      'name': source_node['name']
    }

    # Legacy-indexed docs of `type:shard` will set `shard.relocating_node` to `null`, if
    # the shard is not relocating. However, Metricbeat-indexed docs of `type:shard` will simply
    # not send the `shard.relocating_node` field if the shard is not relocating. So we normalize
    # by deleting the `shard.relocating_node` field from the legacy-indexed doc if the shard
    # is not relocating.
    if 'relocating_node' in legacy_doc['shard'] and legacy_doc['shard']['relocating_node'] == None:
        legacy_doc['shard'].pop('relocating_node')

def handle_special_cases(doc_type, legacy_doc, metricbeat_doc):
    if doc_type == "index_recovery":
        handle_special_case_index_recovery(legacy_doc, metricbeat_doc)
    if doc_type == "cluster_stats":
        handle_special_case_cluster_stats(legacy_doc, metricbeat_doc)
    if doc_type == 'node_stats':
        handle_special_case_node_stats(legacy_doc, metricbeat_doc)
    if doc_type == 'shards':
        handle_special_case_shards(legacy_doc, metricbeat_doc)

check_parity(handle_special_cases)