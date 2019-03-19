/**
 * Elastic cloud client
 *
 *
 * @author  Liza Dayoub
 *
 */

package org.estf.gradle;

import io.swagger.client.ApiClient;
import co.elastic.cloud.api.builder.ApiClientBuilder;
import co.elastic.cloud.api.builder.SaaSAuthenticationRequestBuilder;
import co.elastic.cloud.api.client.SaaSAuthenticationApi;
import co.elastic.cloud.api.client.ClusterClient;
import co.elastic.cloud.api.model.generated.ElasticsearchClusterInfo;
import co.elastic.cloud.api.model.generated.KibanaClusterInfo;
import java.net.*;
import java.io.*;


public class CloudApi {

    private ClusterClient clusterClient;
    private String host;
    private String apiVer = "/api/v0.1";
    private String region = "/v1-regions/us-east-1";
    private ApiClient authenticatedApiClient;

    public ClusterClient createClient() {

        // Get cloud credentials
        CloudCredentials creds = new CloudCredentials();
        creds.vaultAuth();

        // Check host is set
        host = System.getenv("ESTF_CLOUD_HOST");
        if (host == null) {
            throw new Error("Environment variable: ESTF_CLOUD_HOST is required");
        }
        String url = getUrl();

        System.out.println(" .. Setting up API client");
        // Setup cloud API client
        ApiClient authApiClient = new ApiClientBuilder()
                .setBasePath(url)
                .build();
        SaaSAuthenticationApi saaSAuthenticationApi = new SaaSAuthenticationApi(authApiClient);
        String token = saaSAuthenticationApi.login(new SaaSAuthenticationRequestBuilder()
                .setUsername(creds.getUsername())
                .setPassword(creds.getPassword())
                .build()).getToken();
        token = "Bearer " + token;
        authenticatedApiClient = new ApiClientBuilder()
                .setBasePath(url + region)
                .setApiKey(token).build();
        authenticatedApiClient.setDebugging(true);
        System.out.println(" .. Successfully setup API client");

        // Setup cloud cluster client
        System.out.println(" .. Setting up Cluster client");
        clusterClient = new ClusterClient(authenticatedApiClient);
        System.out.println(" .. Successfully setup cluster client");

        return clusterClient;
    }

    public ClusterClient getClient() {
        return clusterClient;
    }

    public ApiClient getApiClient() {
        return authenticatedApiClient;
    }

    public boolean isClusterRunning(ElasticsearchClusterInfo elasticsearchClusterInfo) {
        return ElasticsearchClusterInfo.StatusEnum.STARTED.equals(elasticsearchClusterInfo.getStatus());
    }

    public boolean isKibanaRunning(KibanaClusterInfo kibanaClusterInfo) {
        return KibanaClusterInfo.StatusEnum.STARTED.equals(kibanaClusterInfo.getStatus());
    }

    private String getHost() {
        try {
            if (host.contains("http")) {
                URL url = new URL(host);
                return url.getHost();
            }
        } catch (MalformedURLException e) {
            throw new Error(e.toString());
        }
        return host;
    }

    private String getUrl() {
       return "https://" + getHost() + apiVer;
    }
}