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
  description             = "${var.eks_cluster_name}-vault-key"
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
    name      = "vault-automation-secret"
    namespace = "default"
  }

  data = {
    "automation-script.sh" = file("automation-script.sh")
  }
}


resource "helm_release" "example_chart" {
  depends_on    = [aws_eks_node_group.example_node_group, aws_eks_addon.csi_driver,kubernetes_secret.example_secret]
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
          - "sleep 20 && cp /vault/userconfig/vault-automation-secret/automation-script.sh /tmp/test.sh && chmod 777 /tmp/test.sh && /tmp/test.sh "
          extraVolumes:
          - type: secret
            name: vault-automation-secret

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