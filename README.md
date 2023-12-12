### Create a EKS cluster 
add ebs driver to eks cluster

### Create k8s secret with below command which uses script includes vault command for automation

kubectl create secret generic automation-script-secret --from-file=test.sh

### Install hashicorp vault using helm commands.

helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault hashicorp/vault --values values.yml