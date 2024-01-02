# Create an EKS cluster
resource "aws_eks_cluster" "vault_cluster" {
  name     = "${var.eks_cluster_name}-${var.env}"
  role_arn = data.aws_iam_role.cluster-role.arn

  vpc_config {
    subnet_ids = data.aws_subnets.example.ids
  }

  tags = var.tags
}

# Run aws commands to access the eks cluster as we need to deploy helm chart using k8s provider.

resource "null_resource" "local" {
  depends_on = [aws_eks_cluster.vault_cluster,aws_eks_node_group.vault_node_group]
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${var.eks_cluster_name}-${var.env}"
  }
}

# Add EKS OIDC as identity provider in AWS IAM

resource "aws_iam_openid_connect_provider" "example" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.example.certificates.0.sha1_fingerprint]
  url             = aws_eks_cluster.vault_cluster.identity.0.oidc.0.issuer
}

# install CSI driver add_on in EKS cluster

resource "aws_eks_addon" "csi_driver" {
  depends_on    = [aws_eks_node_group.vault_node_group]
  cluster_name  = aws_eks_cluster.vault_cluster.name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = var.ebs_addon_version
  tags          = var.tags
}

# Create a node group for the EKS cluster
resource "aws_eks_node_group" "vault_node_group" {
  cluster_name    = aws_eks_cluster.vault_cluster.name
  node_group_name = "${var.eks_cluster_name}-${var.env}-nodegroup"
  node_role_arn   = data.aws_iam_role.nodegroup-role.arn
  subnet_ids      = data.aws_subnets.example.ids

  scaling_config {
    desired_size = var.desired_instances
    max_size     = var.max_instances
    min_size     = var.min_instances
  }

  tags = var.tags
}

# AWS KMS key

resource "aws_kms_key" "vault_unseal_key" {
  description             = "${var.eks_cluster_name}-${var.env}-vault-key"
  deletion_window_in_days = 7
  tags                    = var.tags
}

resource "kubernetes_secret" "vault_secret" {
  depends_on = [aws_eks_node_group.vault_node_group, aws_eks_addon.csi_driver, null_resource.local]
  metadata {
    name      = "vault-automation-secret"
    namespace = "default"
  }

  data = {
    "automation-script.sh" = file(var.vault_automation_script_path)
  }
}

# Create an IAM role which would be assume by vault serviceaccount

resource "aws_iam_role" "vault_service_account_role" {
  name = "${var.eks_cluster_name}-${var.env}-vault-sa-role"
  tags = var.tags
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider_url}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "${local.oidc_provider_url}:aud" : "sts.amazonaws.com",
            "${local.oidc_provider_url}:sub" : "system:serviceaccount:default:vault-service-account"
          }
        }
      }
    ]
  })
}

# Above IAM role IAM policy

resource "aws_iam_role_policy_attachment" "vault_sa_role_policy" {
  role       = aws_iam_role.vault_service_account_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Vault serviceAccount which will assume above IAM role

resource "kubernetes_service_account" "vault_sa" {
  depends_on = [aws_eks_node_group.vault_node_group, aws_eks_addon.csi_driver, null_resource.local]
  metadata {
    name      = "vault-service-account"
    namespace = "default"
    annotations = {
      "eks.amazonaws.com/role-arn" = "${aws_iam_role.vault_service_account_role.arn}"
    }
  }
}

# vault helm chart

resource "helm_release" "vault_chart" {
  depends_on    = [aws_eks_node_group.vault_node_group, aws_eks_addon.csi_driver, kubernetes_secret.vault_secret, null_resource.local]
  name          = "${var.eks_cluster_name}-${var.env}"
  repository    = "https://helm.releases.hashicorp.com"
  version       = var.vault_helm_chart_version
  force_update  = true
  recreate_pods = true

  chart = "vault"
  values = [
    <<EOF
        global:
          enabled: true

        injector:
          enabled: true

        server:

          serviceAccount:
            create: false
            name: ${kubernetes_service_account.vault_sa.metadata[0].name}
          dataStorage:
            enabled: true
            size: "${var.vault_storage_size}"
            mountPath: "${var.vault_storage_path}"
            storageClass: null
            accessMode: ReadWriteOnce
            annotations: {}

          ha:
            enabled: true
            replicas: ${var.vault_replicas}

            raft:
              enabled: true
              setNodeId: false
              config: |
                ui = true

                listener "tcp" {
                tls_disable = 1
                address = "[::]:8200"
                cluster_address = "[::]:8201"
                }
                
                storage "raft" {
                path = "${var.vault_storage_path}"

                retry_join {
                    auto_join        = "provider=k8s namespace=default label_selector=\"app.kubernetes.io/instance=${var.eks_cluster_name}-${var.env},component=server\""
                    auto_join_scheme = "http"
                }
                }

                service_registration "kubernetes" {}

                seal "awskms" {
                region     = "${var.region}"
                kms_key_id = "${aws_kms_key.vault_unseal_key.key_id}"
                }

        ui:
          enabled: true
          serviceType: "LoadBalancer"
    EOF
  ]

  namespace = "default"
}

# vault provider example

#resource "vault_policy" "example_policy" {
#  name   = "vault-test-policy"                      
#  policy = <<EOT
#  # Example Vault policy
#   path "secret/data/my-secret" {
#      capabilities = ["read"]
#    }
#  EOT
#}
