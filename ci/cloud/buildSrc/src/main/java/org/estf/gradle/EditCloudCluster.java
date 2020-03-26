/**
 * Default task for editing a cloud cluster
 *
 *
 * @author  Liza Dayoub
 *
 */

package org.estf.gradle;

import co.elastic.cloud.api.client.ClusterClient;
import co.elastic.cloud.api.model.generated.ElasticsearchClusterPlan;
import co.elastic.cloud.api.model.generated.KibanaClusterPlan;
import co.elastic.cloud.api.model.generated.ClusterCrudResponse;
import co.elastic.cloud.api.model.generated.ClusterUpgradeInfo;
import co.elastic.cloud.api.client.generated.ClustersElasticsearchApi;
import co.elastic.cloud.api.client.generated.ClustersKibanaApi;
import co.elastic.cloud.api.model.generated.ElasticsearchScriptTypeSettings;
import co.elastic.cloud.api.model.generated.ElasticsearchScriptingUserSettings;
import co.elastic.cloud.api.model.generated.ElasticsearchSystemSettings;
import co.elastic.cloud.api.util.Waiter;
import org.gradle.api.DefaultTask;
import org.gradle.api.tasks.TaskAction;
import org.gradle.api.tasks.Input;

public class EditCloudCluster extends DefaultTask {

    @Input
    String kibanaUserSettings;

    @Input
    String esUserSettings;

    @Input
    String clusterId;

    @Input
    String kibanaClusterId;

    @Input
    String esScriptSettings;

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

        CloudApi cloudApi = new CloudApi();
        ClusterClient clusterClient = cloudApi.createClient();
        ClustersElasticsearchApi esApi = new ClustersElasticsearchApi(cloudApi.getApiClient());
        ElasticsearchClusterPlan esClusterPlan = esApi.getEsClusterPlan(clusterId, showPlanDefaults, convertLegacyPlans);
        ClustersKibanaApi kbnApi = new ClustersKibanaApi(cloudApi.getApiClient());

        if (esUserSettings != null) {
            esClusterPlan.getElasticsearch().setUserSettingsYaml(esUserSettings);
            ClusterCrudResponse response = esApi.updateEsClusterPlan(esClusterPlan, clusterId, validateOnly);
            Waiter.waitFor(() -> cloudApi.isClusterRunning(
                esApi.getEsCluster(response.getElasticsearchClusterId(), showSecurity, showMetadata, showPlans, showPlanLogs,
                                   showPlanDefaults, convertLegacyPlans, showSystemAlerts, showSettings)
            ));
        }

        if (kibanaUserSettings != null) {
            KibanaClusterPlan kbnClusterPlan = kbnApi.getKibanaClusterPlan(kibanaClusterId, showPlanDefaults);
            kbnClusterPlan.getKibana().setUserSettingsYaml(kibanaUserSettings);
            ClusterCrudResponse response = kbnApi.updateKibanaClusterPlan(kbnClusterPlan, kibanaClusterId, validateOnly);
            Waiter.waitFor(() -> cloudApi.isKibanaRunning(
                kbnApi.getKibanaCluster(response.getKibanaClusterId(), showMetadata, showPlans, showPlanLogs, showPlanDefaults)
            ));

        }

        if (esScriptSettings != null) {
            System.out.println("************************************* ES SCRIPT SETTINGS *************************************************");
            ElasticsearchScriptTypeSettings scriptTypeSettings = new ElasticsearchScriptTypeSettings();
            scriptTypeSettings.setEnabled(false);
            scriptTypeSettings.setSandboxMode(false);
            ElasticsearchScriptingUserSettings scriptUserSettings = new ElasticsearchScriptingUserSettings();
            scriptUserSettings.setInline(scriptTypeSettings);
            scriptUserSettings.setFile(scriptTypeSettings);
            scriptUserSettings.setStored(scriptTypeSettings);
            ElasticsearchSystemSettings systemSettings = new ElasticsearchSystemSettings();
            systemSettings.setScripting(scriptUserSettings);
            esClusterPlan.getElasticsearch().setSystemSettings(systemSettings);
            ClusterCrudResponse response = esApi.updateEsClusterPlan(esClusterPlan, clusterId, validateOnly);
            Waiter.waitFor(() -> cloudApi.isClusterRunning(
                esApi.getEsCluster(response.getElasticsearchClusterId(), showSecurity, showMetadata, showPlans, showPlanLogs,
                                   showPlanDefaults, convertLegacyPlans, showSystemAlerts, showSettings)
            ));

        }
    }
}