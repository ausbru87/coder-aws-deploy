# Kubernetes Controllers for EKS
# Deploys AWS Load Balancer Controller and EBS CSI Driver with IRSA

# =============================================================================
# AWS Load Balancer Controller
# Requirements: 6.1 - Deploy AWS Load Balancer Controller with proper IRSA
# =============================================================================

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_lb_controller_version
  namespace  = "kube-system"

  values = [
    yamlencode({
      clusterName = aws_eks_cluster.main.name
      region      = data.aws_region.current.id
      vpcId       = var.vpc_id
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.aws_lb_controller.arn
        }
      }
      enableServiceMutatorWebhook = true
    })
  ]

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.control,
    aws_iam_role_policy_attachment.aws_lb_controller,
  ]
}

# =============================================================================
# EBS CSI Driver (EKS Addon)
# Requirements: 6.1, 6.3 - Deploy EBS CSI driver with IRSA and encryption
# =============================================================================

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.ebs_csi_driver_version
  service_account_role_arn    = aws_iam_role.ebs_csi.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.control,
    aws_iam_role_policy_attachment.ebs_csi,
  ]
}

# Data source for current AWS region
data "aws_region" "current" {}

# =============================================================================
# Storage Classes with Encryption
# Requirements: 6.3 - Configure storage classes with encryption
# =============================================================================

resource "kubernetes_storage_class_v1" "gp3_encrypted" {
  metadata {
    name = "gp3-encrypted"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }

  depends_on = [aws_eks_addon.ebs_csi]
}

resource "kubernetes_storage_class_v1" "gp3_encrypted_retain" {
  metadata {
    name = "gp3-encrypted-retain"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }

  depends_on = [aws_eks_addon.ebs_csi]
}

# High-performance storage class for workspaces requiring higher IOPS
resource "kubernetes_storage_class_v1" "gp3_high_perf" {
  metadata {
    name = "gp3-high-performance"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type       = "gp3"
    encrypted  = "true"
    fsType     = "ext4"
    iops       = "16000"
    throughput = "1000"
  }

  depends_on = [aws_eks_addon.ebs_csi]
}
