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

# ****************************************************************************
# SECTION: Kibana CI setup functions
# ****************************************************************************

# ----------------------------------------------------------------------------
# Method to create Kibana build install directory
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

  readonly Glb_Pkg_Name
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

  Glb_Kibana_Url="$_host/$_path/$Glb_Pkg_Name"

  local _urlExists=$(curl --head -f "${Glb_Kibana_Url}"; echo $?)
  if [[ $_urlExists -ne 0 ]]; then
    echo_error_exit "URL does not exist: $Glb_Kibana_Url"
  fi

  echo_info "Kibana URL: $Glb_Kibana_Url"

  readonly Glb_Kibana_Url
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
    sed -ie 's/"chromedriver": "^76.0.0"/"chromedriver": "^75.1.0"/g' package.json
  fi

  yarn kbn bootstrap
}

# ----------------------------------------------------------------------------
# Method to check if any files changed during bootstraping
# ----------------------------------------------------------------------------
function check_git_changes() {

  local _git_changes="$(git ls-files --modified | grep -Ev "yarn.lock")"

  if $Glb_ChromeDriverHack; then
    echo_warning "Temporary package.json modified for chromedriver."
    local _git_changes="$(git ls-files --modified | grep -Ev "package.json|yarn.lock")"
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
# Method to install Kibana
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

# *****************************************************************************
# SECTION: Percy visual testing functions
# *****************************************************************************

# -----------------------------------------------------------------------------
# Method to set percy target branch
# -----------------------------------------------------------------------------
function set_percy_target_branch() {
  export PERCY_TARGET_BRANCH=$(git branch | grep \* | cut -d ' ' -f2)
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
  cp -r kibana-visual-tests/test/visual_regression test
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
  cp -r kibana-visual-tests/x-pack/test/visual_regression x-pack/test
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
# Method to run Kibana unit tests
# -----------------------------------------------------------------------------
function run_unit_tests() {
  echo_info "In run_unit_tests"
  run_ci_setup

  export TEST_ES_FROM=snapshot
  export TEST_BROWSER_HEADLESS=1

  echo_info " -> Running unit tests"
  "$(FORCE_COLOR=0 yarn bin)/grunt" jenkins:unit --from=${TEST_ES_FROM};
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

  echo " -> Running jest tests"
  node scripts/jest --ci --verbose
  echo ""
  echo ""

  echo " -> Running SIEM cyclic dependency test"
  cd "$XPACK_DIR"
  node legacy/plugins/siem/scripts/check_circular_deps
  echo ""
  echo ""

  echo " -> Running jest contracts tests"
  cd "$XPACK_DIR"
  node scripts/jest_contract.js --ci --verbose
  echo ""
  echo ""

  # echo " -> Running jest integration tests"
  # node scripts/jest_integration --ci --verbose
  # echo ""
  # echo ""
}

# -----------------------------------------------------------------------------
# Method to run oss tests from Kibana repo, ones in test/ directory
# -----------------------------------------------------------------------------
function run_oss_tests() {
  echo_info "In run_oss_tests"
  local testGrp=$1

  run_ci_setup
  includeTags=$(update_config "test/functional/config.js" $testGrp)
  TEST_KIBANA_BUILD=oss
  install_kibana

  export TEST_BROWSER_HEADLESS=1

  echo_info " -> Running oss functional tests"
  eval node scripts/functional_tests \
        --esFrom snapshot \
        --kibana-install-dir=${Glb_Kibana_Dir} \
        --config test/functional/config.js \
        --debug " $includeTags" \
        -- --server.maxPayloadBytes=1679958
}

# -----------------------------------------------------------------------------
# Method to run x-pack tests from Kibana repo, ones in x-pack/test/ directory
# -----------------------------------------------------------------------------
function run_xpack_func_tests() {
  echo_info "In run_xpack_func_tests"
  local testGrp=$1

  run_ci_setup
  includeTags=$(update_config "x-pack/test/functional/config.js" $testGrp)
  TEST_KIBANA_BUILD=default
  install_kibana

  local _xpack_dir="$(cd x-pack; pwd)"
  echo_info "-> XPACK_DIR ${_xpack_dir}"
  cd "$_xpack_dir"

  export TEST_BROWSER_HEADLESS=1

  echo_info " -> Running xpack func tests"
  eval node scripts/functional_tests \
        --esFrom=snapshot \
        --config test/functional/config.js \
        --kibana-install-dir=${Glb_Kibana_Dir} \
        --debug " $includeTags"
}

# -----------------------------------------------------------------------------
# Method to run x-pack tests from Kibana repo, ones in x-pack/test/ directory
# -----------------------------------------------------------------------------
function run_xpack_ext_tests() {
  echo_info "In run_xpack_ext_tests"
  local funcTests="${1:- false}"

  run_ci_setup
  TEST_KIBANA_BUILD=default
  install_kibana

  local _xpack_dir="$(cd x-pack; pwd)"
  echo_info "-> XPACK_DIR ${_xpack_dir}"
  cd "$_xpack_dir"

  export TEST_BROWSER_HEADLESS=1

  # Note: It is done this way until kibana issue #42454 is resolved
  matches=$(awk 'match($0, /test[\a-z.]+'\''/) { print substr($0,RSTART,RLENGTH-1) }' scripts/functional_tests.js)
  failures=0
  for cfg in $matches; do
    if [ $cfg == "test/functional/config.js" ] && [ $funcTests == "false" ]; then
      continue
    fi
    echo " -> Running xpack ext tests config: $cfg"
    node scripts/functional_tests \
      --esFrom=snapshot \
      --config $cfg \
      --kibana-install-dir=${Glb_Kibana_Dir} \
      --debug
    if [ $? -ne 0 ]; then
      failures=1
    fi
  done
  if [ $failures -eq 1 ]; then
      echo_error_exit "Tests failed!"
  fi
}

# -----------------------------------------------------------------------------
# Method to run oss tests from Kibana repo, ones in test/ directory for cloud platform
# -----------------------------------------------------------------------------
function run_cloud_oss_tests() {
  echo_info "In run_cloud_oss_tests"
  local testGrp=$1

  run_ci_setup
  includeTags=$(update_config "test/functional/config.js" $testGrp)

  export TEST_BROWSER_HEADLESS=1

  echo_info " -> Running cloud oss functional tests"
  eval node scripts/functional_test_runner \
        --config test/functional/config.js \
        --exclude-tag skipCloud \
        --debug " $includeTags"
}

# -----------------------------------------------------------------------------
# Method to run cloud xpack tests
# -----------------------------------------------------------------------------
function run_cloud_xpack_func_tests() {
  echo_info "In run_cloud_xpack_func_tests"
  local testGrp=$1

  run_ci_setup
  includeTags=$(update_config "x-pack/test/functional/config.js" $testGrp)

  local _xpack_dir="$(cd x-pack; pwd)"
  echo_info "-> XPACK_DIR ${_xpack_dir}"
  cd "$_xpack_dir"

  export TEST_BROWSER_HEADLESS=1

  echo_info " -> Running cloud xpack func tests"
  eval node ../scripts/functional_test_runner \
        --config test/functional/config.js \
        --exclude-tag skipCloud \
        --debug " $includeTags"
}

# -----------------------------------------------------------------------------
# Method to run cloud xpack tests
# -----------------------------------------------------------------------------
function run_cloud_xpack_ext_tests() {
  echo_info "In run_cloud_xpack_ext_tests"
  echo_warning "Not all tests are running yet on cloud"
  local funcTests="${1:- false}"

  run_ci_setup

  local _xpack_dir="$(cd x-pack; pwd)"
  echo_info "-> XPACK_DIR ${_xpack_dir}"
  cd "$_xpack_dir"

  export TEST_BROWSER_HEADLESS=1

  # Note: Only the following tests run on cloud at this time
  cfgs = "test/functional/config.js
          test/reporting/configs/chromium_api.js
          test/reporting/configs/chromium_functional.js
          test/api_integration/config.js
         "
  failures=0
  for cfg in $cfgs; do
    if [ $cfg == "test/functional/config.js" ] && [ $funcTests == "false" ]; then
      continue
    fi
    echo " -> Running cloud xpack ext tests config: $cfg"
    node ../scripts/functional_test_runner \
      --esFrom=snapshot \
      --config $cfg \
      --exclude-tag skipCloud \
      --debug
    if [ $? -ne 0 ]; then
      failures=1
    fi
  done
  if [ $failures -eq 1 ]; then
      echo_error_exit "Tests failed!"
  fi
}

# -----------------------------------------------------------------------------
# Method to run code tests
# -----------------------------------------------------------------------------
function run_code_tests() {
  run_ci_setup
  TEST_KIBANA_BUILD=default
  install_kibana

  local _xpack_dir="$(cd x-pack; pwd)"
  echo_info "-> XPACK_DIR ${_xpack_dir}"
  cd "$_xpack_dir"

  export TEST_BROWSER_HEADLESS=1

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
    echo_error_exit "Code tests failed!"
  fi
}

# -----------------------------------------------------------------------------
# Method to run visual tests under Kibana repo tests/
# -----------------------------------------------------------------------------
function run_visual_tests_oss() {
  check_percy_pkg
  run_ci_setup
  set_percy_branch
  cp_visual_tests

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
  cp_xpack_visual_tests

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

# Source pre-defined groups
source ./group_defs.sh

case "$TEST_GROUP" in
  intake)
    [ $PLATFORM == "cloud" ] && { echo_error "'intake' job is not valid on cloud"; } || run_unit_tests
    ;;
  ossGrp*)
    [ $PLATFORM == "cloud" ] && { run_cloud_oss_tests $TEST_GROUP; } || run_oss_tests $TEST_GROUP
    ;;
  xpackIntake)
    [ $PLATFORM == "cloud" ] && { echo_error "'x-pack-intake' job is not valid on cloud"; } || run_xpack_unit_tests
    ;;
  xpackGrp*)
    [ $PLATFORM == "cloud" ] && { run_cloud_xpack_func_tests $TEST_GROUP; } || run_xpack_func_tests $TEST_GROUP
    ;;
  xpackExt)
    [ $PLATFORM == "cloud" ] && { run_cloud_xpack_ext_tests; } || run_xpack_ext_tests
    ;;
  selenium)
    run_oss_tests
    ;;
  xpack)
    run_xpack_ext_tests true
    ;;
  code)
    run_code_tests
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
  *)
    echo_error "TEST_GROUP '$TEST_GROUP' is invalid group"
    ;;
esac
