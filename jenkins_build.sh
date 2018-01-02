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

create_workspace
check_workspace
source_additional_env
activate_python_virtual_env
python_install_packages
generate_package_variables
check_ansible_playbook
check_ansible_script
check_test_script
run_ansible_script
run_ansible_playbook
run_test_script
deactivate_python_virtual_env
# ----------------------------------------------------------------------------
