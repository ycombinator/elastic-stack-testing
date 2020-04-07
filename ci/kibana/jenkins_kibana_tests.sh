#!/usr/bin/env bash

# ----------------------------------------------------------------------------
#
# Functions to:
#  - Download and install kibana archive: .zip or .tar.gz
#  - Download and install node and yarn
#  - Kibana bootstrap
#  - Run Kibana tests: unit, selenium and xpack
#  - Logging functions
#
# Author: Liza Dayoub
#
# ----------------------------------------------------------------------------

###
### Since the Jenkins logging output collector doesn't look like a TTY
### Node/Chalk and other color libs disable their color output. But Jenkins
### can handle color fine, so this forces https://github.com/chalk/supports-color
### to enable color support in Chalk and other related modules.
###
export FORCE_COLOR=1

NC='\033[0m' # No Color
WHITE='\033[1;37m'
BLACK='\033[0;30m'
BLUE='\033[0;34m'
LIGHT_BLUE='\033[1;34m'
GREEN='\033[0;32m'
LIGHT_GREEN='\033[1;32m'
CYAN='\033[0;36m'
LIGHT_CYAN='\033[1;36m'
RED='\033[0;31m'
LIGHT_RED='\033[1;31m'
PURPLE='\033[0;35m'
LIGHT_PURPLE='\033[1;35m'
BROWN='\033[0;33m'
YELLOW='\033[1;33m'
GRAY='\033[0;30m'
LIGHT_GRAY='\033[0;37m'

if [ -z $COLOR_LOGS ] || ([ ! -z $COLOR_LOGS ] && $COLOR_LOGS); then
    export COLOR_LOGS=true
fi

Glb_Cache_Dir="${CACHE_DIR:-"$HOME/.kibana"}"
readonly Glb_Cache_Dir

# For static Jenkins nodes
Glb_KbnBootStrapped="no"
Glb_KbnClean="no"

# *****************************************************************************
# SECTION: Logging functions
# *****************************************************************************

# ----------------------------------------------------------------------------
# Method to get date timestamp
# ----------------------------------------------------------------------------
function date_timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

# ----------------------------------------------------------------------------
# Method to print error message
# ----------------------------------------------------------------------------
function echo_error() {
  if [ ${COLOR_LOGS} == true ]; then
    echo -e ${RED}"["$(date_timestamp)"] [ERROR] $1" ${NC}
  else
    echo -e "["$(date_timestamp)"] [ERROR] $1"
  fi
}

# ----------------------------------------------------------------------------
# Method to print error message and exit with error status
# -----------------------------------------------------------------------------
function echo_error_exit() {
  echo_error "$1"
  exit 1
}

# ----------------------------------------------------------------------------
# Method to print warning message
# ----------------------------------------------------------------------------
function echo_warning() {
  if [ ${COLOR_LOGS} == true ]; then
    echo -e ${YELLOW}"["$(date_timestamp)"] [WARNING] $1" ${NC}
  else
    echo -e "["$(date_timestamp)"] [WARNING] $1"
  fi
}

# ----------------------------------------------------------------------------
# Method to print info message
# ----------------------------------------------------------------------------
function echo_info() {
  if [ ${COLOR_LOGS} == true ]; then
    echo -e ${LIGHT_BLUE}"["$(date_timestamp)"] [INFO] $1" ${NC}
  else
    echo -e "["$(date_timestamp)"] [INFO] $1"
  fi
}

# ----------------------------------------------------------------------------
# Method to print debug message
# ----------------------------------------------------------------------------
function echo_debug() {
  if [ ${COLOR_LOGS} == true ]; then
    echo -e ${GRAY}"["$(date_timestamp)"] [DEBUG] $1" ${NC}
  else
    echo -e "["$(date_timestamp)"] [DEBUG] $1"
  fi
}

# ----------------------------------------------------------------------------
# Method to exit script
# ----------------------------------------------------------------------------
function exit_script() {
  rc=${1:-0}
  msg=$2

  if [ $rc -ne 0 ]; then
    echo_error_exit $msg
  fi
  exit
}

# ----------------------------------------------------------------------------
# Method to exit script
# ----------------------------------------------------------------------------
function check_status_ok() {
    [[ "${*}" =~ ^(0 )*0$ ]]
    return
}

# ****************************************************************************
# SECTION: Kibana CI setup functions
# ****************************************************************************

# ----------------------------------------------------------------------------
# Method to create Kibana build install directory
# ----------------------------------------------------------------------------
function create_kbn_install_dir() {
  if [ ! -z $Glb_Install_Dir ]; then
    return
  fi
  Glb_Install_Dir="$(pwd)/kibana-build"
  mkdir -p "$Glb_Install_Dir"
  readonly Glb_Install_Dir
}

# ----------------------------------------------------------------------------
# Method to remove Kibana build install directory
# ----------------------------------------------------------------------------
function remove_kbn_install_dir() {
  if [ ! -d $Glb_Install_Dir ]; then
    return
  fi
  rm -rf "$Glb_Install_Dir"
}

# ----------------------------------------------------------------------------
# Method to remove es build install directory
# ----------------------------------------------------------------------------
function remove_es_install_dir() {
  local esdir="$(pwd)/.es"

  if [ ! -d $esdir ]; then
    return
  fi
  rm -rf $esdir
}

# ----------------------------------------------------------------------------
# Method to remove node_modules directory
# ----------------------------------------------------------------------------
function remove_node_modules_dir() {
  local dir="$(pwd)/node_modules"

  if [ ! -d $dir ]; then
    return
  fi
  rm -rf $dir
}

# ----------------------------------------------------------------------------
# Method to get build server: snapshots
# ----------------------------------------------------------------------------
function get_build_server() {
  if [ ! -z $Glb_Build_Server ]; then
    return
  fi
  Glb_Build_Server="${TEST_BUILD_SERVER:-"snapshots"}"
  if ! [[ "$Glb_Build_Server" =~ ^(snapshots)$ ]]; then
    echo_error_exit "Invalid build server: $Glb_Build_Server"
  fi
  readonly Glb_Build_Server
}

# ----------------------------------------------------------------------------
# Method to get version from Kibana package.json file
# ----------------------------------------------------------------------------
function get_version() {
  if [ ! -z $Glb_Kibana_Version ]; then
    return
  fi
  local _pkgVersion=$(cat package.json | \
                      grep "\"version\"" | \
                      cut -d ':' -f 2 | \
                      tr -d ",\"\ +" | \
                      xargs)

  Glb_Kibana_Version=${TEST_KIBANA_VERSION:-${_pkgVersion}}

  if [[ -z "$Glb_Kibana_Version" ]]; then
    echo_error_exit "Kibana version can't be empty"
  fi

  if [[ "$Glb_Build_Server" == "snapshots" ]]; then
    Glb_Kibana_Version="${Glb_Kibana_Version}-SNAPSHOT"
  fi

  readonly Glb_Kibana_Version
}

# ----------------------------------------------------------------------------
# Method to get OS
# ----------------------------------------------------------------------------
function get_os() {
  if [ ! -z $Glb_OS ]; then
    return
  fi
  local _uname=$(uname)
  echo_debug "Uname: $_uname"
  if [[ "$_uname" = *"MINGW64_NT"* ]]; then
    Glb_OS="windows"
  elif [[ "$_uname" = "Darwin" ]]; then
    Glb_OS="darwin"
    #TODO: remove later
    Glb_KbnClean="yes"
  elif [[ "$_uname" = "Linux" ]]; then
    Glb_OS="linux"
  else
    echo_error_exit "Unknown OS: $_uname"
  fi

  echo_info "Running on OS: $Glb_OS"

  readonly Glb_OS
}

# ----------------------------------------------------------------------------
# Method to get Kibana package
# ----------------------------------------------------------------------------
function get_kibana_pkg() {

  if [ ! -z $Glb_Pkg_Name ]; then
    return
  fi

  # Get if oss packages are available
  local _splitStr=(${Glb_Kibana_Version//./ })
  local _version=${_splitStr[0]}.${_splitStr[1]}
  local _isOssSupported=$(echo "$_version 6.3" | awk '{print ($1 >= $2)}')

  # Package type
  local _pkgType="${TEST_KIBANA_BUILD:-"oss"}"
  if ! [[ "$_pkgType" =~ ^(oss|default)$ ]]; then
    echo_error_exit "Unknown build type: $_pkgType"
  fi
  if [[ "$_pkgType" == "oss" && $_isOssSupported == 1 ]]; then
    _pkgType="-oss"
  else
    _pkgType=""
  fi

  # OS and package name
  local _pkgName=""

  if [[ "$Glb_OS" = "windows" ]]; then
    if [[ $_isOssSupported == 1 ]]; then
      _pkgName="windows-x86_64.zip"
    else
      _pkgName="windows-x86.zip"
    fi
  elif [[ "$Glb_OS" = "darwin" ]]; then
    _pkgName="darwin-x86_64.tar.gz"
  elif [[ "$Glb_OS" = "linux" ]]; then
    _pkgName="linux-x86_64.tar.gz"
  else
    echo_error_exit "Unknown OS: $Glb_OS"
  fi

  Glb_Pkg_Name="kibana${_pkgType}-${Glb_Kibana_Version}-${_pkgName}"
  Glb_Es_Pkg_Name="elasticsearch${_pkgType}-${Glb_Kibana_Version}-${_pkgName}"

  readonly Glb_Pkg_Name Glb_Es_Pkg_Name
}

# ----------------------------------------------------------------------------
# Method to check if Kibana package URL exists
# ----------------------------------------------------------------------------
function get_kibana_url() {

  if [ ! -z $Glb_Kibana_Url ]; then
    return
  fi

  local _host="https://${Glb_Build_Server}.elastic.co"
  local _path="downloads/kibana"
  local _es_path="downloads/elasticsearch"

  Glb_Kibana_Url="$_host/$_path/$Glb_Pkg_Name"

  local _urlExists=$(curl --head -f "${Glb_Kibana_Url}"; echo $?)
  if [[ $_urlExists -ne 0 ]]; then
    echo_error_exit "URL does not exist: $Glb_Kibana_Url"
  fi

  echo_info "Kibana URL: $Glb_Kibana_Url"

  # Set the elasticsearch snapshot for functional tests
  Glb_Es_Url="$_host/$_es_path/$Glb_Es_Pkg_Name"
  export KBN_ES_SNAPSHOT_URL="$Glb_Es_Url"
  echo_info "Elasticsearch URL: $Glb_Es_Url"

  readonly Glb_Kibana_Url Glb_Es_Url
}

# ----------------------------------------------------------------------------
# Method to download and extract Kibana package
# ----------------------------------------------------------------------------
function download_and_extract_package() {
  if [ ! -z $Glb_Kibana_Dir ]; then
    return
  fi

  echo_info "Kibana root build install dir: $Glb_Install_Dir"
  echo_info "KibanaUrl from $Glb_Kibana_Url"

  local _pkgName="$Glb_Install_Dir/${Glb_Kibana_Url##*/}"
  local _dirName=""
  if [[ -z $TEST_SKIP_KIBANA_INSTALL ]]; then
    curl --silent -o $_pkgName $Glb_Kibana_Url
  fi
  if [[ "$Glb_OS" == "windows" ]]; then
    _dirName=$(zipinfo -1 "$_pkgName" | head -n 1)
  else
    _dirName=$(tar tf "$_pkgName" | head -n 1)
  fi
  _dirName=${_dirName%%/*}

  Glb_Kibana_Dir="$Glb_Install_Dir/$_dirName"
  if [ -d "$Glb_Kibana_Dir" ]; then
      if [[ -z $TEST_SKIP_KIBANA_INSTALL ]]; then
        echo_info "Clearing previous Kibana install"
        rm -rf "$Glb_Kibana_Dir"
      fi
  fi

  if [[ -z $TEST_SKIP_KIBANA_INSTALL ]]; then
    if [[ "$Glb_OS" == "windows" ]]; then
      unzip -qo "$_pkgName" -d "$Glb_Install_Dir"
    else
      tar xfz "$_pkgName" -C "$Glb_Install_Dir"
    fi
  fi

  if [[ ! -z $TEST_SKIP_KIBANA_INSTALL ]]; then
    if [ ! -d "$Glb_Kibana_Dir" ]; then
      echo_error_exit "Kibana directory does not exist"
    fi
  fi

  echo_info  "Using Kibana install: $Glb_Kibana_Dir"

  if [[ "$Glb_OS" == "windows" ]]; then
    export JAVA_HOME="c:\Users\jenkins\.java\java11"
  else
    export JAVA_HOME="/var/lib/jenkins/.java/java11"
  fi

  readonly Glb_Kibana_Dir
}

# -----------------------------------------------------------------------------
# Method to check if in Kibana repo
# -----------------------------------------------------------------------------
function in_kibana_repo() {
  local _dir="$(pwd)"
  if [ ! -f "$_dir/package.json" ] || [ ! -f "$_dir/.node-version" ]; then
    echo_error_exit "CI setup must be run within a Kibana repo"
  fi

  check_test_files

  git checkout test
  git checkout x-pack/test
  git checkout .yarnrc
}

# -----------------------------------------------------------------------------
# Method to install node
# -----------------------------------------------------------------------------
function install_node() {
  local _dir="$(pwd)"
  local _nodeVersion="$(cat $_dir/.node-version)"
  local _nodeDir="$Glb_Cache_Dir/node/$_nodeVersion"
  local _nodeBin=""
  local _nodeUrl=""

  if [[ "$Glb_OS" == "windows" ]]; then
    # This variable must be set in the user path - done in jenkins
    _nodeBin="$HOME/node"
    _nodeUrl="https://nodejs.org/dist/v$_nodeVersion/node-v$_nodeVersion-win-x64.zip"
  elif [[ "$Glb_OS" == "darwin" ]]; then
    _nodeBin="$_nodeDir/bin"
    _nodeUrl="https://nodejs.org/dist/v$_nodeVersion/node-v$_nodeVersion-darwin-x64.tar.gz"
  elif [[ "$Glb_OS" == "linux" ]]; then
    _nodeBin="$_nodeDir/bin"
    _nodeUrl="https://nodejs.org/dist/v$_nodeVersion/node-v$_nodeVersion-linux-x64.tar.gz"
  else
    echo_error_exit "Unknown OS: $Glb_OS"
  fi

  echo_info "Node: version=v${_nodeVersion} dir=${_nodeDir}"

  echo_info "Setting up node.js"
  if [ -x "$_nodeBin/node" ] && [ "$($_nodeBin/node --version)" == "v$_nodeVersion" ]; then
    echo_info "Reusing node.js install"
  else
    if [ -d "$_nodeDir" ]; then
      echo_info "Clearing previous node.js install"
      rm -rf "$_nodeDir"
    fi

    echo_info "Downloading node.js from $_nodeUrl"
    mkdir -p "$_nodeDir"
    if [[ "$Glb_OS" == "windows" ]]; then
      local _nodePkg="$_nodeDir/${_nodeUrl##*/}"
      curl --silent -o $_nodePkg $_nodeUrl
      unzip -qo $_nodePkg -d $_nodeDir
      mv "${_nodePkg%.*}" "$_nodeBin"
    else
      curl --silent "$_nodeUrl" | tar -xz -C "$_nodeDir" --strip-components=1
    fi
  fi

  echo_debug "Node bin is here: "
  echo_debug $(ls $_nodeBin)
  export PATH="$_nodeBin:$PATH"
  hash -r

  echo_debug "Node is here: "
  if [[ "$Glb_OS" == "windows" ]]; then
    echo_debug $(where node)
  else
    echo_debug $(which node)
  fi
  echo_debug "$PATH"
}

# -----------------------------------------------------------------------------
# Method to install yarn
# -----------------------------------------------------------------------------
function install_yarn() {
  echo_info "Installing yarn"
  local _yarnVersion="$(node -e "console.log(String(require('./package.json').engines.yarn || '').replace(/^[^\d]+/,''))")"
  npm install -g yarn@^${_yarnVersion}

  #local _yarnDir="$Glb_Cache_Dir/yarn/$_yarnVersion"
  #export PATH="$_yarnDir/bin:$PATH"
  local _yarnGlobalDir="$(yarn global bin)"
  export PATH="$PATH:$_yarnGlobalDir"
  hash -r

  echo_debug "Yarn is here: "
  if [[ "$Glb_OS" == "windows" ]]; then
    echo_debug $(where node)
  else
    echo_debug $(which node)
  fi
}

# ----------------------------------------------------------------------------
# Method to bootstrap
# ----------------------------------------------------------------------------
function yarn_kbn_bootstrap() {
  echo_info "Installing node.js dependencies"
  #yarn config set cache-folder "$Glb_Cache_Dir/yarn"

  if $Glb_ChromeDriverHack; then
    echo_warning "Temporary update package.json bump chromedriver."
    sed -i 's/"chromedriver": "^76.0.0"/"chromedriver": "^75.1.0"/g' package.json
  fi

  # For windows testing
  Glb_YarnNetworkTimeout=$(grep "network-timeout" .yarnrc | wc -l)
  if [ $Glb_YarnNetworkTimeout -eq 0 ]; then
    echo "network-timeout 600000" >> .yarnrc
  fi

  yarn kbn bootstrap --prefer-offline

  if [ $? -ne 0 ]; then
    echo_error_exit "yarn kbn bootstrap failed!"
  fi

  Glb_KbnBootStrapped="yes"
}

# ----------------------------------------------------------------------------
# Method to run kbn clean
# ----------------------------------------------------------------------------
function yarn_kbn_clean() {
  echo_info "In yarn_kbn_clean"

  if [ $Glb_KbnBootStrapped == "yes" ]; then
    yarn kbn clean
  fi
}

# ----------------------------------------------------------------------------
# Method to check if any files changed during bootstraping
# ----------------------------------------------------------------------------
function check_git_changes() {
  local _git_changes

  _git_changes="$(git ls-files --modified | grep -Ev "yarn.lock")"

  if $Glb_ChromeDriverHack; then
    echo_warning "Temporary package.json modified for chromedriver."
    _git_changes="$(git ls-files --modified | grep -Ev "package.json|yarn.lock")"
  fi
  if [ $Glb_YarnNetworkTimeout -eq 0 ]; then
    echo_warning "Modified network timeout in .yarnrc"
    _git_changes="$(git ls-files --modified | grep -Ev ".yarnrc")"
  fi
  if [ "$_git_changes" ]; then
    echo_error_exit "'yarn kbn bootstrap' caused changes to the following files:\n$_git_changes"
  fi
}

# -----------------------------------------------------------------------------
# Method to setup CI environment
# -----------------------------------------------------------------------------
function run_ci_setup() {
  if [[ ! -z $TEST_SKIP_CI_SETUP ]]; then
    return
  fi
  get_os
  in_kibana_repo
  install_node
  install_yarn
  yarn_kbn_bootstrap
  check_git_changes
}

# -----------------------------------------------------------------------------
# Method to cleanup CI environment
# -----------------------------------------------------------------------------
function run_ci_cleanup() {
  if [ $Glb_KbnClean == "yes" ]; then
    remove_node_modules_dir
    remove_kbn_install_dir
    remove_es_install_dir
  fi
}

# -----------------------------------------------------------------------------
# Method to install Kibana
# -----------------------------------------------------------------------------
function install_kibana() {
  create_kbn_install_dir
  get_build_server
  get_version
  get_os
  get_kibana_pkg
  get_kibana_url
  download_and_extract_package
}

# *****************************************************************************
# SECTION: Percy visual testing functions
# *****************************************************************************

# -----------------------------------------------------------------------------
# Method to set percy target branch
# -----------------------------------------------------------------------------
function set_percy_target_branch() {
  export PERCY_TARGET_BRANCH=$(git branch | grep \* | cut -d ' ' -f2)
  export PERCY_BRANCH=$PERCY_TARGET_BRANCH
}

# -----------------------------------------------------------------------------
# Method to copy oss visual tests into Kibana repo
# -----------------------------------------------------------------------------
function cp_visual_tests() {
  # Get files
  git submodule -b $(basename $branch_specifier) add https://github.com/elastic/kibana-visual-tests
  if [ $? -ne 0 ]; then
    echo_error_exit "Submodule checkout failed!"
  fi
  cp -rf kibana-visual-tests/test/visual_regression test
  git rm -f kibana-visual-tests
  git rm -f .gitmodules
  rm -rf .git/modules/kibana-visual-tests/
}

# -----------------------------------------------------------------------------
# Method to copy xpack visual tests into Kibana repo
# -----------------------------------------------------------------------------
function cp_xpack_visual_tests() {
  # Get files
  git submodule -b $(basename $branch_specifier) add https://github.com/elastic/kibana-visual-tests
  if [ $? -ne 0 ]; then
    echo_error_exit "Submodule checkout failed!"
  fi
  cp -rf kibana-visual-tests/x-pack/test/visual_regression x-pack/test
  git rm -f kibana-visual-tests
  git rm -f .gitmodules
  rm -rf .git/modules/kibana-visual-tests/
}

# ----------------------------------------------------------------------------
# Get Percy version from package.json file
# ----------------------------------------------------------------------------
function check_percy_pkg() {
  local _percyVersion=$(cat package.json | \
                        grep "percy" | \
                        cut -d ':' -f 2 | \
                        tr -d "^,\"\ +" | \
                        xargs)

  if [[ -z "$_percyVersion" ]]; then
    echo "No percy package available"
    exit 1
  fi
}

# *****************************************************************************
# SECTION: Running test functions
# *****************************************************************************

# -----------------------------------------------------------------------------
# Method to set kibana version from build specifier for flaky test runner
# -----------------------------------------------------------------------------
function check_kibana_version() {
   if [ -z $ESTF_KIBANA_VERSION ]; then
    echo_error_exit "ESTF_KIBANA_VERSION can't be empty!"
  fi
}

# -----------------------------------------------------------------------------
# Method to check clodu version for flaky test runner
# -----------------------------------------------------------------------------
function check_cloud_version() {
  if [ -z $ESTF_CLOUD_VERSION ]; then
    echo_error_exit "ESTF_CLOUD_VERSION can't be empty!"
  fi
}

# -----------------------------------------------------------------------------
# Method to check test suite values are all in one group
# -----------------------------------------------------------------------------
function _check_array_vals_eq() {
    arr=("$@")
    if [ ${#arr[@]} -eq 0 ]; then
      echo_error_exit "ESTF_FLAKY_TEST_SUITE is empty or is not in proper format"
    elif awk 'v && $1!=v{ exit 1 }{ v=$1 }' <(printf "%s\n" "${arr[@]}"); then
      echo_info "Test Suite Group: ${arr[0]}"
    else
      echo_error_exit "ESTF_FLAKY_TEST_SUITE can not have mixed values: oss, xpack, xpackExt"
    fi
}

# -----------------------------------------------------------------------------
# Method to check test suite for flaky test runner
# -----------------------------------------------------------------------------
function check_test_suite() {
  IFS='
  '
  types=()
  for item in $ESTF_FLAKY_TEST_SUITE
  do
    testSuiteRoot=${item%%/*}
    if [[ "$testSuiteRoot" == "test" ]] ||
       [[ "$testSuiteRoot" == *"ossGrp"* ]]; then
      types+=( "oss" )
    elif [[ "$testSuiteRoot" == "x-pack" ]]; then
      if [[ "$item" != *"/functional/"* ]]; then
        types+=( "xpackExt" )
      else
        types+=( "xpack" )
      fi
    elif [[ "$testSuiteRoot" == *"xpackGrp"* ]]; then
      types+=( "xpack" )
    elif  [[ "$testSuiteRoot" == *"xpackExt"* ]]; then
      types+=( "xpackExt" )
    fi
  done

  _check_array_vals_eq "${types[@]}"
}

# -----------------------------------------------------------------------------
# Method to set test suite for flaky test runner
# -----------------------------------------------------------------------------
function set_test_group() {
  export ESTF_TEST_GROUP="${ESTF_FLAKY_TEST_SUITE%%/*}"
}

# -----------------------------------------------------------------------------
# Method to check number of executions for flaky test runner
# -----------------------------------------------------------------------------
function check_number_executions() {
  ESTF_NUMBER_EXECUTIONS=$( expr $ESTF_NUMBER_EXECUTIONS + 0 )
  re='^[0-9]+$'
  if ! [[ $ESTF_NUMBER_EXECUTIONS =~ $re ]] ; then
    echo_error_exit "ESTF_NUMBER_EXECUTIONS is not a number!"
  fi
}

# -----------------------------------------------------------------------------
# Method to set number of executions for flaky test runner
# -----------------------------------------------------------------------------
function set_number_executions_deployments() {
  # Apply min and max
  if [ $ESTF_NUMBER_EXECUTIONS -lt 0 ]; then
    ESTF_NUMBER_EXECUTIONS=1
  fi

  if [ $ESTF_NUMBER_EXECUTIONS -gt 40 ]; then
    ESTF_NUMBER_EXECUTIONS=40
  fi

  ESTF_NUMBER_DEPLOYMENTS=1
  if [ $ESTF_NUMBER_EXECUTIONS -gt 20 ]; then
    ESTF_NUMBER_DEPLOYMENTS=2
  fi

  ESTF_NUMBER_EXECUTIONS=$(($ESTF_NUMBER_EXECUTIONS / $ESTF_NUMBER_DEPLOYMENTS))

  export ESTF_NUMBER_EXECUTIONS
  export ESTF_NUMBER_DEPLOYMENTS

  echo_debug "ESTF_NUMBER_EXECUTIONS: $ESTF_NUMBER_EXECUTIONS"
  echo_debug "ESTF_NUMBER_DEPLOYMENTS: $ESTF_NUMBER_DEPLOYMENTS"
}

# -----------------------------------------------------------------------------
# Method to check test type for flaky test runner
# -----------------------------------------------------------------------------
function check_test_type() {
  # Get the type of test to run
  if [ -z $ESTF_TEST_PLATFORM ]; then
    echo_error_exit "ESTF_TEST_PLATFORM can't be empty!"
  fi

  valid_platforms=()
  valid_platforms+=('saas')
  # TODO: add eck and ece later
  if [[ " ${valid_platforms[*]} " != *"$ESTF_TEST_PLATFORM"* ]]; then
    echo_error_exit "Invalid ESTF_TEST_PLATFORM, must be one of $valid_platforms"
  fi
}

# -----------------------------------------------------------------------------
# Method create job file for flaky test runner
# -----------------------------------------------------------------------------
function create_matrix_job_file() {
  local matrixJobDir="${JENKINS_HOME:-ci/kibana/jobs}"
  local matrixJobFile="$matrixJobDir/flaky_jobs.yml"

  if [ ! -d $matrixJobDir ]; then
    echo_error_exit "Matrix job directory does not exist!"
  fi

  echo "TASK:" > $matrixJobFile
  echo "  - ${ESTF_TEST_PLATFORM}_run_kibana_tests" >> $matrixJobFile
  echo "JOB: " >> $matrixJobFile
  for i in $(seq 1 1 $ESTF_NUMBER_DEPLOYMENTS); do
    echo "  - flakyRun$i" >> $matrixJobFile
  done
  echo "exclude: ~" >> $matrixJobFile
}

# -----------------------------------------------------------------------------
# Method to get test file
# -----------------------------------------------------------------------------
function get_test_file() {
  local item=$1

  testFile=""
  if [ -d "$item" ]; then
    if [ -f "$item/index.js" ]; then
      testFile="$item/index.js"
    elif [ -f "$item/index.ts" ]; then
      testFile="$item/index.ts"
    fi
  elif [ -f "$item" ]; then
    testFile=$item
  fi
  echo $testFile
}

# -----------------------------------------------------------------------------
# Method to check test files and directories exist
# This can be files or top level feature directories.
# TODO: Add test/<extended tests>
# Examples:
#   test/functional/<feature>
#   test/functional/<feature>/<file>
#   x-pack/test/functional/<feature>
#   x-pack/test/functional/<feature>/<file>
#   x-pack/test/<extended test>/<feature>
#   x-pack/test/<extended test>/<feature>/<file>
#   test/functional
#   x-pack/functional
# -----------------------------------------------------------------------------
function check_test_files() {
  IFS='
  '
  errors=0
  for item in $ESTF_FLAKY_TEST_SUITE
  do
    testFile=$(get_test_file $item)
    if [ -z $testFile ]; then
      echo_error "File does not exist: $item!"
      errors=1
    fi
  done
  if [ $errors -eq 1 ]; then
    echo_error_exit "ESTF_FLAKY_TEST_SUITE not all paths are valid!"
  fi
}

# -----------------------------------------------------------------------------
# Method to run flaky test runner cloud prechecks
# -----------------------------------------------------------------------------
function flaky_test_runner_cloud_prechecks() {
  check_kibana_version
  check_cloud_version
  check_test_suite
  check_number_executions
  set_number_executions_deployments
  check_test_type
  create_matrix_job_file
}

# -----------------------------------------------------------------------------
# Method to run flaky Kibana tests
# TODO: Add eck, ece and on-prem
# (Mainly for functional UI tests)
# -----------------------------------------------------------------------------
function flaky_test_runner() {
  echo_info "In flaky_test_runner"

  cloud_platforms=()
  cloud_platforms+=('saas')
  cloud_platforms+=('ece')
  cloud_platforms+=('eck')

  set_test_group
  set_number_executions_deployments

  # If just the top level directory is specified to run whole
  # suite, then set extended group
  if [[ $ESTF_TEST_GROUP == "x-pack" ]] &&
     [[ "$ESTF_FLAKY_TEST_SUITE" != *"/functional"* ]]; then
    ESTF_TEST_GROUP=xpackext
  fi

  if [[ " ${cloud_platforms[*]} " == *"$ESTF_TEST_PLATFORM"* ]]; then
    PLATFORM=cloud
  fi

  echo_debug "ESTF_TEST_GROUP: $ESTF_TEST_GROUP"
  echo_debug "ESTF_TEST_PLATFORM: $ESTF_TEST_PLATFORM"
  echo_debug "ESTF_FLAKY_TEST_SUITE: $ESTF_FLAKY_TEST_SUITE"

  case "$ESTF_TEST_GROUP" in
    oss|test)
      if [ $PLATFORM == "cloud" ]; then
        run_cloud_oss_tests
      else
        run_oss_tests
      fi
      ;;
    xpack|x-pack)
      if [ $PLATFORM == "cloud" ]; then
        run_cloud_xpack_func_tests
      else
        run_xpack_func_tests
      fi
      ;;
    xpackext)
      if [ $PLATFORM == "cloud" ]; then
        run_cloud_xpack_ext_tests
      else
        run_xpack_ext_tests
      fi
      ;;
    ossGrp*)
      if [ $PLATFORM == "cloud" ]; then
        run_cloud_oss_tests $ESTF_TEST_GROUP
      else
        run_oss_tests $ESTF_TEST_GROUP
      fi
      ;;
    xpackGrp*)
      if [ $PLATFORM == "cloud" ]; then
        run_cloud_xpack_func_tests $ESTF_TEST_GROUP
      else
        run_xpack_func_tests $ESTF_TEST_GROUP
      fi
      ;;
    xpackExt*)
      if [ $PLATFORM == "cloud" ]; then
        run_cloud_xpack_ext_tests
      else
        run_xpack_ext_tests false $ESTF_TEST_GROUP
      fi
      ;;
    *)
      echo_error_exit "ESTF_TEST_GROUP '$ESTF_TEST_GROUP' is invalid group"
      ;;
  esac

  echo "DONE!"
}

# -----------------------------------------------------------------------------
# Method to run Kibana unit tests
# -----------------------------------------------------------------------------
function run_unit_tests() {
  echo_info "In run_unit_tests"

  run_ci_setup

  export TEST_ES_FROM=snapshot
  export TEST_BROWSER_HEADLESS=1

  echo_info " -> Running unit tests"
  "$(FORCE_COLOR=0 yarn bin)/grunt" jenkins:unit --from=${TEST_ES_FROM};
  RC=$?

  run_ci_cleanup

  exit_script $RC "Unit tests failed"
}

# -----------------------------------------------------------------------------
# Method to run Kibana xpack unit tests
# -----------------------------------------------------------------------------
function run_xpack_unit_tests() {
  echo_info "In run_xpack_unit_tests"

  run_ci_setup

  export TEST_ES_FROM=snapshot
  export TEST_BROWSER_HEADLESS=1

  local _xpack_dir="$(cd x-pack; pwd)"
  echo_info "-> XPACK_DIR ${_xpack_dir}"
  cd "$_xpack_dir"

  echo " -> Running mocha tests"
  yarn test
  echo ""
  echo ""
  RC1=$?

  echo " -> Running jest tests"
  node scripts/jest --ci --verbose
  echo ""
  echo ""
  RC2=$?

  echo " -> Running SIEM cyclic dependency test"
  cd "$XPACK_DIR"
  node legacy/plugins/siem/scripts/check_circular_deps
  echo ""
  echo ""
  RC3=$?

  echo " -> Running jest contracts tests"
  cd "$XPACK_DIR"
  node scripts/jest_contract.js --ci --verbose
  echo ""
  echo ""
  RC4=$?

  # echo " -> Running jest integration tests"
  # node scripts/jest_integration --ci --verbose
  # echo ""
  # echo ""

  run_ci_cleanup

  rclist=($RC1 $RC2 $RC3 $RC4)

  check_status_ok ${rclist[*]} && exit_script || exit_script 1 "X-pack unit test failed!"
}

# -----------------------------------------------------------------------------
# Method to run oss tests from Kibana repo, ones in test/ directory
# -----------------------------------------------------------------------------
function run_oss_tests() {
  echo_info "In run_oss_tests"
  local testGrp=$1
  local maxRuns="${ESTF_NUMBER_EXECUTIONS:-1}"

  run_ci_setup

  includeTags=$(update_config "test/functional/config.js" $testGrp)
  update_test_files

  TEST_KIBANA_BUILD=oss
  install_kibana

  export TEST_BROWSER_HEADLESS=1

  failures=0
  for i in $(seq 1 1 $maxRuns); do
    export ESTF_RUN_NUMBER=$i
    update_report_name "test/functional/config.js"

    echo_info " -> Running oss functional tests, run $i of $maxRuns"
    eval node scripts/functional_tests \
          --esFrom snapshot \
          --kibana-install-dir=${Glb_Kibana_Dir} \
          --config test/functional/config.js \
          --debug " $includeTags" \
          -- --server.maxPayloadBytes=1679958
    if [ $? -ne 0 ]; then
      failures=1
    fi
  done

  run_ci_cleanup

  exit_script $failures "OSS Test failed!"
}

# -----------------------------------------------------------------------------
# Method to run x-pack tests from Kibana repo, ones in x-pack/test/ directory
# -----------------------------------------------------------------------------
function run_xpack_func_tests() {
  echo_info "In run_xpack_func_tests"
  local testGrp=$1
  local maxRuns="${ESTF_NUMBER_EXECUTIONS:-1}"

  run_ci_setup

  includeTags=$(update_config "x-pack/test/functional/config.js" $testGrp)
  update_test_files

  TEST_KIBANA_BUILD=default
  install_kibana

  local _xpack_dir="$(cd x-pack; pwd)"
  echo_info "-> XPACK_DIR ${_xpack_dir}"
  cd "$_xpack_dir"

  export TEST_BROWSER_HEADLESS=1

  failures=0
  for i in $(seq 1 1 $maxRuns); do
    export ESTF_RUN_NUMBER=$i
    update_report_name "test/functional/config.js"

    echo_info " -> Running xpack func tests, run $i of $maxRuns"
    eval node scripts/functional_tests \
          --esFrom=snapshot \
          --config test/functional/config.js \
          --kibana-install-dir=${Glb_Kibana_Dir} \
          --debug " $includeTags"
    if [ $? -ne 0 ]; then
      failures=1
    fi
  done

  run_ci_cleanup

  exit_script $failures "X-Pack Test failed!"
}

# -----------------------------------------------------------------------------
# Method to run x-pack tests from Kibana repo, ones in x-pack/test/ directory
# -----------------------------------------------------------------------------
function run_xpack_ext_tests() {
  echo_info "In run_xpack_ext_tests"
  local funcTests="${1:- false}"
  local testGrp=$2
  local maxRuns="${ESTF_NUMBER_EXECUTIONS:-1}"

  run_ci_setup
  update_test_files

  TEST_KIBANA_BUILD=default
  install_kibana

  local _xpack_dir="$(cd x-pack; pwd)"
  echo_info "-> XPACK_DIR ${_xpack_dir}"
  cd "$_xpack_dir"

  export TEST_BROWSER_HEADLESS=1

  awk_exec="awk"
  if [[ "$Glb_OS" = "darwin" ]]; then
    awk_exec="gawk"
  fi

  # Note: It is done this way until kibana issue #42454 is resolved
  matches=$($awk_exec 'match($0, /test[\a-z.]+'\''/) { print substr($0,RSTART,RLENGTH-1) }' scripts/functional_tests.js)

  filter_matches=""
  for grp in ${!testGrp}; do
    cfgs=$(echo $matches | tr " " "\n" | grep "test/$grp[\a-z]*")
    filter_matches="${filter_matches} $cfgs"
  done

  cfgs=$matches
  if [ ! -z "$filter_matches" ]; then
    cfgs=$filter_matches
  fi

  failures=0
  for i in $(seq 1 1 $maxRuns); do
    for cfg in $cfgs; do
      if [ $cfg == "test/functional/config.js" ] && [ $funcTests == "false" ]; then
        continue
      fi
      export ESTF_RUN_NUMBER=$i
      update_report_name $cfg

      echo " -> Running xpack ext tests config: $cfg, run $i of $maxRuns"
      node scripts/functional_tests \
        --esFrom=snapshot \
        --config $cfg \
        --kibana-install-dir=${Glb_Kibana_Dir} \
        --debug
      if [ $? -ne 0 ]; then
        failures=1
      fi
    done
  done

  run_ci_cleanup

  exit_script $failures "X-Pack Ext Test failed!"
}

# -----------------------------------------------------------------------------
# Method to run oss tests from Kibana repo, ones in test/ directory for cloud platform
# -----------------------------------------------------------------------------
function run_cloud_oss_tests() {
  echo_info "In run_cloud_oss_tests"
  local testGrp=$1
  local maxRuns="${ESTF_NUMBER_EXECUTIONS:-1}"

  run_ci_setup
  includeTags=$(update_config "test/functional/config.js" $testGrp)
  update_test_files

  export TEST_BROWSER_HEADLESS=1

  failures=0
  for i in $(seq 1 1 $maxRuns); do
    export ESTF_RUN_NUMBER=$i
    update_report_name "test/functional/config.js"

    echo_info " -> Running cloud oss functional tests, run $i of $maxRuns"
    eval node scripts/functional_test_runner \
          --config test/functional/config.js \
          --exclude-tag skipCloud \
          --debug " $includeTags"
    if [ $? -ne 0 ]; then
      failures=1
    fi
  done

  run_ci_cleanup

  exit_script $failures "Cloud OSS Test failed!"
}

# -----------------------------------------------------------------------------
# Method to run cloud xpack tests
# -----------------------------------------------------------------------------
function run_cloud_xpack_func_tests() {
  echo_info "In run_cloud_xpack_func_tests"
  local testGrp=$1
  local maxRuns="${ESTF_NUMBER_EXECUTIONS:-1}"

  run_ci_setup
  includeTags=$(update_config "x-pack/test/functional/config.js" $testGrp)
  update_test_files

  local _xpack_dir="$(cd x-pack; pwd)"
  echo_info "-> XPACK_DIR ${_xpack_dir}"
  cd "$_xpack_dir"

  export TEST_BROWSER_HEADLESS=1

  failures=0
  for i in $(seq 1 1 $maxRuns); do
    export ESTF_RUN_NUMBER=$i
    update_report_name "test/functional/config.js"

    echo_info " -> Running cloud xpack func tests, run $i of $maxRuns"
    eval node ../scripts/functional_test_runner \
          --config test/functional/config.js \
          --exclude-tag skipCloud \
          --debug " $includeTags"
    if [ $? -ne 0 ]; then
      failures=1
    fi
  done

  run_ci_cleanup

  exit_script $failures "Cloud X-Pack Test failed!"
}

# -----------------------------------------------------------------------------
# Method to run cloud xpack tests
# -----------------------------------------------------------------------------
function run_cloud_xpack_ext_tests() {
  local maxRuns="${ESTF_NUMBER_EXECUTIONS:-1}"

  echo_info "In run_cloud_xpack_ext_tests"
  echo_warning "Not all tests are running yet on cloud"
  local funcTests="${1:- false}"

  run_ci_setup
  update_test_files

  local _xpack_dir="$(cd x-pack; pwd)"
  echo_info "-> XPACK_DIR ${_xpack_dir}"
  cd "$_xpack_dir"

  export TEST_BROWSER_HEADLESS=1

  # Note: Only the following tests run on cloud at this time
  cfgs="test/functional/config.js
        test/reporting/configs/chromium_api.js
        test/reporting/configs/chromium_functional.js
        test/api_integration/config.js
       "
  failures=0
  for i in $(seq 1 1 $maxRuns); do
    for cfg in $cfgs; do
      if [ $cfg == "test/functional/config.js" ] && [ $funcTests == "false" ]; then
        continue
      fi
      export ESTF_RUN_NUMBER=$i
      update_report_name $cfg

      echo " -> Running cloud xpack ext tests config: $cfg, run $i of $maxRuns"
      node ../scripts/functional_test_runner \
        --config $cfg \
        --exclude-tag skipCloud \
        --debug
      if [ $? -ne 0 ]; then
        failures=1
      fi
    done
  done

  run_ci_cleanup

  exit_script $failures "Cloud X-Pack Ext Test failed!"
}

# -----------------------------------------------------------------------------
# Method to run visual tests under Kibana repo tests/
# -----------------------------------------------------------------------------
function run_visual_tests_oss() {
  check_percy_pkg
  run_ci_setup
  set_percy_branch

  TEST_KIBANA_BUILD=oss
  install_kibana

  export TEST_BROWSER_HEADLESS=1

  echo_info "Running oss visual tests"
  yarn run percy exec -t 500 \
  node scripts/functional_tests \
    --kibana-install-dir=${Glb_Kibana_Dir} \
    --esFrom snapshot \
    --config test/visual_regression/config.ts \
    --debug
}

# -----------------------------------------------------------------------------
# Method to run visual tests under Kibana repo x-pack/tests/
# -----------------------------------------------------------------------------
function run_visual_tests_default() {
  check_percy_pkg
  run_ci_setup
  set_percy_branch

  TEST_KIBANA_BUILD=default
  install_kibana

  export TEST_BROWSER_HEADLESS=1

  echo_info "Running default visual tests"
  yarn run percy exec -t 500 \
  node scripts/functional_tests \
    --kibana-install-dir=${Glb_Kibana_Dir} \
    --esFrom=snapshot \
    --config x-pack/test/visual_regression/config.js \
    --debug
}

# *****************************************************************************
# SECTION: Test grouping functions
# *****************************************************************************

# -----------------------------------------------------------------------------
# Method to update config file with files to be included
# -----------------------------------------------------------------------------
function update_config_file() {
  local testGrp=$1
  local configFile=$2

  if [ -z "$testGrp" ] || [ -z $configFile ] ; then
    return
  fi

  if [ ! -f $configFile ]; then
    return
  fi

  awk -v beg='testFiles: \\[' \
      -v end='\\],' \
      'NR==FNR{new = new $0 ORS; next} $0~end{f=0} !f{print} $0~beg{printf "%s", new; f=1} ' \
      <(echo "${testGrp}") $configFile  > temp.config && mv temp.config $configFile
}

# -----------------------------------------------------------------------------
# Method to group kibana tests, must be from testFiles in config
# -----------------------------------------------------------------------------
function update_config() {
  local configFile=$1
  local testGrp=$2

  if [ -z "$testGrp" ]; then
    return
  fi

  read testGrp tag < <(parse_str $testGrp)

  tmp=$(join_by \| ${!testGrp})
  testGrp=$(awk '$0~/resolve.*apps.*('"$tmp"''\''\),)/{printf "%s\n",$0}' $configFile)

  update_config_file "$testGrp" $configFile

  echo $(get_tags "${!tag}")
}

# -----------------------------------------------------------------------------
# Method to update report name when looping
# -----------------------------------------------------------------------------
function update_report_name() {
  local configFile=$1

  if [ -z $configFile ] ; then
    return
  fi

  if [ ! -f $configFile ]; then
    return
  fi

  file_modified=$(grep -c "ESTF_RUN_NUMBER" $configFile)
  echo_debug "$configFile already modified: $file_modified"
  if [[ $file_modified == 0 ]]; then
    sed -i '/reportName:.*/ s/,/ + process.env.ESTF_RUN_NUMBER,/' $configFile
  fi
}

# -----------------------------------------------------------------------------
# Method to update test files
# -----------------------------------------------------------------------------
function update_test_files() {
  IFS='
  '
  for item in $ESTF_FLAKY_TEST_SUITE
  do
    testFile=$(get_test_file $item)
    echo_debug $testFile
    git diff --exit-code -s $testFile
    file_modified=$?
    echo_debug "$testFile already modified: $file_modified"
    if [[ $file_modified == 0 ]]; then
      sed -i '0,/describe(/ s/describe(/describe\.only(/' $testFile
    fi
  done
}

# -----------------------------------------------------------------------------
# Method to get tag substring, must be after group name, start with Tag til end
# ex: ossGrp1TagSomething
# -----------------------------------------------------------------------------
function parse_str() {
  local testGrp=$1
  local tagStr="Tag"

  rest=${testGrp#*$tagStr}
  if [ $rest == $testGrp ]; then
    echo $testGrp
    return
  fi

  strLen=$(( ${#testGrp} ))
  tagInd=$(( ${#testGrp} - ${#rest} - 3 ))

  grp=${testGrp:0:$tagInd}
  tag=${testGrp:$tagInd:$strLen}

  echo "$grp $tag"
}

# -----------------------------------------------------------------------------
# Method to get tags
# -----------------------------------------------------------------------------
function get_tags() {
  local tags=$1

  if [ -z "$tags" ]; then
    return
  fi

  arr=($tags)
  count=0
  for tag in ${arr[@]}; do
    arr[$count]="--include-tag $tag"
    count=$((count+1))
  done

  echo ${arr[@]}
}

# -----------------------------------------------------------------------------
# Method to join a string by a delimiter
# -----------------------------------------------------------------------------
function join_by {
  local IFS="$1"
  shift
  echo "$*"
}

# ****************************************************************************
# SECTION: Argument parsing and execution
# ****************************************************************************

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo_error_exit "Usage: ./jenkins_kibana_tests.sh <test> or <platform> <test_group>"
fi

if [ $# -eq 1 ]; then
  TEST_GROUP=$1
else
  PLATFORM=$1
  TEST_GROUP=$2
  validPlatforms="cloud darwin linux windows"
  isValidPlatform=$(echo $validPlatforms | grep $PLATFORM)
  if [ $? -ne 0 ]; then
    echo_error_exit "Invalid platform '$PLATFORM' must be one of: '$validPlatforms'"
  fi
fi

# -- Set to true, if Chromedriver mismatch on workers
Glb_ChromeDriverHack=false
Glb_YarnNetworkTimeout=0

# Source pre-defined groups
source ./group_defs.sh

# set GCS_UPLOAD_PREFIX env
export GCS_UPLOAD_PREFIX="internal-ci-artifacts/jobs/${JOB_NAME}/${BUILD_NUMBER}"

case "$TEST_GROUP" in
  intake)
    if [ $PLATFORM == "cloud" ]; then
      echo_error_exit "'intake' job is not valid on cloud"
    fi
    run_unit_tests
    ;;
  ossGrp*)
    if [ $PLATFORM == "cloud" ]; then
      run_cloud_oss_tests $TEST_GROUP
    else
      run_oss_tests $TEST_GROUP
    fi
    ;;
  xpackIntake)
    if [ $PLATFORM == "cloud" ]; then
      echo_error_exit "'x-pack-intake' job is not valid on cloud"
    fi
    run_xpack_unit_tests
    ;;
  xpackGrp*)
    if [ $PLATFORM == "cloud" ]; then
      run_cloud_xpack_func_tests $TEST_GROUP
    else
      run_xpack_func_tests $TEST_GROUP
    fi
    ;;
  xpackExt*)
    if [ $PLATFORM == "cloud" ]; then
      run_cloud_xpack_ext_tests
    else
      run_xpack_ext_tests false $TEST_GROUP
    fi
    ;;
  selenium)
    run_oss_tests
    ;;
  xpack)
    run_xpack_ext_tests true
    ;;
  unit)
    run_unit_tests
    ;;
  cloud_selenium)
    run_cloud_oss_tests
    ;;
  cloud_xpack)
    run_cloud_xpack_ext_tests true
    ;;
  visual_tests_oss)
    run_visual_tests_oss
    ;;
  visual_tests_default)
    run_visual_tests_default
    ;;
  flaky_test_runner_cloud_prechecks)
    flaky_test_runner_cloud_prechecks
    ;;
  flaky_test_runner)
    flaky_test_runner
    ;;
  *)
    echo_error_exit "TEST_GROUP '$TEST_GROUP' is invalid group"
    ;;
esac
