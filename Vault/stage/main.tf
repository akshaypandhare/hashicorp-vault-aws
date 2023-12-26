module "vault_cluster" {
  source                       = "../infra"
  vpc_id                       = "vpc-07e3fc26e7dc19ef2"
  env                          = "stage"
  eks_cluster_name             = "htx-c1"
  vault_automation_script_path = "../template/automation-script.tmpl.sh"
  region                       = "ap-southeast-1"
  tags = {
    "POC_NAME" = "Vault_on_AWS"
    "env"      = "stage"
  }
  min_instances     = 3
  max_instances     = 3
  desired_instances = 3
  vault_replicas    = 3
}
