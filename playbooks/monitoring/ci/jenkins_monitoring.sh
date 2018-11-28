#!/bin/bash
#
# @author: Liza Dayoub

# Build Type 
export ES_BUILD_OSS=false

# Build package extension
export ES_BUILD_PKG_EXT=tar

# Install package 
export AIT_ANSIBLE_PLAYBOOK="${AIT_ROOTDIR}/playbooks/monitoring/docs_parity.yml"

# Setup VM
export AIT_VM=vagrant_vm

source jenkins_build.sh
