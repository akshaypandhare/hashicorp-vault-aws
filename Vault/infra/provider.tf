provider "aws" {
  region = var.region
}

terraform {
  required_version = ">= 1.5.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
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

provider "vault" {
  address = "http://a1806ccda84b0479da37b60cd38327a7-2056272176.ap-southeast-1.elb.amazonaws.com:8200"
  token   = "hvs.vh0dKUAojPqI7QnaGlmY9toS"
  version = "~> 2.0"
}
