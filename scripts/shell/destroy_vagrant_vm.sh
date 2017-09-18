#!/bin/bash
#
# @author: liza.dayoub@elastic.co

ROOTDIR="/tmp"
if [ ! -z "$WORKSPACE" ]; then
    ROOTDIR="$WORKSPACE"
fi 

DEFAULT_VAGRANT_DIR=$ROOTDIR/$(basename "$ES_BUILD_VAGRANT_BOX")
if [ -z "${ES_BUILD_VAGRANT_DIR}" ]; then
    export ES_BUILD_VAGRANT_DIR="$DEFAULT_VAGRANT_DIR"
fi 

cd "$ES_BUILD_VAGRANT_DIR"
echo "$ES_BUILD_VAGRANT_DIR"

vagrant destroy -f
exit $?
