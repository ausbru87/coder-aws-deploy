# Base-EC2-Linux Infrastructure Module - Variables
# Contract inputs that this infrastructure base module accepts
#
# Requirements Covered:
# - 11d.1: Minimal, stable interface between toolchain and infrastructure layers
# - 11d.4: Infrastructure base inputs (workspace_name, owner, compute_profile, image_id)

# ============================================================================
# CONTRACT INPUTS (Required by all infrastructure base modules)
# ============================================================================

variable "workspace_name" {
  type        = string
  description = "The name of the workspace being provisioned"

  validation {
    condition     = length(var.workspace_name) > 0 && length(var.workspace_name) <= 64
    error_message = "Workspace name must be between 1 and 64 characters."
  }
}

variable "owner" {
  type        = string
  description = "The username of the workspace owner"

  validation {
    condition     = length(var.owner) > 0 && length(var.owner) <= 64
    error_message = "Owner name must be between 1 and 64 characters."
  }
}

variable "compute_profile" {
  type = object({
    cpu       = number
    memory    = string
    storage   = string
    gpu_count = optional(number, 0)
    gpu_type  = optional(string, null)
  })
  description = "Compute resources requested for the workspace"

  validation {
    condition     = var.compute_profile.cpu >= 1 && var.compute_profile.cpu <= 64
    error_message = "CPU count must be between 1 and 64."
  }

  validation {
    condition     = can(regex("^[0-9]+[KMGT]i$", var.compute_profile.memory))
    error_message = "Memory must be in Kubernetes resource format (e.g., '8Gi')."
  }

  # GPU not supported - use base-ec2-gpu module
  validation {
    condition     = var.compute_profile.gpu_count == 0
    error_message = "GPU workspaces should use base-ec2-gpu module."
  }
}

variable "image_id" {
  type        = string
  description = "AMI ID for the workspace (leave empty to use OS-based default)"
  default     = ""
}

variable "capabilities" {
  type = object({
    persistent_home   = optional(bool, true)
    network_egress    = optional(string, "https-only")
    identity_mode     = optional(string, "iam")
    gpu_support       = optional(bool, false)
    artifact_cache    = optional(bool, false)
    secrets_injection = optional(string, "variables")
    gui_vnc           = optional(bool, false)
    gui_rdp           = optional(bool, false)
  })
  description = "Capabilities requested by the toolchain template"
  default     = {}

  validation {
    condition     = contains(["none", "https-only", "unrestricted"], var.capabilities.network_egress)
    error_message = "Network egress must be one of: none, https-only, unrestricted."
  }

  validation {
    condition     = !var.capabilities.gpu_support
    error_message = "GPU support should use base-ec2-gpu module."
  }

  validation {
    condition     = !var.capabilities.gui_rdp
    error_message = "RDP is not supported on Linux. Use base-ec2-windows module."
  }
}

variable "toolchain_template" {
  type = object({
    name    = string
    version = string
    source  = optional(string, "")
  })
  description = "Information about the toolchain template being composed"
}

variable "base_module" {
  type = object({
    name    = string
    version = string
    source  = optional(string, "")
  })
  description = "Information about this infrastructure base module"
  default = {
    name    = "base-ec2-linux"
    version = "1.0.0"
  }
}

variable "overrides" {
  type = object({
    environment_variables = optional(map(string), {})
    labels                = optional(map(string), {})
    annotations           = optional(map(string), {})
  })
  description = "Controlled overrides applied during template composition"
  default     = {}
}

# ============================================================================
# EC2-SPECIFIC INPUTS
# ============================================================================

variable "vpc_id" {
  type        = string
  description = "VPC ID for the workspace"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for the workspace"
}

variable "availability_zone" {
  type        = string
  description = "Availability zone for EBS volumes"
}

variable "instance_profile_name" {
  type        = string
  description = "IAM instance profile name for the workspace"
}

variable "os_type" {
  type        = string
  description = "Operating system type for the workspace"
  default     = "ubuntu-22.04"

  validation {
    condition     = contains(["amazon-linux-2023", "ubuntu-22.04", "ubuntu-24.04"], var.os_type)
    error_message = "OS type must be one of: amazon-linux-2023, ubuntu-22.04, ubuntu-24.04."
  }
}

variable "ami_owners" {
  type        = list(string)
  description = "AMI owner account IDs for AMI lookup"
  default     = ["amazon", "099720109477"] # Amazon and Canonical
}

variable "default_instance_type" {
  type        = string
  description = "Default instance type if compute profile doesn't match"
  default     = "m5.xlarge"
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ID for EBS encryption"
  default     = null
}

variable "assign_elastic_ip" {
  type        = bool
  description = "Assign an Elastic IP to the instance"
  default     = false
}

variable "coder_agent_init_script" {
  type        = string
  description = "Coder agent initialization script"
  default     = ""
}

variable "vnc_password" {
  type        = string
  description = "VNC password for GUI access"
  sensitive   = true
  default     = "coder"
}
