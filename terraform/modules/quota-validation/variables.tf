# Quota Validation Module Variables
# Requirements: 2a.1, 2a.2, 2a.3, 2a.4, 2a.5

variable "aws_region" {
  description = "AWS region for quota checks"
  type        = string
}

variable "max_workspaces" {
  description = "Maximum number of concurrent workspaces for quota calculations"
  type        = number
  default     = 3000

  validation {
    condition     = var.max_workspaces > 0
    error_message = "max_workspaces must be greater than 0."
  }
}

variable "control_node_max_size" {
  description = "Maximum number of control plane nodes"
  type        = number
  default     = 3
}

variable "prov_node_max_size" {
  description = "Maximum number of provisioner nodes"
  type        = number
  default     = 20
}

variable "ws_node_max_size" {
  description = "Maximum number of workspace nodes"
  type        = number
  default     = 200
}

variable "control_node_instance_type" {
  description = "Instance type for control plane nodes"
  type        = string
  default     = "m5.large"
}

variable "prov_node_instance_type" {
  description = "Instance type for provisioner nodes"
  type        = string
  default     = "c5.2xlarge"
}

variable "ws_node_instance_type" {
  description = "Instance type for workspace nodes"
  type        = string
  default     = "m5.2xlarge"
}

variable "ws_use_spot_instances" {
  description = "Whether workspace nodes use spot instances"
  type        = bool
  default     = true
}

variable "average_workspace_storage_gb" {
  description = "Average storage per workspace in GB"
  type        = number
  default     = 100
}

variable "enable_gpu_workspaces" {
  description = "Enable GPU workspace quotas"
  type        = bool
  default     = true
}

variable "max_gpu_workspaces" {
  description = "Maximum number of GPU workspaces"
  type        = number
  default     = 50
}

variable "quota_buffer_percent" {
  description = "Buffer percentage to add to calculated quotas"
  type        = number
  default     = 20

  validation {
    condition     = var.quota_buffer_percent >= 0 && var.quota_buffer_percent <= 100
    error_message = "quota_buffer_percent must be between 0 and 100."
  }
}

variable "skip_quota_check" {
  description = "Skip quota validation (use with caution)"
  type        = bool
  default     = false
}

variable "auto_request_quota_increases" {
  description = "Automatically request quota increases if needed"
  type        = bool
  default     = false
}
