variable "vpc_id" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vault_automation_script_path" {
  type = string
}

variable "aws_creds_secret" {
    type = string
}

variable "region" {
    type = string
}