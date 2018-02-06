#!/bin/bash
#
# @author: Liza Dayoub

set +x
source ${AIT_SCRIPTS}/shell/lib/vagrant_funcs.sh

vagrant_create_directory
if [ "$1" == "cleanup" ] && [ -z $AIT_SKIP_VM_CLEANUP ]; then
  vagrant_destroy
elif [ "$1" == "save_snapshot_cleanup" ] && [ -z $AIT_SKIP_VM_CLEANUP ]; then
  # TODO: add vagrant_save_snapshot
  vagrant_destroy
elif [ "$1" == "halt" ]; then
  vagrant_halt
elif [ "$1" == "provision" ]; then
  vagrant_provision
elif [ "$1" == "up" ]; then
  vagrant_up
else
  echo_warning "No vagrant vm action specified"
fi
