# EKS Node Groups for Coder Deployment
# Three distinct node groups: control, provisioner, workspace

# =============================================================================
# Control Node Group (coderd) - Static scaling
# =============================================================================
resource "aws_eks_node_group" "control" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-control"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.control_subnet_ids

  instance_types = [var.control_node_instance_type]
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.control_node_min_size
    min_size     = var.control_node_min_size
    max_size     = var.control_node_max_size
  }

  labels = {
    "coder.com/node-type" = "control"
  }

  taint {
    key    = "coder-control"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(var.tags, {
    Name                                = "${var.cluster_name}-control"
    "coder.com/node-type"               = "control"
    "k8s.io/cluster-autoscaler/enabled" = "false"
  })

  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_policy,
  ]
}

# =============================================================================
# Provisioner Node Group - Time-based scaling
# =============================================================================
resource "aws_eks_node_group" "provisioner" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-prov"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.prov_subnet_ids

  instance_types = [var.prov_node_instance_type]
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.prov_node_min_size
    min_size     = var.prov_node_min_size
    max_size     = var.prov_node_max_size
  }

  labels = {
    "coder.com/node-type" = "provisioner"
  }

  taint {
    key    = "coder-prov"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  update_config {
    max_unavailable_percentage = 50
  }

  tags = merge(var.tags, {
    Name                                = "${var.cluster_name}-prov"
    "coder.com/node-type"               = "provisioner"
    "k8s.io/cluster-autoscaler/enabled" = "false"
  })

  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_policy,
  ]

  # Ignore desired_size changes as it's managed by scheduled scaling
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# =============================================================================
# Workspace Node Group - Time-based scaling with spot instances and on-demand fallback
# =============================================================================

# Launch template for workspace nodes with spot instance configuration
resource "aws_launch_template" "workspace" {
  name_prefix = "${var.cluster_name}-ws-"
  description = "Launch template for Coder workspace nodes with spot instance support"

  # Instance type is managed by the node group, not the launch template
  # This allows EKS to handle the mixed instances policy

  # Enable detailed monitoring for better visibility
  monitoring {
    enabled = true
  }

  # Metadata options for IMDSv2 (security best practice)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # Block device configuration for workspace nodes
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 100
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name                  = "${var.cluster_name}-ws-node"
      "coder.com/node-type" = "workspace"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.cluster_name}-ws-volume"
    })
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "workspace" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-ws"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.ws_subnet_ids

  # Use launch template for advanced configuration
  launch_template {
    id      = aws_launch_template.workspace.id
    version = aws_launch_template.workspace.latest_version
  }

  # Instance types for the node group
  # When using spot instances, EKS will try these types in order
  instance_types = var.ws_use_spot_instances ? [
    var.ws_node_instance_type,
    "m5.xlarge",
    "m5a.2xlarge",
    "m5n.2xlarge",
    "m6i.2xlarge"
  ] : [var.ws_node_instance_type]

  # Capacity type: SPOT with on-demand fallback handled by EKS
  # When spot capacity is unavailable, EKS will fall back to on-demand
  capacity_type = var.ws_use_spot_instances ? "SPOT" : "ON_DEMAND"

  scaling_config {
    desired_size = var.ws_node_min_size
    min_size     = var.ws_node_min_size
    max_size     = var.ws_node_max_size
  }

  labels = {
    "coder.com/node-type" = "workspace"
    "coder.com/spot"      = var.ws_use_spot_instances ? "true" : "false"
  }

  taint {
    key    = "coder-ws"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  update_config {
    max_unavailable_percentage = 25
  }

  tags = merge(var.tags, {
    Name                                = "${var.cluster_name}-ws"
    "coder.com/node-type"               = "workspace"
    "k8s.io/cluster-autoscaler/enabled" = "false"
  })

  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_policy,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# =============================================================================
# Scheduled Scaling Actions
# Time-based scaling completing 15 minutes before target time (0700/1800 ET)
# Scale up at 0645 ET, scale down at 1815 ET
# =============================================================================

# Provisioner scale up (0645 ET - 15 min before 0700)
# Pre-provisions capacity for morning workspace provisioning operations
resource "aws_autoscaling_schedule" "prov_scale_up" {
  count = var.enable_autoscaling_schedules ? 1 : 0

  scheduled_action_name  = "${var.cluster_name}-prov-scale-up"
  autoscaling_group_name = aws_eks_node_group.provisioner.resources[0].autoscaling_groups[0].name
  min_size               = var.prov_node_desired_peak
  max_size               = var.prov_node_max_size
  desired_capacity       = var.prov_node_desired_peak
  recurrence             = var.scaling_schedule_start
  time_zone              = var.scaling_timezone
}

# Provisioner scale down (1815 ET - 15 min after 1800)
resource "aws_autoscaling_schedule" "prov_scale_down" {
  count = var.enable_autoscaling_schedules ? 1 : 0

  scheduled_action_name  = "${var.cluster_name}-prov-scale-down"
  autoscaling_group_name = aws_eks_node_group.provisioner.resources[0].autoscaling_groups[0].name
  min_size               = var.prov_node_min_size
  max_size               = var.prov_node_max_size
  desired_capacity       = var.prov_node_min_size
  recurrence             = var.scaling_schedule_stop
  time_zone              = var.scaling_timezone
}

# Workspace scale up (0645 ET - 15 min before 0700)
# Pre-provisions nodes for morning workspace startups to reduce latency
resource "aws_autoscaling_schedule" "ws_scale_up" {
  count = var.enable_autoscaling_schedules ? 1 : 0

  scheduled_action_name  = "${var.cluster_name}-ws-scale-up"
  autoscaling_group_name = aws_eks_node_group.workspace.resources[0].autoscaling_groups[0].name
  min_size               = var.ws_node_desired_peak
  max_size               = var.ws_node_max_size
  desired_capacity       = var.ws_node_desired_peak
  recurrence             = var.scaling_schedule_start
  time_zone              = var.scaling_timezone
}

# Workspace scale down (1815 ET - 15 min after 1800)
resource "aws_autoscaling_schedule" "ws_scale_down" {
  count = var.enable_autoscaling_schedules ? 1 : 0

  scheduled_action_name  = "${var.cluster_name}-ws-scale-down"
  autoscaling_group_name = aws_eks_node_group.workspace.resources[0].autoscaling_groups[0].name
  min_size               = var.ws_node_min_size
  max_size               = var.ws_node_max_size
  desired_capacity       = var.ws_node_min_size
  recurrence             = var.scaling_schedule_stop
  time_zone              = var.scaling_timezone
}
