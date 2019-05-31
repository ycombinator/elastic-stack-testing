#!/bin/bash
#
# @author: Liza Dayoub

# When set, we are running locally not in Jenkins
export AIT_RUN_LOCAL=true

# Build URL
export ES_BUILD_URL=

# Build Type 
export ES_BUILD_OSS=false

# Build package extension
export ES_BUILD_PKG_EXT=tar

# Install package 
export AIT_ANSIBLE_PLAYBOOK=monitoring/${AIT_STACK_PRODUCT}/docs_parity

# Setup VM
export AIT_VM=vagrant_vm

# Skip destroying the VM 
export AIT_SKIP_VM_CLEANUP=true

source jenkins_build.sh
