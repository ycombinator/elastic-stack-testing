#!/bin/bash
#
# Vagrant functions
#
# @author: Liza Dayoub

source ${AIT_SCRIPTS}/shell/lib/logging_funcs.sh

vagrant_create_directory() {
  if [ -z $AIT_ANSIBLE_PLAYBOOK ]; then
    echo_error "No playbook is defined"
    exit 1
  fi
  timestamp=$( date +%Y-%m-%d_%H-%M-%S )
  dirname=${timestamp}_$(basename $AIT_ANSIBLE_PLAYBOOK | cut -f1 -d'.')
  vagrant_dir=${WORKSPACE}/${dirname}
  mkdir ${vagrant_dir}
  cp ${AIT_VAGRANT_FILE} ${vagrant_dir}
  if [ $? -ne 0 ]; then
    echo_error "Error copying vagrantfile!"
    exit 1
  fi
  export AIT_VAGRANT_DIR=${vagrant_dir}
  export AIT_VAGRANT_FILE=${AIT_VAGRANT_DIR}/Vagrantfile
  echo_info "Using Vagrantfile: $AIT_VAGRANT_FILE"
}

goto_vagrant_directory() {
  if [ -z $AIT_VAGRANT_FILE ] || [ ! -f $AIT_VAGRANT_FILE ]; then
    echo_error "File not found: $AIT_VAGRANT_FILE"
    exit 1
  fi
  cd $(dirname $AIT_VAGRANT_FILE)
}

vagrant_up() {
  goto_vagrant_directory
  vagrant up
  exit $?
}

vagrant_destroy() {
  goto_vagrant_directory
  vagrant destroy -f
  exit $?
}
