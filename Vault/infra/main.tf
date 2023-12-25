# Create an EKS cluster
resource "aws_eks_cluster" "vault_cluster" {
  name     = "${var.eks_cluster_name}-${var.env}"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = data.aws_subnets.example.ids
  }

  tags = var.tags
}

# Create an IAM role for EKS service
resource "aws_iam_role" "eks_role" {
  name = "${var.eks_cluster_name}-${var.env}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# install CSI driver add_on in EKS cluster

resource "aws_eks_addon" "csi_driver" {
  cluster_name  = aws_eks_cluster.vault_cluster.name
  addon_name    = "${var.eks_cluster_name}-${var.env}-addon"
  addon_version = var.ebs_addon_version
  tags          = var.tags
}

# Create a node group for the EKS cluster
resource "aws_eks_node_group" "vault_node_group" {
  cluster_name    = aws_eks_cluster.vault_cluster.name
  node_group_name = "${var.eks_cluster_name}-${var.env}-nodegroup"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = data.aws_subnets.example.ids

  scaling_config {
    desired_size = var.desired_instances
    max_size     = var.max_instances
    min_size     = var.min_instances
  }

  tags = var.tags
}

# Create an IAM role for EKS node group
resource "aws_iam_role" "eks_node_role" {
  name = "${var.eks_cluster_name}-${var.env}-nodegroup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Attaching an AWS managed policy to the IAM role
resource "aws_iam_role_policy_attachment" "policy_cluster" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "policy_nodegroup_1" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "policy_nodegroup_2" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "policy_nodegroup_3" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "policy_nodegroup_4" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# AWS KMS key

resource "aws_kms_key" "vault_unseal_key" {
  description             = "${var.eks_cluster_name}-${var.env}-vault-key"
  deletion_window_in_days = 7
  tags                    = var.tags
}

resource "kubernetes_secret" "vault_secret" {
  depends_on = [aws_eks_node_group.vault_node_group, aws_eks_addon.csi_driver]
  metadata {
    name      = "vault-automation-secret"
    namespace = "default"
  }

  data = {
    "automation-script.sh" = file(var.vault_automation_script_path)
  }
}

resource "kubernetes_secret" "aws_creds" {
  depends_on = [aws_eks_node_group.vault_node_group, aws_eks_addon.csi_driver]
  metadata {
    name      = "kms-creds"
    namespace = "default"
  }

  data = {
    AWS_ACCESS_KEY_ID : "ASIA2BSCFRMZDWV47M5P"
    AWS_SECRET_ACCESS_KEY : "voqo4b0y3v5dq3xdwr6eUl4/gG+R4jSshvwKbyIX"
    AWS_SESSION_TOKEN : "IQoJb3JpZ2luX2VjEJz//////////wEaCXVzLWVhc3QtMSJHMEUCIBhD1keLzPlRhoGbWBiKq+itaSvZk6OxWVmdpP/uQiJ3AiEAw86gaOJ4sEBGo4rUMLWcuth1IUXDiNPzskgyNwtAynwqkgMIJRAAGgw2OTA1NTQ3NjgxNzgiDDkuMhOGDnqUPzfNjyrvAil/NtOvxdKOVQ72yDenvZ3vJY6FjCX1m+YGpvLcCn5BXN5ApXI2asd8u3SG5SwPvbhXFFFF6h2z9VQ0GqPWcgQ2L+WYqSVqrzNBphheMivS1mw+4cfTvjirvJaoCnPVqPYTr7y5WJ5eEYpCAgMG5jhPLXMXjElckP7BEhY103RIX1X2k+ZoCOsAnVpH22YL3mhWhL3YLPS0TefPC8woOPdPbSU4kG8dis6q6MWDSvLIesHTmV1um5lHJ7mYC+Arg8R4hxRaoq8ogJRnce2rbJgY1BLYVCY7yynum6SdQhUObrlhwmTh1QXJmMVBtF0Zuboq5zvQ8Xe9a8SW0q8HxRQUbgt4PM+gcoHlTwqdtfCTGKF0Q27b/l5t0f0k/IxovzUh6gpipNNFrujMbjvKjhTlZW/HyHmSF8NN6jDZiSo0w/E69Vatp/9AEm0REmPgGOc9tj6SE1edo9xLOH8pNcojl6aCce4UPKebiYi8ZMowo5CUrAY6pgHzsL3tyV2wIzINmnokk8CiLSLFJFMxfwnNerfq66vFAZ87AitVUBQXwRDqP3A6V9+JjYSHQbfdqfSHy60EIOld9qQwDIvlw7JwU4VonxnDAoBIkXGBgOqXnjJn11q55yEC4Cmfn0Jvkk4weFGeePKSAFtb6PtE3wBDhPi+PiKLWAzRAeZRM6vQ1Ka31kMMEPDU7Dqz1RgX5mg24iM38tewXsnC/e4/"
  }
}


resource "helm_release" "vault_chart" {
  depends_on    = [aws_eks_node_group.vault_node_group, aws_eks_addon.csi_driver, kubernetes_secret.vault_secret, kubernetes_secret.aws_creds]
  name          = "${var.eks_cluster_name}-${var.env}"
  repository    = "https://helm.releases.hashicorp.com"
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

          dataStorage:
            enabled: true
            size: 4Gi 
            mountPath: "/vault/data"
            storageClass: null
            accessMode: ReadWriteOnce
            annotations: {}

          extraSecretEnvironmentVars:
            - envName: AWS_ACCESS_KEY_ID
              secretName: kms-creds
              secretKey: AWS_ACCESS_KEY_ID
            - envName: AWS_SECRET_ACCESS_KEY
              secretName: kms-creds
              secretKey: AWS_SECRET_ACCESS_KEY
            - envName: AWS_SESSION_TOKEN
              secretName: kms-creds
              secretKey: AWS_SESSION_TOKEN

          ha:
            enabled: true
            replicas: 3

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
                path = "/vault/data"

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