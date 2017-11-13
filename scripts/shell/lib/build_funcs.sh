#!/bin/bash
#
# Build shell functions
#
# @author: Liza Dayoub

source ${AIT_SCRIPTS}/shell/lib/logging_funcs.sh

check_workspace() {
  # Check if WORKSPACE env variable exists, exit if not
  if [ -z $WORKSPACE ]; then
    echo_error "Environment variable: WORKSPACE is not defined"
    exit 1
  fi
}

create_workspace() {
  # If not running in jenkins, create a local workspace
  if [ -z $ES_BUILD_LOCAL ] || [ `whoami` == "jenkins" ]; then
    return
  fi
  if [ -z $WORKSPACE ]; then
    if [ ! -d ait_workspace ]; then
      mkdir ait_workspace
    fi
    export WORKSPACE=${AIT_ROOTDIR}/ait_workspace
  fi
}

check_ansible_script() {
  # If not running in jenkins, standalone ansible mode
  if [ -z $ES_BUILD_LOCAL ] || [ `whoami` == "jenkins" ] ||
     [ -z $AIT_ANSIBLE_SCRIPT ] || [ -f $AIT_ANSIBLE_SCRIPT ]; then
    return
  fi
  chk1=${AIT_SCRIPTS}/shell/${AIT_ANSIBLE_SCRIPT}
  chk2=${AIT_SCRIPTS}/shell/${AIT_ANSIBLE_SCRIPT}.sh
  if [ ! -z $chk1 ] && [ -f $chk1 ]; then
    export AIT_ANSIBLE_SCRIPT=$chk1
    return
  fi
  if [ ! -z $chk2 ] && [ -f $chk2 ]; then
    export AIT_ANSIBLE_SCRIPT=$chk2
    return
  fi
  echo_error "Invalid build script!"
  exit 1
}

check_ansible_playbook() {
  # If not running in jenkins, standalone ansible mode
  if [ -z $ES_BUILD_LOCAL ] || [ `whoami` == "jenkins" ] ||
     [ -z $AIT_ANSIBLE_PLAYBOOK ] || [ -f $AIT_ANSIBLE_PLAYBOOK ]; then
    return
  fi
  chk1=${AIT_ANSIBLE_PLAYBOOK_DIR}/${AIT_ANSIBLE_PLAYBOOK}
  chk2=${AIT_ANSIBLE_PLAYBOOK_DIR}/${AIT_ANSIBLE_PLAYBOOK}.yml
  if [ ! -z $chk1 ] && [ -f $chk1 ]; then
    export AIT_ANSIBLE_PLAYBOOK=$chk1
    return
  fi
  if [ ! -z $chk2 ] && [ -f $chk2 ]; then
    export AIT_ANSIBLE_PLAYBOOK=$chk2
    return
  fi
  echo_error "Invalid ansible playbook!"
  exit 1
}

check_test_script() {
  # If not running in jenkins, standalone ansible mode
  if [ -z $ES_BUILD_LOCAL ] || [ `whoami` == "jenkins" ] ||
     [ -z $ES_BUILD_TEST_SCRIPT ] || [ -f $ES_BUILD_TEST_SCRIPT ]; then
    return
  fi
  chk1=${AIT_SCRIPTS}/shell/${ES_BUILD_TEST_SCRIPT}
  chk2=${AIT_SCRIPTS}/shell/${ES_BUILD_TEST_SCRIPT}.sh
  if [ ! -z $chk1 ] && [ -f $chk1 ]; then
    export ES_BUILD_TEST_SCRIPT=$chk1
    return
  fi
  if [ ! -z $chk2 ] && [ -f $chk2 ]; then
    export ES_BUILD_TEST_SCRIPT=$chk2
    return
  fi
  echo_error "Invalid test script!"
  exit 1
}

source_additional_env() {
  # Source additional environment variables
  if [ ! -z $ES_BUILD_ENV_SH ]; then
    echo_info "Source additional environment variables"
    source "${WORKSPACE}/ES_BUILD_ENV_SH"
  fi
}

activate_python_virtual_env() {
  # If not running in jenkins, activate python venv
  if [ -z $ES_BUILD_LOCAL ] || [ `whoami` == "jenkins" ]; then
    return
  fi
  echo_info "Create and activate python venv"
  export PYTHON_VENV_NAME=${WORKSPACE}/es-venv
  # Create python virtual env
  python3.6 -m venv ${PYTHON_VENV_NAME}
  # Activate env
  source ${PYTHON_VENV_NAME}/bin/activate
  echo_info "Python venv name: $PYTHON_VENV_NAME"
}

check_python_virtual_env() {
  # Check if you are in python virtual envrionment
  if [ -z $VIRTUAL_ENV ]; then
      echo_error "Python virtual envrionment is not activated"
      exit 1
  fi
}

python_install_packages() {
  check_python_virtual_env
  # Install required python packages
  echo_info "Install python packages"
  pip install -r requirements.txt
  echo_info "List installed python packages"
  pip list --format=columns
}

generate_package_variables() {
  # Pytest mode
  if [ ! -z $ES_BUILD_TEST_SCRIPT ]; then
    return
  fi
  if [ -z $ES_BUILD_URL ] || [ -z $ES_BUILD_PKG_EXT ]; then
    echo_error "ES_BUILD_URL and ES_BUILD_PKG_EXT can't be empty"
    exit 1
  fi
  # Create build vars file for ansible
  echo_info "Run script to build ansible variables from env"
  python ${AIT_SCRIPTS}/python/ansible_es_build_vars.py
  if [ $? -ne 0 ]; then
    echo_error "FAILED! Did not create ansible build variables!"
    exit 1
  fi
  export AIT_ANSIBLE_ES_VARS=${WORKSPACE}/vars.yml
  if [ ! -z $AIT_ANSIBLE_ES_VARS ] && [ ! -f $AIT_ANSIBLE_ES_VARS ]; then
    echo_error "Build variables file does not exist!"
    exit 1
  fi
  file_lines=`wc -l ${AIT_ANSIBLE_ES_VARS} | awk '{print $1}'`
  if [ $file_lines -le 1 ]; then
    echo_error "Build variables not all generated!"
    exit 1
  fi
}

run_test_script() {
  # Pytest mode
  if [ -z $ES_BUILD_TEST_SCRIPT ]; then
    return
  fi
  if [ ! -f $ES_BUILD_TEST_SCRIPT ]; then
    echo_error "Invalid file: $ES_BUILD_TEST_SCRIPT"
    exit 1
  fi
  echo_info "Run script: ${ES_BUILD_TEST_SCRIPT}"
  cd $(dirname $ES_BUILD_TEST_SCRIPT)
  $ES_BUILD_TEST_SCRIPT
  RC=$?
  if [ $RC -ne 0 ]; then
    echo_error "Script failed!"
    exit 1
  fi
}

run_ansible_script() {
  # Standalone ansible mode
  if [ ! -z $ES_BUILD_TEST_SCRIPT ] || [ -z $AIT_ANSIBLE_SCRIPT ]; then
    return
  fi
  if [ ! -f $AIT_ANSIBLE_SCRIPT ]; then
    echo_error "Invalid file: $AIT_ANSIBLE_SCRIPT"
    exit 1
  fi
  echo_info "Run script: ${AIT_ANSIBLE_SCRIPT}"
  cd $(dirname $AIT_ANSIBLE_SCRIPT)
  $AIT_ANSIBLE_SCRIPT
  RC=$?
  if [ $RC -ne 0 ]; then
    echo_error "Script failed!"
    exit 1
  fi
}

run_ansible_playbook() {
  # Standalone ansible mode
  if [ ! -z $AIT_ANSIBLE_SCRIPT ]; then
    return
  fi
  if [ ! -z $ES_BUILD_TEST_SCRIPT ] || [ -z $AIT_ANSIBLE_PLAYBOOK ]; then
    return
  fi
  if [ ! -f $AIT_ANSIBLE_PLAYBOOK ]; then
    echo_error "Invalid file: $AIT_ANSIBLE_PLAYBOOK"
    exit 1
  fi
  inventory_file=${WORKSPACE}/${AIT_HOST_INVENTORY_ROOTDIR}/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory
  echo_info "Run playbook: ANSIBLE_GROUP_VARS=${WORKSPACE}/vars.yml AIT_UUT=aithost ansible-playbook -i ${inventory_file} ${AIT_ANSIBLE_PLAYBOOK}"
  cd $(dirname $AIT_ANSIBLE_PLAYBOOK)
  ANSIBLE_GROUP_VARS=${WORKSPACE}/vars.yml AIT_UUT=aithost ansible-playbook -i ${inventory_file} $AIT_ANSIBLE_PLAYBOOK
  RC=$?
  if [ $RC -ne 0 ]; then
    echo_error "Playbook failed!"
    exit 1
  fi
}

deactivate_python_virtual_env() {
  # If not running in jenkins, deactivate python venv
  if [ -z $ES_BUILD_LOCAL ] || [ `whoami` == "jenkins" ]; then
    return
  fi
  echo_info "Deactivate python venv"
  deactivate
}
