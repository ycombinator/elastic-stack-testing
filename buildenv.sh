#!/bin/bash
#
# @author: Liza Dayoub

export AIT_RUN_LOCAL=true

export ES_BUILD_URL=staging.elastic.co/5.6.3-d64d30d8
export ES_BUILD_PKG_EXT=tar

export AIT_ANSIBLE_PLAYBOOK=install_no_xpack
export AIT_VM=setup_vagrant_vm

source jenkins_build.sh
