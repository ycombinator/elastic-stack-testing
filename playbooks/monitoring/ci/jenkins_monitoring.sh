#!/bin/bash
#
# @author: Liza Dayoub

# Build Type 
export ES_BUILD_OSS=false

# Build package extension
export ES_BUILD_PKG_EXT=tar

# Install package 
export AIT_ANSIBLE_PLAYBOOK="$(pwd)/playbooks/monitoring/${AIT_STACK_PRODUCT}/docs_parity.yml"

# Setup VM
export AIT_VM=vagrant_vm

source jenkins_build.sh
