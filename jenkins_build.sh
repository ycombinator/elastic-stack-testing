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

echo "This is a stub test"

if [ ! -z "${AIT_ENV_VARS}" ]; then
  echo_info "Export environment variables"
  eval export "${AIT_ENV_VARS}"
fi

echo_info $ES_BUILD_URL
echo_error $ES_BUILD_PKG_EXT
echo_warning $AIT_TEST_SUITE

echo "End test"
# ----------------------------------------------------------------------------
