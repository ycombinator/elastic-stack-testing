'''
Created on Apr, 19, 2018

@author: Liza Dayoub
'''

import pytest
import json
import os
import uuid
import hvac
import ast
import sys, getopt
from cloud_sdk_py.client import Client


class CloudCluster:

    def __init__(self):
        vault_addr = os.environ.get('VAULT_ADDR')
        vault_token = os.environ.get('VAULT_TOKEN')
        vault_path = os.environ.get("VAULT_PATH", 'secret/ui-team/estf/cloud')
        if vault_addr and vault_token:
            vault_client = hvac.Client(url=vault_addr)
            vault_client.auth_github(vault_token)
            if vault_client.is_authenticated():
                creds = vault_client.read(vault_path)
                username = creds['data']['username']
                password = creds['data']['password']
        else:
            username = os.environ.get("ESTF_CLOUD_USERNAME")
            password = os.environ.get("ESTF_CLOUD_PASSWORD")

        host = os.environ.get("ESTF_CLOUD_HOST")
        version = os.environ.get("ESTF_CLOUD_VERSION")

        if not host or not version or not username or not password:
            raise ValueError('Cloud host, version, username and password must be set')

        region = os.environ.get("ESTF_CLOUD_REGION", 'us-east-1')
        monitoring = ast.literal_eval(os.environ.get("ESTF_CLOUD_MONITORING", 'true').title())

        plan = json.loads(self.basic_plan(version))
        plan['cluster_name'] = 'ESTF_' + str(uuid.uuid4())
        client = Client(plan=plan, username=username, password=password, host=host, region=region)
        self.client = client
        self.monitoring = monitoring
        self.plan = plan
        self.version = version
        self.region = region

    def create(self):
        data = self.client.create_cluster(self.plan)
        self.cluster_id = data['cluster_id']
        cluster = self.client.get_cluster_info(self.cluster_id)
        assert cluster['plan_info']['healthy']
        if self.monitoring:
            self.client.set_monitoring(self.cluster_id)
            cluster = self.client.get_cluster_info(self.cluster_id)
            assert self.cluster_id in cluster['elasticsearch_monitoring_info']['destination_cluster_ids']
        return self.format_data(data)

    def basic_plan(self, version, mem=1024, zone=1):
        return json.dumps({
            "cluster_name": "",
            "plan": {
                "zone_count": zone,
                "cluster_topology": [
                    {
                        "node_configuration": "highio.legacy",
                        "node_count_per_zone": 1,
                        "memory_per_node": mem
                    }
                ],
                "elasticsearch": {
                    "include_default_plugins": True,
                    "enabled_built_in_plugins": [],
                    "user_bundles": [],
                    "user_plugins": [],
                    "system_settings": {
                        "auto_create_index": True,
                        "destructive_requires_name": False,
                        "scripting": {
                            "inline": {
                                "enabled": True
                            },
                            "stored": {
                                "enabled": True
                            }
                        }
                    },
                    "version": version
                }
            },
            "settings": {},
            "kibana": {
                "plan": {
                    "zone_count": zone,
                    "kibana": {},
                    "cluster_topology": [
                        {
                            "memory_per_node": mem,
                            "node_count_per_zone": 1
                        }
                    ]
                }
            }
        })

    def format_data(self, cluster_data):
        cluster_id = cluster_data['cluster_id']
        kibana_cluster_id = cluster_data['kibana_cluster_id']
        provider = 'aws.staging'
        if 'gcp' in self.region:
            provider = 'gcp'
        elasticsearch_url = 'https://{0}.{1}.{2}.foundit.no:9243'.format(cluster_id, self.region, provider)
        kibana_url ='https://{0}.{1}.{2}.foundit.no:9243'.format(kibana_cluster_id, self.region, provider)
        cluster_data.update({'elasticsearch_url': elasticsearch_url, 'kibana_url': kibana_url})
        return cluster_data

    def stop(self, cluster_id=None):
        if not cluster_id and getattr(self, 'cluster_id'):
            cluster_id = self.cluster_id
        if not cluster_id:
            raise ValueError('cluster id must be set')
        self.client.shutdown_cluster(cluster_id)

    def delete(self, cluster_id=None):
        if not cluster_id and getattr(self, 'cluster_id'):
            cluster_id = self.cluster_id
        if not cluster_id:
            raise ValueError('cluster id must be set')
        self.client.delete_cluster(cluster_id)

def main(argv):
    try:
        opts, args = getopt.getopt(argv, "hcd:", ["create", "stop=", "delete="])
    except getopt.GetoptError:
        print('cloud_cluster.py -c -s <cluster_id> -d <cluster_id>')
        sys.exit(2)
    print(opts)
    for opt, arg in opts:
        if opt == '-h':
            print('cloud_cluster.py -c -s <cluster_id> -d <cluster_id>')
            sys.exit()
        elif opt in ("-c", "--create"):
            print('Create Cluster')
            cluster = CloudCluster()
            print(cluster.create())
        elif opt in ("-s", "--stop"):
            cluster_id = arg
            print('Stop Cluster: ' + str(cluster_id))
            cluster = CloudCluster()
            cluster.stop(cluster_id)
        elif opt in ("-d", "--delete"):
            cluster_id = arg
            print('Delete Cluster: ' + str(cluster_id))
            cluster = CloudCluster()
            cluster.delete(cluster_id)

if __name__ == "__main__":
    main(sys.argv[1:])