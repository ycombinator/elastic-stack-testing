#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Functions to:
# - Download and install kibana archive: .zip or .tar.gz
# - Download and install node and yarn
# - Kibana bootstrap
# - Run Kibana tests: unit, selenium and xpack
# - Logging functions
# ----------------------------------------------------------------------------

set -e

###
### Since the Jenkins logging output collector doesn't look like a TTY
### Node/Chalk and other color libs disable their color output. But Jenkins
### can handle color fine, so this forces https://github.com/chalk/supports-color
### to enable color support in Chalk and other related modules.
###
export FORCE_COLOR=1

# ----------------------------------------------------------------------------

if [ -z $COLOR_LOGS ] || ([ ! -z $COLOR_LOGS ] && $COLOR_LOGS); then
    export COLOR_LOGS=true
fi

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

date_timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

echo_error() {
  if [ ${COLOR_LOGS} == true ]; then
    echo -e ${RED}"["$(date_timestamp)"] [ERROR] $1" ${NC}
  else
    echo -e "["$(date_timestamp)"] [ERROR] $1"
  fi
}

echo_error_exit() {
  echo_error "$1"
  exit 1
}

echo_warning() {
  if [ ${COLOR_LOGS} == true ]; then
    echo -e ${YELLOW}"["$(date_timestamp)"] [WARNING] $1" ${NC}
  else
    echo -e "["$(date_timestamp)"] [WARNING] $1"
  fi
}

echo_info() {
  if [ ${COLOR_LOGS} == true ]; then
    echo -e ${LIGHT_BLUE}"["$(date_timestamp)"] [INFO] $1" ${NC}
  else
    echo -e "["$(date_timestamp)"] [INFO] $1"
  fi
}

echo_debug() {
  if [ ${COLOR_LOGS} == true ]; then
    echo -e ${GRAY}"["$(date_timestamp)"] [DEBUG] $1" ${NC}
  else
    echo -e "["$(date_timestamp)"] [DEBUG] $1"
  fi
}

# ----------------------------------------------------------------------------

Glb_Cache_Dir="${CACHE_DIR:-"$HOME/.kibana"}"
readonly Glb_Cache_Dir

# ----------------------------------------------------------------------------
# Create kibana build install directory
# ----------------------------------------------------------------------------
function create_install_dir() {
  if [ ! -z $Glb_Install_Dir ]; then
    return
  fi
  Glb_Install_Dir="$(pwd)/kibana-build"
  mkdir -p "$Glb_Install_Dir"
  readonly Glb_Install_Dir
}

# ----------------------------------------------------------------------------
# Get build server: snapshots
# TODO: add archive / staging? <- needs hash
#       - but ES is install from snapshot - ftr limitation ??
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
# Get version from kibana package.json file
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
# Get OS
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
  elif [[ "$_uname" = "Linux" ]]; then
    Glb_OS="linux"
  else
    echo_error_exit "Unknown OS: $_uname"
  fi

  echo_info "Running on OS: $Glb_OS"

  readonly Glb_OS

}

# ----------------------------------------------------------------------------
#
# ----------------------------------------------------------------------------
function get_kibana_pkg() {

  if [ ! -z $Glb_Pkg_Name ]; then
    return
  fi

  # Get if oss packages are available
  local _splitStr=(${Glb_Kibana_Version//./ })
  local _version=${_splitStr[0]}.${_splitStr[1]}
  #local _isOssSupported=$(bc <<< "${_version}>=6.3")
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

  readonly Glb_Pkg_Name
}

# ----------------------------------------------------------------------------
# Check if Kibana package URL exists
# ----------------------------------------------------------------------------
function get_kibana_url() {

  if [ ! -z $Glb_Kibana_Url ]; then
    return
  fi

  local _host="https://${Glb_Build_Server}.elastic.co"
  local _path="downloads/kibana"

  Glb_Kibana_Url="$_host/$_path/$Glb_Pkg_Name"

  local _urlExists=$(curl --head -f "${Glb_Kibana_Url}"; echo $?)
  if [[ $_urlExists -ne 0 ]]; then
    echo_error_exit "URL does not exist: $Glb_Kibana_Url"
  fi

  echo_info "Kibana URL: $Glb_Kibana_Url"

  readonly Glb_Kibana_Url
}

# ----------------------------------------------------------------------------
# Download and extract Kibana package
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
    export JAVA_HOME="c:\Progra~1\Java\jre-10"
  fi

  readonly Glb_Kibana_Dir
}

# -----------------------------------------------------------------------------
function install_kibana() {
  create_install_dir
  get_build_server
  get_version
  get_os
  get_kibana_pkg
  get_kibana_url
  download_and_extract_package
}

# -----------------------------------------------------------------------------
function in_kibana_repo() {
  local _dir="$(pwd)"
  if [ ! -f "$_dir/package.json" ] || [ ! -f "$_dir/.node-version" ]; then
    echo_error_exit "CI setup must be run within a Kibana repo"
  fi
}

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
  echo_debug $(where yarn)
}

# ----------------------------------------------------------------------------
function yarn_kbn_bootstrap() {
  echo_info "Installing node.js dependencies"
  #yarn config set cache-folder "$Glb_Cache_Dir/yarn"

  # Temporary to get windows tests to run in CI until chromedriver is officially bumped
  # See: https://github.com/elastic/kibana/pull/24925
  # TODO: Remove later
  local _node_ver=$(cat .node-version)
  if [ "$_node_ver" == "8.14.0" ] && [[ "$Glb_OS" = "windows" ]]; then
    echo_warning "Temporary update package.json bump chromedriver."
    sed -ie 's/"chromedriver": "2.42.1"/"chromedriver": "2.44"/g' package.json
  fi

  yarn kbn bootstrap
}

# ----------------------------------------------------------------------------
function check_git_changes() {

  local _git_changes="$(git ls-files --modified)"

  # Temporary to get windows tests to run in CI until chromedriver is officially bumped
  # See: https://github.com/elastic/kibana/pull/24925
  # TODO: Remove later
  local _node_ver=$(cat .node-version)
  if [ "$_node_ver" == "8.14.0" ] && [[ "$Glb_OS" = "windows" ]]; then
    echo_warning "Temporary package.json modified for chromedriver."
    local _git_changes="$(git ls-files --modified | grep -Ev "package.json|yarn.lock")"
  fi

  if [ "$_git_changes" ]; then
    echo_error_exit "'yarn kbn bootstrap' caused changes to the following files:\n$_git_changes"
  fi
}

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
function run_selenium_tests() {
  run_ci_setup
  TEST_KIBANA_BUILD=oss
  install_kibana

  # Run Tests
  export TEST_BROWSER_HEADLESS=1

  echo_info "Running selenium tests"
  node scripts/functional_tests \
    --kibana-install-dir=${Glb_Kibana_Dir} \
    --esFrom snapshot \
    --config test/functional/config.js \
    --debug \
    -- --server.maxPayloadBytes=1648576
}

# -----------------------------------------------------------------------------
function run_xpack_tests() {
  run_ci_setup
  TEST_KIBANA_BUILD=default
  install_kibana

  local _xpack_dir="$(cd x-pack; pwd)"
  echo_info "-> XPACK_DIR ${_xpack_dir}"
  cd "$_xpack_dir"

  export TEST_BROWSER_HEADLESS=1

  #echo_info "Running xpack mocha tests"
  #yarn test

  echo_info "Running xpack jest tests"
  node scripts/jest --ci --no-cache --verbose

  echo_info "Running xpack functional and api tests"
  node scripts/functional_tests \
    --kibana-install-dir=${Glb_Kibana_Dir} \
    --esFrom=snapshot \
    --debug

}

# -----------------------------------------------------------------------------
function run_code_tests() {
  run_ci_setup
  TEST_KIBANA_BUILD=default
  install_kibana

  local _xpack_dir="$(cd x-pack; pwd)"
  echo_info "-> XPACK_DIR ${_xpack_dir}"
  cd "$_xpack_dir"

  export TEST_BROWSER_HEADLESS=1

  #echo_info "Running xpack mocha tests"
  #yarn test

  #echo_info "Running xpack jest tests"
  #node scripts/jest --ci --no-cache --verbose

  echo_info "Run API Integration"
  node scripts/functional_tests \
    --kibana-install-dir=${Glb_Kibana_Dir} \
    --config=test/api_integration/config.js \
    --esFrom=snapshot \
    --grep="^apis Code .*"
  api_rc=$?

  echo_info "Run Functional Tests"
  node scripts/functional_tests \
    --kibana-install-dir=${Glb_Kibana_Dir} \
    --config=test/functional/config.js \
    --esFrom=snapshot \
    --grep="^Code .*"
  func_rc=$?

  if [ $api_rc -ne 0 ] ||
     [ $func_rc -ne 0 ]; then
    echo_error_exit "Tests failed!"
  fi
}

# -----------------------------------------------------------------------------
function run_unit_tests() {
  run_ci_setup
  export TEST_ES_FROM=snapshot
  export TEST_BROWSER_HEADLESS=1

  echo_info "Running unit tests"
  "$(FORCE_COLOR=0 yarn bin)/grunt" jenkins:unit --from=${TEST_ES_FROM};
}

# -----------------------------------------------------------------------------
function run_cloud_selenium_tests() {
  run_ci_setup

  # Run Tests
  export TEST_BROWSER_HEADLESS=1

  echo_info "Running selenium tests"

  node scripts/functional_test_runner \
    --debug \
    --exclude-tag skipCloud
}

# -----------------------------------------------------------------------------
function run_cloud_xpack_tests() {
  run_ci_setup

  local _xpack_dir="$(cd x-pack; pwd)"
  echo_info "-> XPACK_DIR ${_xpack_dir}"
  cd "$_xpack_dir"

  export TEST_BROWSER_HEADLESS=1

  echo_info "Running xpack tests"
  echo_warning "Not all tests are including"

  echo_info "Run API Integration"
  node ../scripts/functional_test_runner \
    --config test/api_integration/config.js \
    --debug \
    --exclude-tag skipCloud

  echo_info "Run Functional Tests"
  node ../scripts/functional_test_runner \
    --config test/functional/config.js \
    --debug \
    --exclude-tag skipCloud

  echo_info "Run Reports API"
  node ../scripts/functional_test_runner \
    --config test/reporting/configs/chromium_api.js \
    --debug \
    --exclude-tag skipCloud

  echo_info "Run Reports Functional"
  node ../scripts/functional_test_runner \
    --config test/reporting/configs/chromium_functional.js \
    --debug \
    --exclude-tag skipCloud

}

if [ "$1" == "selenium" ]; then
  run_selenium_tests
elif [ "$1" == "xpack" ]; then
  run_xpack_tests
elif [ "$1" == "code" ]; then
  run_code_tests
elif [ "$1" == "unit" ]; then
  run_unit_tests
elif [ "$1" == "cloud_selenium" ]; then
  run_cloud_selenium_tests
elif [ "$1" == "cloud_xpack" ]; then
  run_cloud_xpack_tests
else
  echo_error_exit "Invalid test option: $1"
fi
