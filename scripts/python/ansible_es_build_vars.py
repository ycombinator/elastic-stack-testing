'''
Created on Sep 14, 2017

@author: liza.dayoub@elastic.co
'''

import re
import yaml
import os

from es_build import ElasticStackBuild

def get_ansible_output(esb):
    ansible_vars = {}
    regex = re.compile('[a-z_]+_package_url')
    attrs = [x for x in ElasticStackBuild.__dict__.keys() if regex.search(x)]
    prefix = ''
    if esb.upgrade:
        prefix = 'upgrade_'
    if esb.extension:
        ansible_vars = {prefix + 'package_ext': esb.extension}
    for attr in attrs:
        value = getattr(esb, attr)
        if value:
            ansible_vars.update({prefix + attr: value})
    return ansible_vars

esb = ElasticStackBuild()
rootdir  = os.getenv('WORKSPACE', '/tmp')
with open(rootdir + '/vars.yml', 'w') as f:
    yaml.dump(get_ansible_output(esb), f, default_flow_style=False)

if os.getenv('UPGRADE_ES_BUILD_URL'):
    esb = ElasticStackBuild(upgrade=True)
    rootdir  = os.getenv('WORKSPACE', '/tmp')
    with open(rootdir + '/vars.yml', 'a') as f:
        yaml.dump(get_ansible_output(esb), f, default_flow_style=False)
