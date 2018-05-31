#!/bin/bash
#
# Jenkins shell script for elastic stack testing for cloud provisioning
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
python_install_packages "cloud"
run_cloud_tests ${1}
deactivate_python_virtual_env
