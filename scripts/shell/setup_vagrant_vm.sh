#!/bin/bash
#
# @author: Liza Dayoub

set +x
source ${AIT_SCRIPTS}/shell/lib/vagrant_funcs.sh

vagrant_create_directory
vagrant_up
