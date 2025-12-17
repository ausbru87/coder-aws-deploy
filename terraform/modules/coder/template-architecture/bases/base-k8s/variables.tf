# Base-K8s Infrastructure Module - Variables
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

  validation {
    condition     = can(regex("^[0-9]+[KMGT]i$", var.compute_profile.storage))
    error_message = "Storage must be in Kubernetes resource format (e.g., '100Gi')."
  }

  # Note: GPU not supported on Kubernetes pods - use EC2 GPU base module
  validation {
    condition     = var.compute_profile.gpu_count == 0
    error_message = "GPU workspaces are not supported on Kubernetes. Use base-ec2-gpu module."
  }
}

variable "image_id" {
  type        = string
  description = "The toolchain image reference (container image). Leave empty to use OS-based default."
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
    condition     = contains(["oidc", "iam", "workload-identity"], var.capabilities.identity_mode)
    error_message = "Identity mode must be one of: oidc, iam, workload-identity."
  }

  # GPU not supported on K8s pods
  validation {
    condition     = !var.capabilities.gpu_support
    error_message = "GPU support is not available on Kubernetes pods. Use base-ec2-gpu module."
  }

  # RDP not supported on K8s (Windows not supported)
  validation {
    condition     = !var.capabilities.gui_rdp
    error_message = "RDP is not supported on Kubernetes pods. Use base-ec2-windows module."
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
    name    = "base-k8s"
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
# KUBERNETES-SPECIFIC INPUTS
# ============================================================================

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for workspaces"
  default     = "coder-ws"
}

variable "storage_class" {
  type        = string
  description = "Storage class for persistent volumes (EBS-backed)"
  default     = "gp3-encrypted"
}

variable "workspace_iam_role_arn" {
  type        = string
  description = "IAM role ARN for IRSA (identity_mode = iam)"
  default     = ""
}

variable "image_registry" {
  type        = string
  description = "Private container registry URL (leave empty for public images)"
  default     = ""
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

variable "replica_count" {
  type        = number
  description = "Number of pod replicas (typically 1 for workspaces, 0 when stopped)"
  default     = 1
}

variable "startup_command" {
  type        = list(string)
  description = "Command to run when the container starts"
  default     = ["sh", "-c", "sleep infinity"]
}

variable "coder_agent_token" {
  type        = string
  description = "Coder agent token for authentication"
  sensitive   = true
  default     = ""
}

variable "additional_node_selectors" {
  type        = map(string)
  description = "Additional node selectors for pod scheduling"
  default     = {}
}

variable "kasmvnc_image" {
  type        = string
  description = "KasmVNC sidecar image for GUI workspaces"
  default     = "kasmweb/desktop:1.14.0"
}

variable "vnc_password" {
  type        = string
  description = "VNC password for GUI access"
  sensitive   = true
  default     = "coder"
}
