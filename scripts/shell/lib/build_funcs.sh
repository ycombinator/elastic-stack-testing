#!/bin/bash
#
# Build shell functions
#
# @author: Liza Dayoub

source ${AIT_SCRIPTS}/shell/lib/logging_funcs.sh

# ----------------------------------------------------------------------------
running_in_jenkins() {
  if  [ -z $AIT_RUN_LOCAL ] || [ `whoami` == "jenkins" ]; then
    return 1
  fi
  return 0
}

# ----------------------------------------------------------------------------
export_env_vars() {
  # Export environment variables
  if [ ! -z "${AIT_ENV_VARS}" ]; then
    echo_info "Export environment variables"
    AIT_ENV_VARS="${AIT_ENV_VARS//$'\n'/ }"
    eval export "${AIT_ENV_VARS}"
  fi
  # If running in Jenkins, set to run headless browser
  running_in_jenkins
  RC=$?
  if [ $RC == 1 ]; then
    export AIT_RUN_HEADLESS_BROWSER=true
  fi

  # Added to get latest build from server
  if [ ! -z $ES_BUILD_SERVER ] && [ ! -z $ES_BUILD_BRANCH ]; then
    LATEST_BUILD_ID=$(curl -s https://artifacts-api.elastic.co/v1/branches/${ES_BUILD_BRANCH##*/}/builds/latest | jq -r .build.build_id)
    export ES_BUILD_URL="${ES_BUILD_SERVER}.elastic.co/$LATEST_BUILD_ID"
  fi

  # Added to support CI multi phase job
  # Note: Specific to elastic stack testing CI job
  if [ $CI_BUILD == "true" ] && [ $RC == 1 ]; then
    export ES_BUILD_OSS=$CI_OSS
    if [ $ES_BUILD_OSS == "true" ]; then
      export AIT_ANSIBLE_PLAYBOOK="${AIT_ROOTDIR}/playbooks/get_started/install_no_xpack.yml"
    else
      export AIT_ANSIBLE_PLAYBOOK="${AIT_ROOTDIR}/playbooks/get_started/install_xpack.yml"
    fi
    # This will eventually be added to the CI_ stuff
    export ES_BUILD_PKG_EXT=tar
    export AIT_VM=vagrant_vm
  fi

  env | sort

}

# ----------------------------------------------------------------------------
create_workspace() {
  # If running in Jenkins, return
  running_in_jenkins
  RC=$?
  if [ $RC == 1 ]; then
    return
  fi
  # If not running in Jenkins, create a local workspace
  if [ -z $WORKSPACE ]; then
    if [ ! -d ait_workspace ]; then
      mkdir ait_workspace
    fi
    export WORKSPACE=${AIT_ROOTDIR}/ait_workspace
  fi
}

# ----------------------------------------------------------------------------
check_env_workspace() {
  # If variable is empty, throw error and exit
  create_workspace
  if [ -z $WORKSPACE ]; then
    echo_error "Environment variable: WORKSPACE is not defined"
    exit 1
  fi
  export AIT_ANSIBLE_ES_VARS=${WORKSPACE}/vars.yml
}

# ----------------------------------------------------------------------------
check_env_vm() {
  # If variable is empty or points to a valid file, return
  if [ -z $AIT_VM ] || [ -f $AIT_VM ]; then
    return
  fi
  # Try to form a valid file, if not throw error and exit
  chk1=${AIT_SCRIPTS}/shell/${AIT_VM}
  chk2=${AIT_SCRIPTS}/shell/${AIT_VM}.sh
  if [ ! -z $chk1 ] && [ -f $chk1 ]; then
    export AIT_VM=$chk1
    return
  fi
  if [ ! -z $chk2 ] && [ -f $chk2 ]; then
    export AIT_VM=$chk2
    return
  fi
  echo_error "Invalid VM setup script: $AIT_VM, check directory ${AIT_SCRIPTS}/shell"
  exit 1
}

# ----------------------------------------------------------------------------
check_env_ansible_playbook() {
  # If running in Jenkins or variable is empty or points to a valid file, return
  running_in_jenkins
  RC=$?
  if [ $RC == 1 ] ||
     [ -z $AIT_ANSIBLE_PLAYBOOK ] || [ -f $AIT_ANSIBLE_PLAYBOOK ]; then
    return
  fi
  # Try to form a valid playbook, if not throw error and exit
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

# ----------------------------------------------------------------------------
check_env_tests() {
  # If variable is empty or points to a valid file, return
  if [ -z $AIT_TESTS ] || [ -f $AIT_TESTS ]; then
    return
  fi
  # Try to form a valid playbook, if not throw error and exit
  chk1=${AIT_SCRIPTS}/shell/${AIT_TESTS}
  chk2=${AIT_SCRIPTS}/shell/${AIT_TESTS}.sh
  chk3=${AIT_ROOTDIR}/tests/integration/tests/${AIT_TESTS}.py
  if [ ! -z $chk1 ] && [ -f $chk1 ]; then
    export AIT_TESTS=$chk1
    return
  fi
  if [ ! -z $chk2 ] && [ -f $chk2 ]; then
    export AIT_TESTS=$chk2
    return
  fi
  if [ ! -z $chk3 ] && [ -f $chk3 ]; then
    export AIT_TESTS=$chk3
    return
  fi
  echo_error "Invalid test script!"
  exit 1
}

# ----------------------------------------------------------------------------
check_python_virtual_env() {
  running_in_jenkins
  RC=$?
  if [ $RC == 1 ] && [ -z $PYENV_VIRTUALENV_INIT ] ||
     [ $RC == 0 ] && [ -z $VIRTUAL_ENV ]; then
    echo "Python virtual envrionment is not activated"
    exit 1
  fi
}

# ----------------------------------------------------------------------------
activate_python_virtual_env() {
  # If running in Jenkins, return
  running_in_jenkins
  RC=$?
  if [ $RC == 1 ]; then
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

# ----------------------------------------------------------------------------
python_install_packages() {
  type=$1; # cloud or empty
  check_python_virtual_env
  running_in_jenkins
  RC=$?
  if [ $RC == 1 ] && [ ! -z $PYENV_VIRTUALENV_INIT ]; then
    echo_info "Install python"
    pyver = $(cat .python-version)
    pyenv install -s $pyver
    pyenv global $pyver
  fi
  echo_info "Install python packages"
  if [ ! -z $type ] && [ "$type" == "cloud" ]; then
    echo_info "requirements_cloud.txt"
    pip install -r requirements_cloud.txt
  else
    echo_info "requirements.txt"
    pip install -r requirements.txt
   fi
  echo_info "List installed python packages"
  pip list
}

# ----------------------------------------------------------------------------
java_install_packages() {
  check_python_virtual_env
  echo_info "Install java sdk package"
  python ${AIT_SCRIPTS}/python/install_cloud_sdk.py
  RC=$?
  if [ $RC -ne 0 ]; then
    echo_error "FAILED! Java SDK not installed"
    exit 1
  fi
}

# ----------------------------------------------------------------------------
generate_build_variables() {
  # If skip variable set, return
  if [ ! -z $AIT_SKIP_GEN_BUILD_VARS ]; then
    return
  fi
  # If variables are empty, throw error and exit
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

# ----------------------------------------------------------------------------
run_vm() {
  action=$1; # provision
  if [ -z $action ]; then
    action="up"
  fi
  on_fail=$2; # exit or continue
  if [ -z $on_fail ]; then
    on_fail="exit"
  fi
  check_env_vm
  check_env_ansible_playbook
  # If variable is empty, return
  if [ -z $AIT_VM ]; then
    return
  fi
  # If not a valid file, throw an error and exit
  if [ ! -f $AIT_VM ]; then
    echo_error "Invalid file: $AIT_VM"
    exit 1
  fi
  # Run vm shell script
  echo_info "Run script: ${AIT_VM}"
  cd $(dirname $AIT_VM)
  $AIT_VM $action
  RC=$?
  # If vm fails, throw error and exit
  if [ $RC -ne 0 ]; then
    echo_error "VM failed!"
    if [ $on_fail == "exit" ] && ( [ $action == "up" ] || [ $action == "provision" ] ); then
      $AIT_VM save_snapshot_cleanup
      exit 1
    fi
  fi
}

# ----------------------------------------------------------------------------
run_ansible_playbook() {
  on_fail=$1; # exit or continue
  if [ -z $on_fail ]; then
    on_fail="exit"
  fi
  check_env_ansible_playbook
  # If running in Jenkins or AIT_VM is not empty or AIT_ANSIBLE_PLAYBOOK is empty, return
  running_in_jenkins
  RC=$?
  if [ $RC == 1 ] ||
     [ ! -z $AIT_VM ] || [ -z $AIT_ANSIBLE_PLAYBOOK ]; then
    return
  fi
  # If AIT_ANSIBLE_PLAYBOOK is not a file, throw error and exit
  if [ ! -f $AIT_ANSIBLE_PLAYBOOK ]; then
    echo_error "Invalid file: $AIT_ANSIBLE_PLAYBOOK"
    exit 1
  fi
  inventory_file=${WORKSPACE}/${AIT_HOST_INVENTORY_DIR}/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory
  if [ ! -f ${inventory_file} ]; then
    echo_error "Invalid file: ${inventory_file}"
    exit 1
  fi
  echo_info "Run playbook: ANSIBLE_GROUP_VARS=${WORKSPACE}/vars.yml AIT_UUT=aithost ansible-playbook -i ${inventory_file} ${AIT_ANSIBLE_PLAYBOOK}"
  cd $(dirname $AIT_ANSIBLE_PLAYBOOK)
  ANSIBLE_GROUP_VARS=${WORKSPACE}/vars.yml AIT_UUT=aithost ansible-playbook -i ${inventory_file} $AIT_ANSIBLE_PLAYBOOK
  RC=$?
  if [ $RC -ne 0 ]; then
    echo_error "Playbook failed!"
    if [ $on_fail == "exit" ]; then
      exit 1
    fi
  fi
}

# ----------------------------------------------------------------------------
run_tests() {
  on_fail=$1; # exit or continue
  if [ -z $on_fail ]; then
    on_fail="exit"
  fi
  check_env_vm
  check_env_tests
  # If variable is empty, then return
  if [ -z $AIT_TESTS ]; then
    return
  fi
  # If not a valid file, then throw error
  if [ ! -f $AIT_TESTS ]; then
    echo_error "Invalid file: $AIT_TESTS"
    exit 1
  fi
  # Run tests
  echo_info "Run script: ${AIT_TESTS}"
  cd $(dirname $AIT_TESTS)
  $AIT_TESTS
  RC=$?
  if [ $RC -ne 0 ]; then
    echo_error "Tests failed!"
    if [ $on_fail == "exit" ]; then
      if [ ! -z $AIT_VM ]; then
        $AIT_VM save_snapshot_cleanup
      fi
      exit 1
    fi
  fi
}

# ----------------------------------------------------------------------------
run_cloud_tests() {
  test_task=$1
  if [ -z $test_task ]; then
    echo_error "Gradle task name must be supplied"
    exit 1
  fi
  cd ${AIT_CI_CLOUD_DIR}
  ./gradlew $test_task
  RC=$?
  if [ $RC -ne 0 ]; then
    echo_error "Tests failed!"
    exit 1
  fi

}

deactivate_python_virtual_env() {
  # If running in Jenkins, return
  running_in_jenkins
  RC=$?
  if [ $RC == 1 ]; then
    return
  fi
  echo_info "Deactivate python venv"
  deactivate
}
