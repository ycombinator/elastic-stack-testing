#!/bin/bash
#
# @author: Liza Dayoub

if [ $CI_BUILD == "true" ]; then
    export ES_BUILD_OSS=$CI_OSS
    if [ $ES_BUILD_OSS == "true" ]; then
      export AIT_ANSIBLE_PLAYBOOK="$(pwd)/playbooks/stack_testing/install_no_xpack.yml"
    else
      export AIT_ANSIBLE_PLAYBOOK="$(pwd)/playbooks/stack_testing/install_xpack.yml"
    fi
    # This will eventually be added to the CI_ stuff
    export ES_BUILD_PKG_EXT=tar
    export AIT_VM=vagrant_vm
fi

source jenkins_build.sh
