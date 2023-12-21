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
    desired_size = 0
    max_size     = 1
    min_size     = 0
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
    AWS_ACCESS_KEY_ID: "ASIA2BSCFRMZDHU4RQLY"
    AWS_SECRET_ACCESS_KEY: "G5reE0kc3O0qESpi3ZH4sjZP8HnLWoMbJH90GW84"
    AWS_SESSION_TOKEN: "IQoJb3JpZ2luX2VjEG0aCXVzLWVhc3QtMSJHMEUCIQCDaRs452oKAoxcCCPbJ/YveBt0oQCfKsKOqV/1VnNmZwIgCWwCYfHwSzNmYkDK4UBrMh1ktCSQPmAEo3/vyYS6igwqmwMI5v//////////ARAAGgw2OTA1NTQ3NjgxNzgiDKA3mQttth6ksl1K2irvAuVMEPFhILQFnFWnfFtUCoRYeKB4ittNTQi+O+qWTZG6u6qDlJF+2ZQh1mxuIjjRm7PBwdgAxZP4MfCPEx9XHzrunpT/VFETfa+K2ohacBC8wCqlOr0TI1d7CKBJ2oAXcJV/xr0EQlnLC6eVZhV7TbWfaFO5mXSvYXRkmFatVt0eHA7feS2z05IcERfuJWIEfFLu5xJK9aVfYqPHQ0SqKpyAoXdDG1kw2Na1D25oON4ijd1Wv2Wx+rfR7kvFNGEYkxzBI0ce250eHU7CL+jKcgxsbk5MASVSMdRMAJFDB6PeUAz8d6SDVgMkVfzyvLbS+ZwszGNIeG+HnCmqmgtBoDRnK0a8iJeewWI+egIa+BV3oUkwzlcOH9cdol8fdMcbCszoA/IQcftr5bFzxPjGqeBsvootHNtdmAwkWWgByey8TFEqWh34/nGj2G4+a/kQx/bVRrr2s7IIefh0fHlPlk6aA557S2dbXZMUt1vP7pkw+NiJrAY6pgEHyiebFaUk6CQgrgkWCVNZRfHoLF0iqy0AKjILmIufRScoeg5VP+woZLt48CpqD0uKMfQTsDc5O6e65Hg+yVhpLko7sSg4B5UrxbiuAcPNnT0KqFdUucKlJg3ZaVSMhYV5Kq1PoEkNSdHn8cqKzZIsAiL2xU9dImZm2o2PjReg1Bo65t72eTEoTFiG9Fad+O2BHpvYNOgslc3CbrYuJ8RJ+r7i0SgI"
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