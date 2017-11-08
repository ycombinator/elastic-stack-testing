#!/bin/bash
#
# Pytest tests functions
#
# @author: Liza Dayoub

source ${AIT_SCRIPTS}/shell/lib/logging_funcs.sh

run_integration_tests() {
  cd ${AIT_ROOTDIR}/tests/integration/tests
  pytest -s $1.py
}
