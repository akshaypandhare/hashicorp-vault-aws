# Create an EKS cluster
resource "aws_eks_cluster" "example_cluster" {
  name     = "${var.eks_cluster_name}-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = var.subnet_ids
  }
}

# Create an IAM role for EKS service
resource "aws_iam_role" "eks_role" {
  name = "${var.eks_cluster_name}-cluster-role"

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
  cluster_name  = aws_eks_cluster.example_cluster.name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = "v1.25.0-eksbuild.1"
}

# Create a node group for the EKS cluster
resource "aws_eks_node_group" "example_node_group" {
  cluster_name    = aws_eks_cluster.example_cluster.name
  node_group_name = "${var.eks_cluster_name}-nodegroup"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  tags = {
    Environment = "Production"
  }
}

# Create an IAM role for EKS node group
resource "aws_iam_role" "eks_node_role" {
  name = "${var.eks_cluster_name}-nodegroup-role"

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

resource "aws_kms_key" "example_key" {
  description             = "${var.eks_cluster_name}-vault-key" # env
  deletion_window_in_days = 7

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "kubernetes_secret" "example_secret" {
  depends_on = [aws_eks_node_group.example_node_group, aws_eks_addon.csi_driver]
  metadata {
    name      = var.vault_automation_secret
    namespace = "default"
  }

  data = {
    "automation-script.sh" = file("automation-script.sh")
  }
}

resource "kubernetes_secret" "aws_creds" {
  depends_on = [aws_eks_node_group.example_node_group, aws_eks_addon.csi_driver]
  metadata {
    name      = var.aws_creds_secret
    namespace = "default"
  }

  data = {
    AWS_ACCESS_KEY_ID: "ASIA2BSCFRMZDWV47M5P"
    AWS_SECRET_ACCESS_KEY: "voqo4b0y3v5dq3xdwr6eUl4/gG+R4jSshvwKbyIX"
    AWS_SESSION_TOKEN: "IQoJb3JpZ2luX2VjEJz//////////wEaCXVzLWVhc3QtMSJHMEUCIBhD1keLzPlRhoGbWBiKq+itaSvZk6OxWVmdpP/uQiJ3AiEAw86gaOJ4sEBGo4rUMLWcuth1IUXDiNPzskgyNwtAynwqkgMIJRAAGgw2OTA1NTQ3NjgxNzgiDDkuMhOGDnqUPzfNjyrvAil/NtOvxdKOVQ72yDenvZ3vJY6FjCX1m+YGpvLcCn5BXN5ApXI2asd8u3SG5SwPvbhXFFFF6h2z9VQ0GqPWcgQ2L+WYqSVqrzNBphheMivS1mw+4cfTvjirvJaoCnPVqPYTr7y5WJ5eEYpCAgMG5jhPLXMXjElckP7BEhY103RIX1X2k+ZoCOsAnVpH22YL3mhWhL3YLPS0TefPC8woOPdPbSU4kG8dis6q6MWDSvLIesHTmV1um5lHJ7mYC+Arg8R4hxRaoq8ogJRnce2rbJgY1BLYVCY7yynum6SdQhUObrlhwmTh1QXJmMVBtF0Zuboq5zvQ8Xe9a8SW0q8HxRQUbgt4PM+gcoHlTwqdtfCTGKF0Q27b/l5t0f0k/IxovzUh6gpipNNFrujMbjvKjhTlZW/HyHmSF8NN6jDZiSo0w/E69Vatp/9AEm0REmPgGOc9tj6SE1edo9xLOH8pNcojl6aCce4UPKebiYi8ZMowo5CUrAY6pgHzsL3tyV2wIzINmnokk8CiLSLFJFMxfwnNerfq66vFAZ87AitVUBQXwRDqP3A6V9+JjYSHQbfdqfSHy60EIOld9qQwDIvlw7JwU4VonxnDAoBIkXGBgOqXnjJn11q55yEC4Cmfn0Jvkk4weFGeePKSAFtb6PtE3wBDhPi+PiKLWAzRAeZRM6vQ1Ka31kMMEPDU7Dqz1RgX5mg24iM38tewXsnC/e4/"
  }
}


resource "helm_release" "example_chart" {
  depends_on    = [aws_eks_node_group.example_node_group, aws_eks_addon.csi_driver,kubernetes_secret.example_secret, kubernetes_secret.aws_creds]
  name          = var.eks_cluster_name
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

          postStart:
          - "/bin/sh"
          - "-c"
          - "sleep 20 && cp /vault/userconfig/${var.vault_automation_secret}/automation-script.sh /tmp/test.sh && chmod 777 /tmp/test.sh && /tmp/test.sh "
          extraVolumes:
          - type: secret
            name: ${var.vault_automation_secret}

          dataStorage:
            enabled: true
            size: 4Gi 
            mountPath: "/vault/data"
            storageClass: null
            accessMode: ReadWriteOnce
            annotations: {}

          extraSecretEnvironmentVars:
            - envName: AWS_ACCESS_KEY_ID
              secretName: ${var.aws_creds_secret}
              secretKey: AWS_ACCESS_KEY_ID
            - envName: AWS_SECRET_ACCESS_KEY
              secretName: ${var.aws_creds_secret}
              secretKey: AWS_SECRET_ACCESS_KEY
            - envName: AWS_SESSION_TOKEN
              secretName: ${var.aws_creds_secret}
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
                    auto_join        = "provider=k8s namespace=default label_selector=\"app.kubernetes.io/instance=${var.eks_cluster_name},component=server\""
                    auto_join_scheme = "http"
                }
                }

                service_registration "kubernetes" {}

                seal "awskms" {
                region     = "${var.region}"
                kms_key_id = "${aws_kms_key.example_key.key_id}"
                }

        ui:
          enabled: true
          serviceType: "LoadBalancer"
    EOF
  ]

  namespace = "default"
}



# testing


#resource "vault_policy" "example_policy" {
#  name   = "my-policy"                      
#  policy = <<EOT
##    # Example Vault policy
#   path "secret/data/my-secret" {
#      capabilities = ["read"]
#    }
#  EOT
#}