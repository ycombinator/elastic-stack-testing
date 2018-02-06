#!/bin/bash
#
# @author: Liza Dayoub

set +x
source ${AIT_SCRIPTS}/shell/lib/test_funcs.sh

pytest_integration_test test_basic_integration ${PYTEST_OPTS}
