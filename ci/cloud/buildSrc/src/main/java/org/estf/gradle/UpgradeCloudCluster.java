/**
 * Default task for upgrading a cloud cluster
 *
 *
 * @author  Liza Dayoub
 *
 */

package org.estf.gradle;

import co.elastic.cloud.api.client.ClusterClient;
import co.elastic.cloud.api.model.generated.ElasticsearchClusterPlan;
import co.elastic.cloud.api.model.generated.ClusterCrudResponse;
import co.elastic.cloud.api.model.generated.ClusterUpgradeInfo;
import co.elastic.cloud.api.client.generated.ClustersElasticsearchApi;
import co.elastic.cloud.api.client.generated.ClustersKibanaApi;
import co.elastic.cloud.api.util.Waiter;
import org.gradle.api.DefaultTask;
import org.gradle.api.tasks.TaskAction;
import org.gradle.api.tasks.Input;


public class UpgradeCloudCluster extends DefaultTask {

    @Input
    String clusterId;

    @Input
    String kibanaClusterId;

    @Input
    String upgradeStackVersion;

    Boolean validateOnly = false;
    Boolean showPlanDefaults = false;
    Boolean convertLegacyPlans = false;
    Boolean showSecurity = false;
    Boolean showMetadata = false;
    Boolean showPlans = true;
    Boolean showPlanLogs = false;
    Integer showSystemAlerts = 0;
    Boolean showSettings = false;

    @TaskAction
    public void run() {

        if (upgradeStackVersion == null) {
             throw new Error("Upgrade stack version is required.");
        }

        System.out.println("************************************* UPGRADE *************************************************");

        CloudApi cloudApi = new CloudApi();
        ClusterClient clusterClient = cloudApi.createClient();
        ClustersElasticsearchApi esApi = new ClustersElasticsearchApi(cloudApi.getApiClient());
        ElasticsearchClusterPlan esClusterPlan = esApi.getEsClusterPlan(clusterId, showPlanDefaults, convertLegacyPlans);
        ClustersKibanaApi kbnApi = new ClustersKibanaApi(cloudApi.getApiClient());

        esClusterPlan.getElasticsearch().setVersion(upgradeStackVersion);
        ClusterCrudResponse response = esApi.updateEsClusterPlan(esClusterPlan, clusterId, validateOnly);
        Waiter.waitFor(() -> cloudApi.isClusterRunning(
            esApi.getEsCluster(response.getElasticsearchClusterId(), showSecurity, showMetadata, showPlans, showPlanLogs,
                                showPlanDefaults, convertLegacyPlans, showSystemAlerts, showSettings)
        ));

        ClusterUpgradeInfo upInfo = kbnApi.upgradeKibanaCluster(kibanaClusterId, validateOnly);
        Waiter.waitFor(() -> cloudApi.isKibanaRunning(
            kbnApi.getKibanaCluster(upInfo.getClusterId(), showMetadata, showPlans, showPlanLogs, showPlanDefaults)
        ));

    }

}