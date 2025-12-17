# Default Template Pairings - Variables
# Requirement 11c.8: Instance administrators select toolchain + base pairings

# =============================================================================
# PAIRING SELECTION
# =============================================================================

variable "enabled_pairings" {
  type        = list(string)
  description = "List of template pairings to enable"
  default     = ["pod-swdev", "ec2-windev-gui", "ec2-datasci", "ec2-datasci-gpu"]

  validation {
    condition = alltrue([
      for p in var.enabled_pairings : contains(
        ["pod-swdev", "ec2-windev-gui", "ec2-datasci", "ec2-datasci-gpu"],
        p
      )
    ])
    error_message = "Invalid pairing name. Valid pairings: pod-swdev, ec2-windev-gui, ec2-datasci, ec2-datasci-gpu."
  }
}

# =============================================================================
# VERSION CONFIGURATION
# =============================================================================

variable "toolchain_versions" {
  type        = map(string)
  description = "Version for each toolchain template"
  default = {
    "swdev-toolchain"   = "1.0.0"
    "windev-toolchain"  = "1.0.0"
    "datasci-toolchain" = "1.0.0"
  }
}

variable "base_versions" {
  type        = map(string)
  description = "Version for each infrastructure base module"
  default = {
    "base-k8s"         = "1.0.0"
    "base-ec2-linux"   = "1.0.0"
    "base-ec2-windows" = "1.0.0"
    "base-ec2-gpu"     = "1.0.0"
  }
}

# =============================================================================
# SOURCE CONFIGURATION
# =============================================================================

variable "toolchain_source_base" {
  type        = string
  description = "Base URL for toolchain template sources (Git URL or local path)"
  default     = ""
}

variable "base_source_base" {
  type        = string
  description = "Base URL for infrastructure base module sources (Git URL or local path)"
  default     = ""
}

# =============================================================================
# INFRASTRUCTURE CONTEXT
# =============================================================================

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for pod workspaces"
  default     = "coder-ws"
}

variable "storage_class" {
  type        = string
  description = "Storage class for persistent volumes"
  default     = "gp3-encrypted"
}

variable "aws_region" {
  type        = string
  description = "AWS region for EC2 workspaces"
  default     = "us-east-1"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for EC2 workspaces"
  default     = ""
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for EC2 workspaces"
  default     = []
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs for EC2 workspaces"
  default     = []
}

# =============================================================================
# TEMPLATE CONFIGURATION
# =============================================================================

variable "default_ttl_ms" {
  type        = number
  description = "Default TTL for workspaces in milliseconds (8 hours)"
  default     = 28800000
}

variable "activity_bump_ms" {
  type        = number
  description = "Activity bump duration in milliseconds (1 hour)"
  default     = 3600000
}

variable "failure_ttl_ms" {
  type        = number
  description = "TTL for failed builds in milliseconds (24 hours)"
  default     = 86400000
}

variable "time_til_dormant_ms" {
  type        = number
  description = "Time until workspace becomes dormant in milliseconds (7 days)"
  default     = 604800000
}

variable "time_til_dormant_autodelete_ms" {
  type        = number
  description = "Time until dormant workspace is auto-deleted in milliseconds (30 days)"
  default     = 2592000000
}

# =============================================================================
# TAGS
# =============================================================================

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
