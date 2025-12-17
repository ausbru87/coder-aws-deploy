# IAM Roles for EKS Cluster and Nodes

# =============================================================================
# EKS Cluster Role
# =============================================================================
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_vpc_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# =============================================================================
# EKS Node Role
# =============================================================================
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# =============================================================================
# Coder Server Role (IRSA)
# =============================================================================
#
# Requirements: 2.5 - Least-privilege IAM roles for Coder services using IRSA
#
# This role is assumed by the coderd service account and provides:
# - Secrets Manager access for database credentials and OIDC secrets
# - RDS access for database connectivity monitoring
# - CloudWatch Logs access for audit log forwarding
#
# The role uses IRSA (IAM Roles for Service Accounts) to securely provide
# AWS credentials to the coderd pods without storing credentials in the cluster.

resource "aws_iam_role" "coder_server" {
  name = "${var.cluster_name}-coder-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:coder:coder"
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name        = "${var.cluster_name}-coder-server-role"
    Component   = "coder-server"
    Description = "IRSA role for Coder control plane (coderd)"
  })
}

resource "aws_iam_role_policy" "coder_server" {
  name = "${var.cluster_name}-coder-server-policy"
  role = aws_iam_role.coder_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Secrets Manager access for database credentials, OIDC secrets, and external auth
      # Requirement 3.4: Integration with AWS Secrets Manager for sensitive configuration
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:coder/*",
          "arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:${var.cluster_name}/*"
        ]
      },
      # RDS access for database connectivity and health monitoring
      # Requirement 2.3: Aurora PostgreSQL database access
      {
        Sid    = "RDSDescribeAccess"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBClusters",
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusterEndpoints"
        ]
        Resource = [
          "arn:aws:rds:*:${data.aws_caller_identity.current.account_id}:cluster:${var.cluster_name}-*",
          "arn:aws:rds:*:${data.aws_caller_identity.current.account_id}:db:${var.cluster_name}-*"
        ]
      },
      # CloudWatch Logs access for audit log forwarding
      # Requirement 3.6: Forward Coder audit logs to CloudWatch Logs
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/coder/*",
          "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/coder/*:*"
        ]
      },
      # KMS access for decrypting secrets (if using KMS-encrypted secrets)
      {
        Sid    = "KMSDecryptAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [
          "arn:aws:kms:*:${data.aws_caller_identity.current.account_id}:key/*"
        ]
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.*.amazonaws.com"
          }
        }
      }
    ]
  })
}

# =============================================================================
# Coder Provisioner Role (IRSA)
# =============================================================================
#
# Requirements: 2.5 - Least-privilege IAM roles for provisioners using IRSA
#
# This role is assumed by the coder-provisioner service account and provides:
# - EC2 provisioning permissions for EC2-based workspaces (ec2-windev-gui, ec2-datasci)
# - EKS access for pod-based workspaces (pod-swdev)
# - EBS volume management for workspace persistent storage
# - IAM PassRole for workspace instance profiles
# - Secrets Manager access for provisioner keys
#
# The provisioner runs Terraform to create workspace infrastructure, so it needs
# permissions to manage EC2 instances, EBS volumes, and Kubernetes resources.

resource "aws_iam_role" "coder_provisioner" {
  name = "${var.cluster_name}-coder-prov-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:coder-prov:coder-provisioner"
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name        = "${var.cluster_name}-coder-prov-role"
    Component   = "coder-provisioner"
    Description = "IRSA role for Coder external provisioners"
  })
}

resource "aws_iam_role_policy" "coder_provisioner" {
  name = "${var.cluster_name}-coder-prov-policy"
  role = aws_iam_role.coder_provisioner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EC2 Instance Management for EC2-based workspaces
      # Requirement 11.3: Support EC2-based workspaces (ec2-windev-gui, ec2-datasci)
      {
        Sid    = "EC2InstanceManagement"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RebootInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstanceTypes",
          "ec2:ModifyInstanceAttribute"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/ManagedBy" = "coder"
          }
        }
      },
      # EC2 Describe permissions (no resource constraints needed for describe)
      {
        Sid    = "EC2DescribeResources"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumeStatus",
          "ec2:DescribeSnapshots",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSpotPriceHistory"
        ]
        Resource = "*"
      },
      # EC2 Tagging for workspace resources
      {
        Sid    = "EC2TagManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = [
              "RunInstances",
              "CreateVolume",
              "CreateSecurityGroup",
              "CreateSnapshot"
            ]
          }
        }
      },
      # Security Group Management for workspace network isolation
      # Requirement 3.1c: Workspace network isolation
      {
        Sid    = "EC2SecurityGroupManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:ModifySecurityGroupRules",
          "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
          "ec2:UpdateSecurityGroupRuleDescriptionsEgress"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/ManagedBy" = "coder"
          }
        }
      },
      # EBS Volume Management for workspace persistent storage
      # Requirement 11a.1: Persist /home/coder directory across restarts
      # Requirement 14.5: Block storage for optimal read/write performance
      {
        Sid    = "EBSVolumeManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/ManagedBy" = "coder"
          }
        }
      },
      # EKS Access for pod-based workspaces
      # Requirement 11.3: Support EKS pod-based workspaces (pod-swdev)
      {
        Sid    = "EKSClusterAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:AccessKubernetesApi"
        ]
        Resource = [
          "arn:aws:eks:*:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}",
          "arn:aws:eks:*:${data.aws_caller_identity.current.account_id}:nodegroup/${var.cluster_name}/*/*"
        ]
      },
      # IAM PassRole for workspace instance profiles
      # Required for EC2 workspaces to assume their own IAM roles
      {
        Sid    = "IAMPassRoleForWorkspaces"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/coder-workspace-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster_name}-workspace-*"
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ec2.amazonaws.com"
          }
        }
      },
      # IAM Instance Profile management for EC2 workspaces
      {
        Sid    = "IAMInstanceProfileManagement"
        Effect = "Allow"
        Action = [
          "iam:GetInstanceProfile",
          "iam:ListInstanceProfiles"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/coder-workspace-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${var.cluster_name}-workspace-*"
        ]
      },
      # Secrets Manager access for provisioner keys and workspace secrets
      # Requirement 12f.1: Provisioner key authentication
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:coder/*",
          "arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:${var.cluster_name}/*"
        ]
      },
      # SSM Parameter Store access for workspace configuration
      {
        Sid    = "SSMParameterAccess"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/coder/*",
          "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/${var.cluster_name}/*"
        ]
      },
      # KMS access for decrypting secrets and encrypting EBS volumes
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext"
        ]
        Resource = [
          "arn:aws:kms:*:${data.aws_caller_identity.current.account_id}:key/*"
        ]
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "secretsmanager.*.amazonaws.com",
              "ec2.*.amazonaws.com"
            ]
          }
        }
      },
      # CloudWatch Logs for provisioner logging
      # Requirement 12f.6: Provisioner access logs
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/coder/provisioner/*",
          "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/coder/provisioner/*:*"
        ]
      },
      # Service Quotas read access for capacity planning
      {
        Sid    = "ServiceQuotasRead"
        Effect = "Allow"
        Action = [
          "servicequotas:GetServiceQuota",
          "servicequotas:ListServiceQuotas"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# AWS Load Balancer Controller Role (IRSA)
# =============================================================================
resource "aws_iam_role" "aws_lb_controller" {
  name = "${var.cluster_name}-aws-lb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "aws_lb_controller" {
  policy_arn = aws_iam_policy.aws_lb_controller.arn
  role       = aws_iam_role.aws_lb_controller.name
}

resource "aws_iam_policy" "aws_lb_controller" {
  name        = "${var.cluster_name}-aws-lb-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller"

  policy = file("${path.module}/policies/aws-lb-controller-policy.json")
}

# =============================================================================
# EBS CSI Driver Role (IRSA)
# =============================================================================
resource "aws_iam_role" "ebs_csi" {
  name = "${var.cluster_name}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}
