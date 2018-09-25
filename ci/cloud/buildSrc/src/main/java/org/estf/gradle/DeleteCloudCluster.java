/*
    Default task for deleting a cloud cluster

    Author: Liza Dayoub

 */

package org.estf.gradle;

import org.gradle.api.DefaultTask;
import org.gradle.api.tasks.TaskAction;
import org.gradle.api.tasks.Input;
import co.elastic.cloud.api.client.ClusterClient;
import java.io.File;


public class DeleteCloudCluster extends DefaultTask {

    @Input 
    String clusterId;

    @TaskAction
    public void run() {

        // Setup cluster client
        CloudApi cloudApi = new CloudApi();
        ClusterClient clusterClient = cloudApi.createClient();
        
        // Delete cluster
        clusterClient.deleteEsCluster(clusterId);

        // Delete properties file 
        String filename = PropFile.getFilename(clusterId);
        File f = new File(filename);
        if (f.exists()) {
            f.delete();
        }

    }
}
