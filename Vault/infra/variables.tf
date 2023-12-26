variable "vpc_id" {
  type = string
}

variable "env" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}

variable "vault_automation_script_path" {
  type = string
}

variable "region" {
  type = string
}

variable "tags" {
  type    = map(any)
  default = {}
}

variable "ebs_addon_version" {
  type    = string
  default = "v1.26.0-eksbuild.1"
}

variable "min_instances" {
  type    = number
  default = 1
}
variable "max_instances" {
  type    = number
  default = 1
}
variable "desired_instances" {
  type    = number
  default = 1
}

variable "vault_helm_chart_version" {
  type = string
  default = "0.27.0"
}

variable "vault_storage_path" {
  type = string
  default = "/vault/data"
}

variable "vault_storage_size" {
  type = string
  default = "4Gi"
}

variable "vault_replicas" {
  type = number
  default = 1
}