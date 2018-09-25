'''
Created on Sep, 25, 2018

@author: Liza Dayoub
'''

import hvac
import os 
from pathlib import Path
import subprocess

vault_addr = os.environ.get('VAULT_ADDR')
vault_token = os.environ.get('VAULT_TOKEN')
vault_path = os.environ.get("VAULT_PATH", 'secret/stack-testing/github')
if not vault_addr and not vault_token:
    raise IOError('Need VAULT_ADDR and VAULT_TOKEN environment variables set')
    exit(1)
vault_client = hvac.Client(url=vault_addr, token=vault_token)
if not vault_client.is_authenticated():
    raise IOError('Unable to authenticate to vault')
    exit(1)
creds = vault_client.read(vault_path)
os.chdir(str(Path(__file__).resolve().parent.parent.parent) + '/ci/cloud')
print(os.getcwd())
cmd = 'GH_OWNER=elastic GH_TOKEN=' + creds['data']['token'] + ' ./getJavaSdk.sh'
p = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True)
(output, err) = p.communicate()
p.wait()
print(output)
exit(p.returncode)
