# Template Composition Module - Variables
# Requirements: 11c.7, 11d.7
#
# This module composes toolchain templates with infrastructure base modules.

# =============================================================================
# TOOLCHAIN TEMPLATE CONFIGURATION
# =============================================================================

variable "toolchain_name" {
  type        = string
  description = "Name of the toolchain template to compose"

  validation {
    condition     = contains(["swdev-toolchain", "windev-toolchain", "datasci-toolchain"], var.toolchain_name)
    error_message = "Toolchain name must be one of: swdev-toolchain, windev-toolchain, datasci-toolchain."
  }
}

variable "toolchain_version" {
  type        = string
  description = "Version of the toolchain template (semantic versioning)"

  validation {
    condition     = can(regex("^v?[0-9]+\\.[0-9]+\\.[0-9]+", var.toolchain_version))
    error_message = "Toolchain version must follow semantic versioning (e.g., '1.0.0' or 'v1.0.0')."
  }
}

variable "toolchain_source" {
  type        = string
  description = "Source URL for the toolchain template (Git URL or local path)"
  default     = ""
}

# =============================================================================
# INFRASTRUCTURE BASE CONFIGURATION
# =============================================================================

variable "base_name" {
  type        = string
  description = "Name of the infrastructure base module to compose"

  validation {
    condition     = contains(["base-k8s", "base-ec2-linux", "base-ec2-windows", "base-ec2-gpu"], var.base_name)
    error_message = "Base name must be one of: base-k8s, base-ec2-linux, base-ec2-windows, base-ec2-gpu."
  }
}

variable "base_version" {
  type        = string
  description = "Version of the infrastructure base module (semantic versioning)"

  validation {
    condition     = can(regex("^v?[0-9]+\\.[0-9]+\\.[0-9]+", var.base_version))
    error_message = "Base version must follow semantic versioning (e.g., '1.0.0' or 'v1.0.0')."
  }
}

variable "base_source" {
  type        = string
  description = "Source URL for the infrastructure base module (Git URL or local path)"
  default     = ""
}

# =============================================================================
# WORKSPACE CONTEXT
# =============================================================================

variable "workspace_name" {
  type        = string
  description = "Workspace name from data.coder_workspace.me.name"

  validation {
    condition     = length(var.workspace_name) > 0 && length(var.workspace_name) <= 64
    error_message = "Workspace name must be between 1 and 64 characters."
  }
}

variable "owner" {
  type        = string
  description = "Workspace owner from data.coder_workspace_owner.me.name"

  validation {
    condition     = length(var.owner) > 0 && length(var.owner) <= 64
    error_message = "Owner name must be between 1 and 64 characters."
  }
}

# =============================================================================
# COMPUTE PROFILE
# =============================================================================

variable "compute_profile_name" {
  type        = string
  description = "T-shirt size name for compute resources"

  validation {
    condition = contains([
      "sw-dev-small", "sw-dev-medium", "sw-dev-large",
      "platform-devsecops",
      "datasci-standard", "datasci-large", "datasci-xlarge"
    ], var.compute_profile_name)
    error_message = "Compute profile must be a valid t-shirt size."
  }
}

variable "compute_profile_override" {
  type = object({
    cpu       = optional(number)
    memory    = optional(string)
    storage   = optional(string)
    gpu_count = optional(number)
    gpu_type  = optional(string)
  })
  description = "Optional overrides for compute profile values"
  default     = {}
}

# =============================================================================
# CAPABILITY OVERRIDES
# =============================================================================

variable "capability_overrides" {
  type = object({
    persistent_home   = optional(bool)
    network_egress    = optional(string)
    identity_mode     = optional(string)
    gpu_support       = optional(bool)
    artifact_cache    = optional(bool)
    secrets_injection = optional(string)
    gui_vnc           = optional(bool)
    gui_rdp           = optional(bool)
  })
  description = "Optional overrides for capability values"
  default     = {}
}

# =============================================================================
# CONTROLLED OVERRIDES
# =============================================================================

variable "overrides" {
  type = object({
    environment_variables = optional(map(string), {})
    labels                = optional(map(string), {})
    annotations           = optional(map(string), {})
  })
  description = "Controlled overrides applied during template composition"
  default     = {}
}

# =============================================================================
# OVERRIDE POLICY
# =============================================================================

variable "override_policy" {
  type = object({
    allow_compute_override    = optional(bool, true)
    allow_env_override        = optional(bool, true)
    allow_label_override      = optional(bool, true)
    allow_annotation_override = optional(bool, true)
    allow_network_override    = optional(bool, false)
    allow_identity_override   = optional(bool, false)
    allow_privileged          = optional(bool, false)
    allow_mount_override      = optional(bool, false)
    blocked_env_prefixes      = optional(list(string), ["AWS_", "CODER_AGENT_"])
    blocked_labels            = optional(list(string), ["kubernetes.io/", "eks.amazonaws.com/"])
  })
  description = "Policy controlling which overrides are permitted"
  default     = {}
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
# COMPOSITION METADATA
# =============================================================================

variable "composed_template_name" {
  type        = string
  description = "Name for the composed template (e.g., 'pod-swdev')"
  default     = ""
}

variable "composed_template_description" {
  type        = string
  description = "Description for the composed template"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to composed resources"
  default     = {}
}
