#!/bin/bash
#
# Pytest tests functions
#
# @author: Liza Dayoub

source ${AIT_SCRIPTS}/shell/lib/logging_funcs.sh

# ----------------------------------------------------------------------------
pytest_integration_test() {
  test_name=$1
  opts=${@:2}
  test_dir=${AIT_ROOTDIR}/tests/integration/tests
  # If directory does not exist, throw error and exit
  if [ ! -d $test_dir ]; then
    echo_error "No such directory: $test_dir"
    exit 1
  fi
  # Goto directory
  cd $test_dir
  # Form file name, allow with/without .py ext, if file doesn't exist, throw error and exit
  chk1=${test_name}
  chk2=${test_name}.py
  if [ -f $chk1 ]; then
    test_file=$chk1
  elif [ -f $chk2 ]; then
    test_file=$chk2
  else
    echo_error "No such file: $test_file in directory: $test_dir"
    exit 1
  fi
  # Run pytest test file
  pytest $opts $test_file
}
