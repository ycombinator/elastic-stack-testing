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
  build='build'
  if [ ! -z $ES_BUILD_URL ]; then
      build=$(basename $ES_BUILD_URL)
      build="${build//\./-}"
  fi
  os='os'
  if [ ! -z $ES_BUILD_VAGRANT_BOX ]; then
      os=$(basename $ES_BUILD_VAGRANT_BOX)
  fi
  timestamp=$( date +%Y-%m-%d_%H-%M-%S )
  dirname=${build}_${os}_$(basename $AIT_ANSIBLE_PLAYBOOK | cut -f1 -d'.')
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
  vagrant destroy -f
  rc=$?
  if [ $rc != 0 ]; then
    exit $rc;
  fi
  vagrant up
  exit $?
}

vagrant_destroy() {
  goto_vagrant_directory
  vagrant destroy -f
  exit $?
}

get_random_port() {
  CHECK="do while"
  while [[ ! -z $CHECK ]]; do
    PORT=$(( ( RANDOM % 60000 )  + 1025 ))
    CHECK=$(netstat -an | grep $PORT)
  done
  return $PORT
}
