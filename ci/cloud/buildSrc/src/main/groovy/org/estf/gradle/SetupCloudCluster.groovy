/*
    Default task for setting up a cloud cluster

    Author: Liza Dayoub

 */

package org.estf.gradle

import org.gradle.api.DefaultTask
import org.gradle.api.tasks.TaskAction


class SetupCloudCluster extends DefaultTask {

    private String properties_file
    private String cluster_id

    @TaskAction
    public void run() {
        println ' ** In setup cloud cluster **'
        def exe = CloudScripts.getExecutable('-c')
        def sout = ShellCmd.run(exe)
        //println sout
        properties_file =  sout.find("cloud_properties_file: .*").trim().split(':')[1]
        def filename = new File(properties_file).getName()
        cluster_id = filename.trim().split('\\.')[0]
        println properties_file
        println cluster_id
    }

    public String getClusterId() {
        return cluster_id
    }

    public String getPropertiesFile() {
        return properties_file
    }
}