/*
    Class to get python script for cloud provisioning

    Author: Liza Dayoub

 */

class CloudScripts {

    public static String getExecutable(args) {
        def _ait_scripts = System.env['AIT_SCRIPTS']
        if (_ait_scripts == null) {
            throw new Exception("ENV AIT_SCRIPTS is not set")
        }
        return "python $_ait_scripts/python/cloud_cluster.py " + args
    }

}
