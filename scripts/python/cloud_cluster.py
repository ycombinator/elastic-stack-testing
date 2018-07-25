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

    # ------------------------------------------------------------------------------------------------------------------
    # Constructor
    def __init__(self):
        vault_addr = os.environ.get('VAULT_ADDR')
        vault_token = os.environ.get('VAULT_TOKEN')
        vault_path = os.environ.get("VAULT_PATH", 'secret/stack-testing/cloud')
        if vault_addr and vault_token:
            vault_client = hvac.Client(url=vault_addr, token=vault_token)
            if vault_client.is_authenticated():
                creds = vault_client.read(vault_path)
                username = creds['data']['username']
                password = creds['data']['password']
        else:
            username = os.environ.get("ESTF_CLOUD_USERNAME")
            password = os.environ.get("ESTF_CLOUD_PASSWORD")

        host = os.environ.get("ESTF_CLOUD_HOST")
        version = os.environ.get("ESTF_CLOUD_VERSION")
        
        print('in python script debug:')
        print(vault_addr)
        print(vault_token)
        print(vault_addr)
        print(host)
        print(version)
        print(username)
        print(password)
        print('end debug')

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

    # ------------------------------------------------------------------------------------------------------------------
    # Create
    def create(self):
        data = self.client.create_cluster(self.plan)
        self.cluster_id = data['cluster_id']
        cluster = self.client.get_cluster_info(self.cluster_id)
        assert cluster['plan_info']['healthy']
        if self.monitoring:
            self.client.set_monitoring(self.cluster_id)
            cluster = self.client.get_cluster_info(self.cluster_id)
            assert self.cluster_id in cluster['elasticsearch_monitoring_info']['source_cluster_ids']
        return self.format_data(data)

    # ------------------------------------------------------------------------------------------------------------------
    # Format return data
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

    # ------------------------------------------------------------------------------------------------------------------
    # Shutdown
    def shutdown(self, cluster_id=None):
        if not cluster_id and getattr(self, 'cluster_id'):
            cluster_id = self.cluster_id
        if not cluster_id:
            raise ValueError('Cluster ID must be set')
        self.client.shutdown_cluster(cluster_id)

    # ------------------------------------------------------------------------------------------------------------------
    # Delete
    def delete(self, cluster_id=None):
        if not cluster_id and getattr(self, 'cluster_id'):
            cluster_id = self.cluster_id
        if not cluster_id:
            raise ValueError('Cluster ID must be set')
        self.client.delete_cluster(cluster_id)

    # ------------------------------------------------------------------------------------------------------------------
    # Create properties file
    def create_properties_file(self, cluster_data):
        cluster_id = cluster_data.get('cluster_id')
        if not cluster_id:
            raise ValueError('Data does not contain cluster_id')
        filename = self.get_filename(cluster_id)
        file = open(filename, "w")
        for key in cluster_data.keys():
            file.write(key + "=" + cluster_data[key] + "\n")
        file.close()
        return filename

    # ------------------------------------------------------------------------------------------------------------------
    # Delete properties file
    def delete_properties_file(self, cluster_id):
        filename = self.check_filename(cluster_id)
        if filename:
            os.remove(filename)
        else:
            print("[WARNING] Could not find file to delete for cluster_id: " + cluster_id)

    # ------------------------------------------------------------------------------------------------------------------
    # Get filename
    def get_filename(self, cluster_id, useCurrentDir=False):
        workspace = os.getenv('WORKSPACE')
        if not os.path.isdir(workspace) or useCurrentDir:
            workspace = os.getcwd()
        filename = workspace + '/' + cluster_id + ".properties"
        return filename

    # ------------------------------------------------------------------------------------------------------------------
    # Check filename
    def check_filename(self, cluster_id):
        file1 = self.get_filename(cluster_id)
        file2 = self.get_filename(cluster_id, True)
        if os.path.isfile(file1):
            return file1
        if os.path.isfile(file2):
            return file2
        return None

    # ------------------------------------------------------------------------------------------------------------------
    # Basic Plan
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


# ----------------------------------------------------------------------------------------------------------------------
def main(argv):

    help_msg = """cloud_cluster.py -c | -s <cluster_id> | -d <cluster_id>
        -c: create a cluster 
        -s <cluster_id>: shutdown a cluster using cluster id 
        -d <cluster_id>: delete a cluster using cluster id
    """

    try:
        opts, args = getopt.getopt(argv, "hcs:d:", ["create", "shutdown=", "delete="])
    except getopt.GetoptError:
        print(help_msg)
        sys.exit(2)

    if ('-c' in argv and len(argv) != 1) or len(argv) > 2:
        print(help_msg)
        sys.exit(2)

    for opt, arg in opts:
        if opt == '-h':
            print(help_msg)
            sys.exit()
        elif opt in ("-c", "--create"):
            print('\n******Create Cluster')
            cluster = CloudCluster()
            filename = cluster.create_properties_file(cluster.create())
            print("\ncloud_properties_file: " + filename)
        elif opt in ("-s", "--shutdown"):
            cluster_id = arg
            print('\n******Shutdown Cluster: ' + str(cluster_id))
            cluster = CloudCluster()
            cluster.shutdown(cluster_id)
        elif opt in ("-d", "--delete"):
            cluster_id = arg
            print('\n*****Delete Cluster: ' + str(cluster_id))
            cluster = CloudCluster()
            cluster.delete(cluster_id)
            cluster.delete_properties_file(cluster_id)

if __name__ == "__main__":
    main(sys.argv[1:])