/**
 * Default task for creating a cloud cluster
 *
 *
 * @author  Liza Dayoub
 *
 */


package org.estf.gradle;

import co.elastic.cloud.api.client.ClusterClient;
import co.elastic.cloud.api.model.generated.CreateElasticsearchClusterRequest;
import co.elastic.cloud.api.model.generated.ElasticsearchClusterInfo;
import co.elastic.cloud.api.model.generated.KibanaClusterInfo;
import co.elastic.cloud.api.model.generated.ClusterCrudResponse;
import co.elastic.cloud.api.model.generated.ClusterCredentials;
import co.elastic.cloud.api.client.generated.ClustersKibanaApi;
import co.elastic.cloud.api.util.Waiter;
import com.google.gson.Gson;
import com.google.gson.stream.JsonReader;
import org.gradle.api.DefaultTask;
import org.gradle.api.tasks.TaskAction;
import org.gradle.api.tasks.Input;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.UUID;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.Properties;


public class CreateCloudCluster extends DefaultTask {

    @Input
    String kibanaUserSettings;

    @Input
    String esUserSettings;

    @Input
    String stackVersion;

    String clusterId;
    String kibanaClusterId;
    String propertiesFile;

    private String jsonPlan = "legacyPlan.json";

    @TaskAction
    public void run() {

        if (stackVersion == null) {
            throw new Error("Environment variable: ESTF_CLOUD_VERSION is required");
        }

        // Setup cluster client
        CloudApi cloudApi = new CloudApi();
        ClusterClient clusterClient = cloudApi.createClient();

        // Create cluster
        ClusterCrudResponse response = clusterClient.createEsCluster(getFromJson());
        ClustersKibanaApi kbnApi = new ClustersKibanaApi(cloudApi.getApiClient());
        Waiter.waitFor(() -> cloudApi.isKibanaRunning(
            kbnApi.getKibanaCluster(response.getKibanaClusterId(), false, true, false, false)
        ));

        // Get cluster info
        clusterId = response.getElasticsearchClusterId();
        kibanaClusterId = response.getKibanaClusterId();
        ClusterCredentials clusterCreds = response.getCredentials();
        String esUser = clusterCreds.getUsername();
        String esPassword = clusterCreds.getPassword();
        ElasticsearchClusterInfo esInfo = clusterClient.getEsCluster(clusterId);
        String region = esInfo.getRegion();
        String domain = "foundit.no";
        String port = "9243";
        String provider = "aws.staging";
        if (region.contains("gcp")) {
            provider = "gcp";
        }
        String elasticsearch_url = String.format("https://%s.%s.%s.%s:%s", clusterId, region, provider, domain, port);
        String kibana_url = String.format("https://%s.%s.%s.%s:%s", kibanaClusterId, region, provider, domain, port);

        // Create properties file
        try {
			Properties properties = new Properties();
			properties.setProperty("cluster_id", clusterId);
			properties.setProperty("es_username", esUser);
			properties.setProperty("es_password", esPassword);
            properties.setProperty("kibana_cluster_id", kibanaClusterId);
			properties.setProperty("elasticsearch_url", elasticsearch_url);
            properties.setProperty("kibana_url", kibana_url);
            propertiesFile = PropFile.getFilename(clusterId);
			File file = new File(propertiesFile);
            FileOutputStream fileOut = new FileOutputStream(file);
            properties.store(fileOut, "Cloud Cluster Info");
			fileOut.close();
		} catch (FileNotFoundException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}
    }

    public String getClusterId() {
        return clusterId;
    }

    public String getKibanaClusterId() {
        return kibanaClusterId;
    }

    public String getPropertiesFile() {
        return propertiesFile;
    }

    private CreateElasticsearchClusterRequest getFromJson() {
        InputStream in = this.getClass().getClassLoader().getResourceAsStream(jsonPlan);
        JsonReader jsonReader = new JsonReader(new InputStreamReader(in));
        CreateElasticsearchClusterRequest jsonRequest =
                new Gson().fromJson(jsonReader, CreateElasticsearchClusterRequest.class);

        jsonRequest.getPlan().getElasticsearch().setVersion(stackVersion);

        if (esUserSettings != null) {
            jsonRequest.getPlan().getElasticsearch().setUserSettingsYaml(esUserSettings);
        }
        if (kibanaUserSettings != null) {
            jsonRequest.getKibana().getPlan().getKibana().setUserSettingsYaml(kibanaUserSettings);
        }

        jsonRequest.setClusterName("ESTF_Cluster__" + UUID.randomUUID().toString());
        return jsonRequest;
    }

}
