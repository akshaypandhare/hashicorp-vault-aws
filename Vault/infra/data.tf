data "aws_subnets" "example" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

data "aws_iam_role" "cluster-role" {
  name = "vault-cluster-role"
}

data "aws_iam_role" "nodegroup-role" {
  name = "vault-nodegroup-role"
}

data "tls_certificate" "example" {
  url = aws_eks_cluster.vault_cluster.identity.0.oidc.0.issuer
}

locals {
  oidc_provider_url = replace(aws_eks_cluster.vault_cluster.identity.0.oidc.0.issuer, "https://", "")
}

data "aws_caller_identity" "current" {}