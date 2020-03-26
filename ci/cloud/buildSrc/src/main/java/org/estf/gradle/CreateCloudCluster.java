/**
 * Default task for creating a cloud cluster
 *
 *
 * @author  Liza Dayoub
 *
 */


package org.estf.gradle;

import co.elastic.cloud.api.builder.ApiClientBuilder;
import co.elastic.cloud.api.builder.CreateElasticsearchClusterRequestBuilder;
import co.elastic.cloud.api.builder.CreateKibanaInCreateElasticsearchRequestBuilder;
import co.elastic.cloud.api.builder.DiscreteSizesBuilder;
import co.elastic.cloud.api.builder.ElasticsearchClusterPlanBuilder;
import co.elastic.cloud.api.builder.ElasticsearchClusterTopologyElementBuilder;
import co.elastic.cloud.api.builder.ElasticsearchConfigurationBuilder;
import co.elastic.cloud.api.builder.ElasticsearchNodeTypeBuilder;
import co.elastic.cloud.api.builder.ElasticsearchScriptingUserSettingsBuilder;
import co.elastic.cloud.api.builder.ElasticsearchScriptTypeSettingsBuilder;
import co.elastic.cloud.api.builder.ElasticsearchSystemSettingsBuilder;
import co.elastic.cloud.api.builder.InstanceConfigurationBuilder;
import co.elastic.cloud.api.builder.KibanaClusterPlanBuilder;
import co.elastic.cloud.api.builder.KibanaClusterTopologyElementBuilder;
import co.elastic.cloud.api.builder.KibanaConfigurationBuilder;
import co.elastic.cloud.api.builder.TopologySizeBuilder;
import co.elastic.cloud.api.client.ClusterClient;
import co.elastic.cloud.api.client.generated.ClustersElasticsearchApi;
import co.elastic.cloud.api.client.generated.ClustersKibanaApi;
import co.elastic.cloud.api.model.generated.ClusterCredentials;
import co.elastic.cloud.api.model.generated.ClusterCrudResponse;
import co.elastic.cloud.api.model.generated.CreateElasticsearchClusterRequest;
import co.elastic.cloud.api.model.generated.CreateKibanaInCreateElasticsearchRequest;
import co.elastic.cloud.api.model.generated.DiscreteSizes;
import co.elastic.cloud.api.model.generated.ElasticsearchClusterInfo;
import co.elastic.cloud.api.model.generated.ElasticsearchClusterPlan;
import co.elastic.cloud.api.model.generated.ElasticsearchClusterTopologyElement;
import co.elastic.cloud.api.model.generated.ElasticsearchConfiguration;
import co.elastic.cloud.api.model.generated.ElasticsearchNodeType;
import co.elastic.cloud.api.model.generated.ElasticsearchScriptingUserSettings;
import co.elastic.cloud.api.model.generated.ElasticsearchScriptTypeSettings;
import co.elastic.cloud.api.model.generated.ElasticsearchSystemSettings;
import co.elastic.cloud.api.model.generated.InstanceConfiguration;
import co.elastic.cloud.api.model.generated.KibanaClusterInfo;
import co.elastic.cloud.api.model.generated.KibanaClusterPlan;
import co.elastic.cloud.api.model.generated.KibanaClusterTopologyElement;
import co.elastic.cloud.api.model.generated.KibanaConfiguration;
import co.elastic.cloud.api.model.generated.TopologySize;
import co.elastic.cloud.api.util.Waiter;
import com.google.gson.Gson;
import com.google.gson.stream.JsonReader;
import org.gradle.api.DefaultTask;
import org.gradle.api.tasks.Input;
import org.gradle.api.tasks.TaskAction;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.IOException;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Properties;
import java.util.UUID;

public class CreateCloudCluster extends DefaultTask {

    @Input
    String stackVersion;

    @Input
    String kibanaUserSettings;

    @Input
    String esUserSettings;

    @Input
    String esUserSettingsOverride;

    @Input
    String kibanaUserSettingsOverride;

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
        String es_cfg = "aws.highio.classic";
        String kbn_cfg = "aws.kibana.classic";
        String ml_cfg = "aws.ml.m5";
        String data_region = System.getenv("ESTF_CLOUD_REGION");
        if (data_region != null) {
            if (data_region.contains("gcp")) {
                es_cfg = "gcp.highio.classic";
                kbn_cfg = "gcp.kibana.classic";
                ml_cfg = "gcp.ml.1";
            } else if (data_region.contains("azure")) {
                es_cfg = "master";
                kbn_cfg = "kibana";
                ml_cfg = "ml";
            }
        }

        ClusterCrudResponse response = clusterClient.createEsCluster(createClusterRequest(es_cfg, kbn_cfg, ml_cfg));
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
            region = region.replace("gcp-","");
        } else if (region.contains("azure")) {
            provider = "staging.azure";
            region = region.replace("azure-","");
        }

        // TODO: see if I can get this from cluster info
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

    private CreateElasticsearchClusterRequest createClusterRequest(String esConfigId, String kbnConfigId, String mlConfigId) {

        TopologySize topologySize = new TopologySizeBuilder()
            .setValue(1024)
            .setResource(TopologySize.ResourceEnum.MEMORY)
            .build();

        int kibanaZone = 1;
        try {
            kibanaZone = Integer.parseInt(System.getenv("ESTF_CLOUD_KIBANA_ZONE"));
        } catch (NumberFormatException e) {
            kibanaZone = 1;
        }

        ElasticsearchNodeType esNodeType = new ElasticsearchNodeTypeBuilder().setData(true).setMaster(true).build();

        ElasticsearchNodeType mlNodeType = new ElasticsearchNodeTypeBuilder().setMl(true).build();

        ElasticsearchClusterTopologyElement esTopo = new ElasticsearchClusterTopologyElementBuilder()
            .setInstanceConfigurationId(esConfigId)
            .setNodeType(esNodeType)
            .setZoneCount(1)
            .setSize(topologySize)
            .build();

        ElasticsearchClusterTopologyElement mlTopo = new ElasticsearchClusterTopologyElementBuilder()
            .setInstanceConfigurationId(mlConfigId)
            .setNodeType(mlNodeType)
            .setZoneCount(1)
            .setSize(topologySize)
            .build();

        KibanaClusterTopologyElement kbnTopo = new KibanaClusterTopologyElementBuilder()
            .setInstanceConfigurationId(kbnConfigId)
            .setZoneCount(kibanaZone)
            .setSize(topologySize)
            .build();

        ElasticsearchScriptTypeSettings typeSetting = new ElasticsearchScriptTypeSettingsBuilder()
            .setEnabled(true)
            .build();

        ElasticsearchScriptingUserSettings userSettings = new ElasticsearchScriptingUserSettingsBuilder()
            .setInline(typeSetting)
            .setStored(typeSetting)
            .build();

        ElasticsearchSystemSettings esSettings = new ElasticsearchSystemSettingsBuilder()
            .setAutoCreateIndex(true)
            .setDestructiveRequiresName(false)
            .setScripting(userSettings)
            .build();

        ElasticsearchConfigurationBuilder esCfgBld = new ElasticsearchConfigurationBuilder();
        esCfgBld.setSystemSettings(esSettings);
        esCfgBld.setVersion(stackVersion);
        if (esUserSettings != null) {
            esCfgBld.setUserSettingsYaml(esUserSettings);
        }
        if (esUserSettingsOverride != null) {
            esCfgBld.setUserSettingsOverrideYaml(esUserSettingsOverride);
        }
        ElasticsearchConfiguration esCfg = esCfgBld.build();

        KibanaConfigurationBuilder kbnCfgBld = new KibanaConfigurationBuilder();
        if (kibanaUserSettings != null) {
            kbnCfgBld.setUserSettingsYaml(kibanaUserSettings);
        }
        if (kibanaUserSettingsOverride != null) {
            kbnCfgBld.setUserSettingsOverrideYaml(kibanaUserSettingsOverride);
        }
        KibanaConfiguration kbnCfg = kbnCfgBld.build();

        ElasticsearchClusterPlan plan = new ElasticsearchClusterPlanBuilder()
            .setElasticsearch(esCfg)
            .setClusterTopology(Arrays.asList(esTopo, mlTopo))
            .build();

        KibanaClusterPlan kbnPlan = new KibanaClusterPlanBuilder()
            .setKibana(kbnCfg)
            .setClusterTopology(Arrays.asList(kbnTopo))
            .build();

        CreateKibanaInCreateElasticsearchRequest kbnInEs = new CreateKibanaInCreateElasticsearchRequestBuilder()
            .setPlan(kbnPlan)
            .build();

        return new CreateElasticsearchClusterRequestBuilder()
            .setPlan(plan)
            .setKibana(kbnInEs)
            .setClusterName("ESTF_Cluster__" + UUID.randomUUID().toString())
            .build();
    }
}
