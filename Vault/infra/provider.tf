provider "aws" {
  region = var.region
}

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

data "aws_caller_identity" "current" {}

provider "vault" {
  address = "http://a99f9ed4d69fc4c989c876c391078ecb-693577189.ap-southeast-1.elb.amazonaws.com:8200"
  token   = ""
  version = "~> 2.0"
}
