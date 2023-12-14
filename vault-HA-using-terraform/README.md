## Vault HA cluster with auto unseal feature.

### Create a kubernetes secret with aws credentials

```hcl
apiVersion: v1
data:
  AWS_ACCESS_KEY_ID: "" #update access key here.
  AWS_SECRET_ACCESS_KEY: "" #update secret access key here.
  AWS_SESSION_TOKEN: "" #update secret token here. Not required if we are using IAM user.
kind: Secret
metadata:
  name: kms-creds
  namespace: default
```

### Once we created the secret we need to pass the name of the secret in terraform.tfvars file as below

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
