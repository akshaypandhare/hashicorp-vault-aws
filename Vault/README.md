## Vault HA cluster with auto unseal feature.

### Update the the name of the secret and other required variables in terraform.tfvars file as below

```hcl
aws_creds_secret             = "kms-creds"
```

### Update the terraform.tfvars file with required variables.

```hcl
vpc_id                       = "vpc-123456729400"
eks_cluster_name             = "htx-c1"
subnet_ids                   = ["subnet-242342knwekfn", "subnet-12314n23r23kr"]
vault_automation_script_path = "test.sh"
aws_creds_secret             = "kms-creds"
region                       = "ap-southeast-1"
vault_automation_secret      = "vault-automation-secret"
```

### Update local kubeconfig with EKS credentials

```hcl
aws eks update-kubeconfig --region ap-southeast-1 --name htx-c1-cluster
```

### Run terraform commands

```hcl
terraform init
terraform fmt
terraform fmt
terraform plan
terraform apply
```

```hcl
```
### Once we created all the resources using terraform then we need to initialise the vault cluster.

```hcl
kubectl get pods

NAME                                          READY   STATUS    RESTARTS   AGE
htx-c1-vault-0                                0/1     Running   0          12s
htx-c1-vault-1                                0/1     Running   0          11s
htx-c1-vault-2                                0/1     Running   0          11s
htx-c1-vault-agent-injector-d84cf8c7d-2tczj   1/1     Running   0          5m25s

kubectl exec -it htx-c1-vault-0 /bin/sh
/ $
/ $
/ $ vault operator init
Recovery Key 1: d7O8gb5EMriuDsxncXwKD2HDALXnYn+xrY2nrJCqI6I5
Recovery Key 2: JNtjbNjdWOMgS49p3MvcUN2Z607Mo0XMMAeNdcOG/wi9
Recovery Key 3: Nq5WcpFVfW8MIwVre19iABIneuZLdUafAmZwg639OLLZ
Recovery Key 4: m0fL1mjhqXk5s2EQfEQvulq03OTPIrSY2mGLOdbQ8i7p
Recovery Key 5: rJ9Owf2DBIVfHDolwvEpXP1RI9dTnLTM/BW5DBGybrzA

Initial Root Token: hvs.kJo1gmCVZqAyXp0Gc0Bt2QR8

Success! Vault is initialized

Recovery key initialized with 5 key shares and a key threshold of 3. Please
securely distribute the key shares printed above.
```

### Save the token and keys from above output in a safe place as we need to root token to login to vault.

### Once you initialised the vault cluster all the cluster nodes will automatically joined the cluster.

```hcl
kubectl get pods
NAME                                          READY   STATUS    RESTARTS   AGE
htx-c1-vault-0                                1/1     Running   0          59s
htx-c1-vault-1                                1/1     Running   0          58s
htx-c1-vault-2                                1/1     Running   0          58s
htx-c1-vault-agent-injector-d84cf8c7d-2tczj   1/1     Running   0          6m12s
```

### Now we need to update the terraform condifuration to run postStart script using helm so that we can automate the creation of secrets and vault policies upon start up.

### we need to update a script which runs for us as a postStart script (automation-script.sh). Update the script with the root token and the required vault command which we want to excecute during script excecution.

```hcl
#!/bin/sh
export VAULT_TOKEN="hvs.Eo0y023L2bcUk1d2U0PFHMEE"

vault policy write test-policy - <<EOF
    path "secret/data/*" {
      capabilities = ["create", "update"]
    }

    path "secret/data/foo" {
      capabilities = ["read"]
    }
EOF
```

### Update the helm chart's values content in the terraform configuration as below.

```hcl
server:

  postStart:
  - "/bin/sh"
  - "-c"
  - "sleep 20 && cp /vault/userconfig/${var.vault_automation_secret}/automation-script.sh /tmp/test.sh && chmod 777 /tmp/test.sh && /tmp/test.sh "
  extraVolumes:
  - type: secret
    name: ${var.vault_automation_secret}
```

### Apply the terraform configurations

```hcl
terraform init
terraform fmt
terraform fmt
terraform plan
terraform apply
```

### Once pods are up and running then exec in to the pod and verify if the required vault resources are crated by the script or not also if pods are failing check the logs of the pod.