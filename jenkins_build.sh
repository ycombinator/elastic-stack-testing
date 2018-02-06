#!/bin/bash
#
# Jenkins shell script for elastic stack testing
#
# This script can also be run outside jenkins by running buildenv.sh
# which sets up local env variables then calls this script.
#
# @author: Liza Dayoub

# ----------------------------------------------------------------------------
set +x
source aitenv.sh
source ${AIT_SCRIPTS}/shell/lib/build_funcs.sh

export_env_vars
check_env_workspace
activate_python_virtual_env
python_install_packages
generate_build_variables
run_vm
run_ansible_playbook
run_tests
run_vm cleanup
deactivate_python_virtual_env
# ----------------------------------------------------------------------------
