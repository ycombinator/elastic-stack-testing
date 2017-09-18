#!/bin/bash
#
# @author: liza.dayoub@elastic.co

RUNNING_VMS=`VBoxManage list runningvms`
if [ ! -z "$RUNNING_VMS" ]; then
    echo "Another VM is running"
    exit 1
fi 

ROOTDIR="/tmp"
if [ ! -z "$WORKSPACE" ]; then
    ROOTDIR="$WORKSPACE"
fi 

VAGRANT_FILE="${AIT_ROOTDIR}/vm/vagrant/Vagrantfile"

DEFAULT_VAGRANT_BOX="elastic/ubuntu-16.04-x86_64"
if [ -z "${ES_BUILD_VAGRANT_BOX}" ]; then
    export ES_BUILD_VAGRANT_BOX="$DEFAULT_VAGRANT_BOX"
fi 

DEFAULT_VAGRANT_DIR=$ROOTDIR/$(basename "$ES_BUILD_VAGRANT_BOX")
if [ -z "${ES_BUILD_VAGRANT_DIR}" ]; then
    export ES_BUILD_VAGRANT_DIR="$DEFAULT_VAGRANT_DIR"
fi 

if [ ! -d "$ES_BUILD_VAGRANT_DIR" ]; then
    mkdir "$ES_BUILD_VAGRANT_DIR"
fi

cp "$VAGRANT_FILE" "$ES_BUILD_VAGRANT_DIR"
cd "$ES_BUILD_VAGRANT_DIR"
echo "$ES_BUILD_VAGRANT_DIR"

vagrant up 
exit $?
