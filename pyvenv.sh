# Start the python virtual env for running python tests
#
# @author: Liza Dayoub

# ----------------------------------------------------------------------------
source aitenv.sh
exec /bin/bash -c "AIT_RUN_LOCAL=True
source ${AIT_SCRIPTS}/shell/lib/build_funcs.sh
check_env_workspace
activate_python_virtual_env
python_install_packages
cd ${AIT_ROOTDIR}/tests
exec /bin/bash -i"
