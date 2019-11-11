# AIT environment settings
#
# @author: Liza Dayoub

export AIT_ROOTDIR=$(pwd)

export AIT_SCRIPTS=${AIT_ROOTDIR}/scripts
export PYTHONPATH="${PYTHONPATH}:${AIT_SCRIPTS}/python/lib"

export ANSIBLE_ROOTDIR=${AIT_ROOTDIR}/ansible
export ANSIBLE_CONFIG=${ANSIBLE_ROOTDIR}
export ANSIBLE_LIBRARY=${ANSIBLE_ROOTDIR}/library
export ANSIBLE_GROUP_VARS=${ANSIBLE_ROOTDIR}/group_vars
export ANSIBLE_HOST_VARS=${ANSIBLE_ROOTDIR}/host_vars
export ANSIBLE_ROLES=${ANSIBLE_ROOTDIR}/roles
export ANSIBLE_TEMPLATES=${ANSIBLE_ROOTDIR}/templates

export AIT_ANSIBLE_PLAYBOOK_DIR=${AIT_ROOTDIR}/playbooks
export AIT_VAGRANT_DIR=${AIT_ROOTDIR}/vm/vagrant
export AIT_VAGRANT_FILE=${AIT_VAGRANT_DIR}/Vagrantfile
export AIT_VM_INSTALL_DIR=/home/vagrant
export AIT_VM_WIN_INSTALL_DIR=c:/users/vagrant

export AIT_CI_CLOUD_DIR=${AIT_ROOTDIR}/ci/cloud
