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