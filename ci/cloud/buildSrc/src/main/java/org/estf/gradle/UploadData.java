/**
 * Upload data to Kibana: tutorial and sample data
 *
 *
 * @author  Liza Dayoub
 *
 */

package org.estf.gradle;

import java.nio.file.Paths;
import java.nio.channels.ReadableByteChannel;
import java.nio.channels.Channels;
import java.io.File;
import java.net.URL;
import java.net.URI;
import java.io.FileOutputStream;
import java.io.FileInputStream;
import org.gradle.api.DefaultTask;
import org.gradle.api.tasks.Input;
import org.gradle.api.tasks.TaskAction;

import groovy.transform.ConditionalInterrupt;

import java.io.IOException;
import java.net.URISyntaxException;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.io.BufferedOutputStream;

import java.util.Base64;
import org.apache.http.HttpEntity;
import org.apache.http.entity.FileEntity;
import org.apache.http.entity.ContentType;
import org.apache.http.HttpResponse;
import org.apache.http.HttpHeaders;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.HttpClient;
import org.apache.http.impl.client.HttpClientBuilder;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.client.methods.HttpRequestBase;

import org.apache.http.client.methods.HttpGet;
import org.apache.http.conn.ssl.*;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.ssl.SSLContextBuilder;
import javax.net.ssl.*;
import java.io.IOException;
import java.security.KeyManagementException;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;

import org.apache.http.entity.StringEntity;
import org.apache.http.util.EntityUtils;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

public class UploadData extends DefaultTask {

    @Input
    String esBaseUrl;

    @Input
    String kbnBaseUrl;

    @Input
    String username;

    @Input
    String password;

    @TaskAction
    public void run() throws IOException {
        uploadBankAccountData();
        createBankIndexPatternAsDefault();
        loadSampleData();

    }

    public void uploadBankAccountData() throws IOException {
        String link = "https://download.elastic.co/demos/kibana/gettingstarted/accounts.zip";
        boolean zipFile = true;
        downloadFile(link, zipFile);
        String creds = username + ":" + password;
        String basicAuthPayload = "Basic " + Base64.getEncoder().encodeToString(creds.getBytes());
        HttpPost postRequest = new HttpPost(esBaseUrl + "/bank/account/_bulk?pretty");
        postRequest.setHeader(HttpHeaders.AUTHORIZATION, basicAuthPayload);
        postRequest.setEntity(new FileEntity(new File("tmp/accounts.json"),ContentType.create("application/x-ndjson")));
        HttpClient client = HttpClientBuilder.create().build();
        HttpResponse response = client.execute(postRequest);
        int statusCode = response.getStatusLine().getStatusCode();
        if (statusCode != 200) {
            throw new IOException("Failed to post bank account data!");
        }
    }

    public void downloadFile(String link, boolean zipFile) throws IOException {
        try {
            String projectPath = System.getProperty("user.dir");
            URL url = new URL(link);
            String filename = Paths.get(new URI(link).getPath()).getFileName().toString();
            String filedir = projectPath + "/tmp";
            String filepath = filedir + "/" + filename;
            File f = new File(filedir);
            if (! f.exists()) {
                f.mkdir();
            }
            ReadableByteChannel rbc = Channels.newChannel(url.openStream());
            FileOutputStream fOutStream = new FileOutputStream(filepath);
            fOutStream.getChannel().transferFrom(rbc, 0, Long.MAX_VALUE);
            fOutStream.close();
            rbc.close();
            if (zipFile) {
                unzip(filepath, filedir);
            }
        } catch (URISyntaxException e) {
            throw new IOException("Invalid URI", e);
        }
    }

    public void unzip(String zipFilePath, String destDir) throws IOException {
        ZipInputStream zipIn = new ZipInputStream(new FileInputStream(zipFilePath));
        ZipEntry entry = zipIn.getNextEntry();
        while (entry != null) {
            String filePath = destDir + File.separator + entry.getName();
            if (!entry.isDirectory()) {
                // if the entry is a file, extracts it
                extractFile(zipIn, filePath);
            } else {
                // if the entry is a directory, make the directory
                File dir = new File(filePath);
                dir.mkdir();
            }
            zipIn.closeEntry();
            entry = zipIn.getNextEntry();
        }
        zipIn.close();
    }


    public void extractFile(ZipInputStream zipIn, String filePath) throws IOException {
        BufferedOutputStream bos = new BufferedOutputStream(new FileOutputStream(filePath));
        byte[] bytesIn = new byte[4096];
        int read = 0;
        while ((read = zipIn.read(bytesIn)) != -1) {
            bos.write(bytesIn, 0, read);
        }
        bos.close();
    }

    public void createBankIndexPatternAsDefault() throws IOException {
        String creds = username + ":" + password;
        String basicAuthPayload = "Basic " + Base64.getEncoder().encodeToString(creds.getBytes());
        HttpPost postRequest = new HttpPost(kbnBaseUrl + "/api/saved_objects/index-pattern");
        postRequest.setHeader(HttpHeaders.AUTHORIZATION, basicAuthPayload);
        postRequest.setHeader("kbn-xsrf", "automation");
        postRequest.setHeader(HttpHeaders.CONTENT_TYPE, "application/json");
        String jsonstr = "{\"attributes\": {\"title\": \"bank*\"}}";
        StringEntity entity = new StringEntity(jsonstr);
        entity.setContentType(ContentType.APPLICATION_JSON.getMimeType());
        postRequest.setEntity(entity);
        HttpClient client = HttpClientBuilder.create().build();
        HttpResponse response = client.execute(postRequest);
        int statusCode = response.getStatusLine().getStatusCode();
        if (statusCode != 200) {
            throw new IOException("Failed to post bank account data!");
        }
        String responseString = EntityUtils.toString(response.getEntity(), "UTF-8");
        JSONObject json = new JSONObject(responseString);
        String id = json.getString("id");
        postRequest = new HttpPost(kbnBaseUrl + "/api/kibana/settings");
        postRequest.setHeader(HttpHeaders.AUTHORIZATION, basicAuthPayload);
        postRequest.setHeader("kbn-xsrf", "automation");
        postRequest.setHeader(HttpHeaders.CONTENT_TYPE, "application/json");
        jsonstr = "{\"changes\": {\"defaultIndex\": \"" + id +  "\"}}";
        entity = new StringEntity(jsonstr);
        entity.setContentType(ContentType.APPLICATION_JSON.getMimeType());
        postRequest.setEntity(entity);
        client = HttpClientBuilder.create().build();
        response = client.execute(postRequest);
        statusCode = response.getStatusLine().getStatusCode();
        System.out.println(statusCode);
        if (statusCode != 200) {
            throw new IOException("Failed to post bank account data!");
        }
    }

    public void createNonDefaultSpace(String name, String id) throws IOException {
        String creds = username + ":" + password;
        String basicAuthPayload = "Basic " + Base64.getEncoder().encodeToString(creds.getBytes());
        HttpPost postRequest = new HttpPost(kbnBaseUrl + "/api/spaces/space");
        postRequest.setHeader(HttpHeaders.AUTHORIZATION, basicAuthPayload);
        postRequest.setHeader("kbn-xsrf", "automation");
        postRequest.setHeader(HttpHeaders.CONTENT_TYPE, "application/json");
        String jsonstr = "{\"name\": \"" + name + "\", \"id\": \"" + id + "\"}";
        StringEntity entity = new StringEntity(jsonstr);
        entity.setContentType(ContentType.APPLICATION_JSON.getMimeType());
        postRequest.setEntity(entity);
        HttpClient client = HttpClientBuilder.create().build();
        HttpResponse response = client.execute(postRequest);
        int statusCode = response.getStatusLine().getStatusCode();
        System.out.println(statusCode);
        if (statusCode != 200) {
            throw new IOException("Failed to create space: " + id);
        }
    }

    public void loadSampleData() throws IOException {
        createNonDefaultSpace("Automation", "automation");
        List<String> dataList = new ArrayList<String>(6);
        dataList.add("api/sample_data/ecommerce");
        dataList.add("api/sample_data/logs");
        dataList.add("api/sample_data/flights");
        dataList.add("s/automation/api/sample_data/ecommerce");
        dataList.add("s/automation/api/sample_data/logs");
        dataList.add("s/automation/api/sample_data/flights");
        String creds = username + ":" + password;
        String basicAuthPayload = "Basic " + Base64.getEncoder().encodeToString(creds.getBytes());
	for (int i = 0; i < dataList.size(); i++) {
            HttpPost postRequest = new HttpPost(kbnBaseUrl + "/" + dataList.get(i));
            postRequest.setHeader(HttpHeaders.AUTHORIZATION, basicAuthPayload);
            postRequest.setHeader("kbn-xsrf", "automation");
            postRequest.setHeader(HttpHeaders.CONTENT_TYPE, "application/json");
            HttpClient client = HttpClientBuilder.create().build();
            HttpResponse response = client.execute(postRequest);
            int statusCode = response.getStatusLine().getStatusCode();
            System.out.println(statusCode);
            if (statusCode != 200) {
                throw new IOException("Failed to load data: " + dataList.get(i));
            }
        }
    }
}
