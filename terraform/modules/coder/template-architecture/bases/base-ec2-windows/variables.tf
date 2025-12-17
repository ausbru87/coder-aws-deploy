# Base-EC2-Windows Infrastructure Module - Variables
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
    condition     = var.compute_profile.cpu >= 2 && var.compute_profile.cpu <= 32
    error_message = "CPU count must be between 2 and 32 for Windows workspaces."
  }

  # GPU not supported on Windows
  validation {
    condition     = var.compute_profile.gpu_count == 0
    error_message = "GPU is not supported on Windows workspaces."
  }
}

variable "image_id" {
  type        = string
  description = "AMI ID for the workspace (leave empty to use default Windows Server 2022)"
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
    gui_rdp           = optional(bool, true)
  })
  description = "Capabilities requested by the toolchain template"
  default     = {}

  validation {
    condition     = contains(["none", "https-only", "unrestricted"], var.capabilities.network_egress)
    error_message = "Network egress must be one of: none, https-only, unrestricted."
  }

  validation {
    condition     = !var.capabilities.gpu_support
    error_message = "GPU support is not available on Windows workspaces."
  }

  validation {
    condition     = !var.capabilities.gui_vnc
    error_message = "VNC is not supported on Windows. Use gui_rdp instead."
  }

  validation {
    condition     = var.capabilities.gui_rdp
    error_message = "Windows workspaces require gui_rdp capability."
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
    name    = "base-ec2-windows"
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

variable "remote_desktop_type" {
  type        = string
  description = "Remote desktop protocol: dcv (NICE DCV) or webrdp"
  default     = "dcv"

  validation {
    condition     = contains(["dcv", "webrdp"], var.remote_desktop_type)
    error_message = "Remote desktop type must be one of: dcv, webrdp."
  }
}

variable "ami_owners" {
  type        = list(string)
  description = "AMI owner account IDs for AMI lookup"
  default     = ["amazon"]
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
  description = "Coder agent initialization script (PowerShell)"
  default     = ""
}

variable "windows_password" {
  type        = string
  description = "Password for the coder Windows user"
  sensitive   = true
  default     = "CoderWorkspace123!"
}
