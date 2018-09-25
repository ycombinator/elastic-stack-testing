/*
    Elastic Cloud Credentials

    Author: Liza Dayoub

 */

package org.estf.gradle;


import org.gradle.api.DefaultTask;
import org.gradle.api.tasks.TaskAction;
import java.io.InputStream;
import java.io.InputStreamReader;
import com.bettercloud.vault.*;
import static java.lang.System.*;
import java.util.Map;


public class CloudCredentials {

    private String username;
    private String password;

    public void vaultAuth() {
        String vaultAddr = System.getenv("VAULT_ADDR");
        String vaultToken = System.getenv("VAULT_TOKEN");
        String vaultPath = System.getenv("VAULT_PATH");

        if (vaultPath == null) {
            vaultPath = "secret/stack-testing/cloud";
        }

        if (vaultAddr == null || vaultToken == null) {
            throw new Error("Environment variables: VAULT_ADDR and VAULT_TOKEN are required");
        }

        try {
            final VaultConfig config = new VaultConfig()
                                            .address(vaultAddr)
                                            .token(vaultToken)
                                            .build();

            final Vault vault = new Vault(config);
            final Map map = vault.logical()
                                    .read(vaultPath)
                                    .getData();

            this.username = map.get("username").toString();
            this.password = map.get("password").toString();

        } catch(VaultException e) {
            throw new Error("Caught Vault Exception: " + e.getMessage());
        }
    }

    public String getUsername() {
        return username;
    }

    public String getPassword() {
        return password;
    }
} 

