/*
    Default task for deleting a cloud cluster

    Author: Liza Dayoub

 */

package org.estf.gradle

import org.gradle.api.DefaultTask
import org.gradle.api.tasks.TaskAction
import org.gradle.api.tasks.Input


class DeleteCloudCluster extends DefaultTask {

    @Input
    String cluster_id

    @TaskAction
    public void run() {
        println '** In cleanup cloud cluster for ' + cluster_id + ' **'
        def exe = CloudScripts.getExecutable('-d ' + cluster_id)
        def sout = ShellCmd.run(exe)
        //println sout
    }
}

