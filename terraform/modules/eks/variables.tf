# EKS Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "control_subnet_ids" {
  description = "Subnet IDs for control plane nodes"
  type        = list(string)
}

variable "prov_subnet_ids" {
  description = "Subnet IDs for provisioner nodes"
  type        = list(string)
}

variable "ws_subnet_ids" {
  description = "Subnet IDs for workspace nodes"
  type        = list(string)
}

# Control Node Group
variable "control_node_instance_type" {
  description = "Instance type for control nodes"
  type        = string
}

variable "control_node_min_size" {
  description = "Minimum size for control node group"
  type        = number
}

variable "control_node_max_size" {
  description = "Maximum size for control node group"
  type        = number
}

# Provisioner Node Group
variable "prov_node_instance_type" {
  description = "Instance type for provisioner nodes"
  type        = string
}

variable "prov_node_min_size" {
  description = "Minimum size for provisioner node group"
  type        = number
}

variable "prov_node_max_size" {
  description = "Maximum size for provisioner node group"
  type        = number
}

variable "prov_node_desired_peak" {
  description = "Desired size for provisioner node group during peak hours"
  type        = number
  default     = 5
}

# Workspace Node Group
variable "ws_node_instance_type" {
  description = "Instance type for workspace nodes"
  type        = string
}

variable "ws_node_min_size" {
  description = "Minimum size for workspace node group"
  type        = number
}

variable "ws_node_max_size" {
  description = "Maximum size for workspace node group"
  type        = number
}

variable "ws_node_desired_peak" {
  description = "Desired size for workspace node group during peak hours (pre-provisioning)"
  type        = number
  default     = 50
}

variable "ws_use_spot_instances" {
  description = "Use spot instances for workspace nodes with on-demand fallback"
  type        = bool
}

# Scaling Schedules
variable "enable_autoscaling_schedules" {
  description = "Enable time-based autoscaling schedules (SR-HA feature)"
  type        = bool
  default     = false
}

variable "scaling_schedule_start" {
  description = "Cron expression for scaling up"
  type        = string
}

variable "scaling_schedule_stop" {
  description = "Cron expression for scaling down"
  type        = string
}

variable "scaling_timezone" {
  description = "Timezone for scaling schedules"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Kubernetes Controller Versions
# =============================================================================

variable "aws_lb_controller_version" {
  description = "Version of AWS Load Balancer Controller Helm chart"
  type        = string
  default     = "1.7.1"
}

variable "ebs_csi_driver_version" {
  description = "Version of EBS CSI Driver addon"
  type        = string
  default     = "v1.28.0-eksbuild.1"
}
