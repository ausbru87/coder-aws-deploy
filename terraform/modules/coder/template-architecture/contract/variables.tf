# Template Contract - Terraform Variable Definitions
# These variables define the contract inputs that infrastructure base modules MUST accept.
#
# Requirements Covered:
# - 11d.1: Define minimal, stable interface between toolchain and infrastructure layers
# - 11d.2: Specify toolchain template inputs
# - 11d.4: Specify infrastructure base inputs (workspace_name, owner, compute_profile, image_id)

# ============================================================================
# CONTRACT INPUTS
# Infrastructure base modules MUST accept these variables
# ============================================================================

variable "workspace_name" {
  type        = string
  description = "The name of the workspace being provisioned. Sourced from data.coder_workspace.me.name"

  validation {
    condition     = length(var.workspace_name) > 0 && length(var.workspace_name) <= 64
    error_message = "Workspace name must be between 1 and 64 characters."
  }

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.workspace_name)) || length(var.workspace_name) == 1
    error_message = "Workspace name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "owner" {
  type        = string
  description = "The username of the workspace owner. Sourced from data.coder_workspace_owner.me.name"

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
    error_message = "Memory must be in Kubernetes resource format (e.g., '8Gi', '32Gi')."
  }

  validation {
    condition     = can(regex("^[0-9]+[KMGT]i$", var.compute_profile.storage))
    error_message = "Storage must be in Kubernetes resource format (e.g., '100Gi', '1Ti')."
  }

  validation {
    condition     = var.compute_profile.gpu_count >= 0 && var.compute_profile.gpu_count <= 8
    error_message = "GPU count must be between 0 and 8."
  }

  validation {
    condition     = var.compute_profile.gpu_count == 0 || var.compute_profile.gpu_type != null
    error_message = "GPU type must be specified when gpu_count > 0."
  }

  validation {
    condition = var.compute_profile.gpu_type == null || contains(
      ["nvidia-t4", "nvidia-a10g", "nvidia-v100", "nvidia-a100"],
      var.compute_profile.gpu_type
    )
    error_message = "GPU type must be one of: nvidia-t4, nvidia-a10g, nvidia-v100, nvidia-a100."
  }
}

variable "image_id" {
  type        = string
  description = "The toolchain image reference or identifier (container image digest, AMI ID, or artifact reference)"

  validation {
    condition     = length(var.image_id) > 0
    error_message = "Image ID must not be empty."
  }
}

# ============================================================================
# CAPABILITY INPUTS
# Toolchain templates declare these capabilities; infrastructure bases implement them
# ============================================================================

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

  validation {
    condition     = contains(["variables", "vault", "secrets-manager"], var.capabilities.secrets_injection)
    error_message = "Secrets injection must be one of: variables, vault, secrets-manager."
  }

  validation {
    condition     = !(var.capabilities.gui_vnc && var.capabilities.gui_rdp)
    error_message = "Cannot enable both gui_vnc and gui_rdp simultaneously."
  }
}

# ============================================================================
# METADATA INPUTS
# Additional context for composition and provenance tracking
# ============================================================================

variable "toolchain_template" {
  type = object({
    name    = string
    version = string
    source  = optional(string, "")
  })
  description = "Information about the toolchain template being composed"

  validation {
    condition     = length(var.toolchain_template.name) > 0
    error_message = "Toolchain template name must not be empty."
  }

  validation {
    condition     = can(regex("^v?[0-9]+\\.[0-9]+\\.[0-9]+", var.toolchain_template.version))
    error_message = "Toolchain template version must follow semantic versioning (e.g., '1.2.0' or 'v1.2.0')."
  }
}

variable "base_module" {
  type = object({
    name    = string
    version = string
    source  = optional(string, "")
  })
  description = "Information about the infrastructure base module"

  validation {
    condition     = length(var.base_module.name) > 0
    error_message = "Base module name must not be empty."
  }

  validation {
    condition     = can(regex("^v?[0-9]+\\.[0-9]+\\.[0-9]+", var.base_module.version))
    error_message = "Base module version must follow semantic versioning (e.g., '3.1.0' or 'v3.1.0')."
  }
}

# ============================================================================
# OVERRIDE INPUTS
# Controlled overrides that can be applied during composition
# ============================================================================

variable "overrides" {
  type = object({
    environment_variables = optional(map(string), {})
    labels                = optional(map(string), {})
    annotations           = optional(map(string), {})
  })
  description = "Controlled overrides applied during template composition"
  default     = {}
}

