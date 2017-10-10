#!/bin/bash

#----------------------------------------------------------
# Jenkins Job Shell: Integration Testing
# 
# Author: Liza Dayoub
#----------------------------------------------------------

echo "Jenkins Job: Integration Testing"

echo "Source aitenv.sh"
source aitenv.sh 

if [ -z "$WORKSPACE" ]; then
    echo "This script is for running within Jenkins"
    exit 1 
fi

if [ -z "$ES_BUILD_VAGRANT_BOX" ] && [ -z "$ES_BUILD_AWS_AMI" ]; then
    echo "NOTE! No Vagrant or AWS AMI was specified, defaulting to Vagrant/Ubuntu 16.04"
    export ES_BUILD_VAGRANT_BOX="elastic/ubuntu-16.04-x86_64"
fi

# Source additional environment variables 
if [ ! -z "$ES_BUILD_ENV_SH" ]; then
    echo "Source additional environment variables"
    source "${WORKSPACE}/ES_BUILD_ENV_SH"
fi

echo "Install python packages"
# Install packages
pip install -r requirements.txt
echo "List installed python packages"
pip list --format=columns

# Create build vars file for ansible
echo "Run script to build ansible variables from env"
python ${AIT_SCRIPTS}/python/ansible_es_build_vars.py

if [ $? -ne 0 ]; then
  echo "FAILED! Did not create ansible build variables!"
  exit 1
fi

echo "Create VM and run playbook to install/configure products under test"
if [ ! -z "$ES_BUILD_VAGRANT_BOX" ]; then
    ${AIT_SCRIPTS}/shell/start_vagrant_vm.sh
    INSTALL_EXIT_CODE=$?
elif [ ! -z "$ES_BUILD_AWS_AMI" ]; then
    # TODO: Add EC2 Launch
    echo "Not yet implemented, exiting" 
    exit 1
fi 

if [ ! -z $ES_BUILD_TESTS ]; then
    if [ ! -z $INSTALL_EXIT_CODE ] && [ $INSTALL_EXIT_CODE -eq 0 ]; then
        echo "Run Tests"
    fi
fi

echo "Destroy VM"
${AIT_SCRIPTS}/shell/destroy_vagrant_vm.sh

echo "Exit shell script"
if [ ! -z $INSTALL_EXIT_CODE ] && [ $INSTALL_EXIT_CODE -eq 0 ]; then
    if [ -z $ES_BUILD_TESTS ]; then
        exit 0
    fi
    if [ ! -z $TEST_EXIT_CODE ] && [ $TEST_EXIT_CODE -eq 0 ]; then
        exit 0 
    fi
fi
exit 1
