# Example: Toolchain Template and Infrastructure Base Pairings
#
# This example demonstrates how to compose toolchain templates with
# infrastructure base modules to create runnable Coder templates.
#
# Requirements Covered: 11c.7, 11c.8, 11d.7, 16.4
#
# Architecture:
#   Toolchain Template (portable) + Infrastructure Base (instance-specific)
#   = Composed Coder Template
#
# Usage:
#   terraform init
#   terraform plan
#   terraform apply

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.0.0"
    }
  }
}

# =============================================================================
# Variables
# =============================================================================

variable "compute_profile_name" {
  description = "Compute profile t-shirt size"
  type        = string
  default     = "sw-dev-medium"

  validation {
    condition = contains([
      "sw-dev-small",
      "sw-dev-medium",
      "sw-dev-large",
      "platform-devsecops",
      "datasci-standard",
      "datasci-large",
      "datasci-xlarge"
    ], var.compute_profile_name)
    error_message = "Invalid compute profile name."
  }
}

# =============================================================================
# Compute Profile Mapping
# =============================================================================

locals {
  compute_profiles = {
    "sw-dev-small" = {
      cpu       = 2
      memory    = "4Gi"
      storage   = "20Gi"
      gpu_count = 0
      gpu_type  = null
    }
    "sw-dev-medium" = {
      cpu       = 4
      memory    = "8Gi"
      storage   = "50Gi"
      gpu_count = 0
      gpu_type  = null
    }
    "sw-dev-large" = {
      cpu       = 8
      memory    = "16Gi"
      storage   = "100Gi"
      gpu_count = 0
      gpu_type  = null
    }
    "platform-devsecops" = {
      cpu       = 4
      memory    = "8Gi"
      storage   = "100Gi"
      gpu_count = 0
      gpu_type  = null
    }
    "datasci-standard" = {
      cpu       = 8
      memory    = "32Gi"
      storage   = "500Gi"
      gpu_count = 0
      gpu_type  = null
    }
    "datasci-large" = {
      cpu       = 16
      memory    = "64Gi"
      storage   = "1Ti"
      gpu_count = 1
      gpu_type  = "nvidia-t4"
    }
    "datasci-xlarge" = {
      cpu       = 32
      memory    = "64Gi"
      storage   = "2Ti"
      gpu_count = 4
      gpu_type  = "nvidia-a100"
    }
  }

  selected_profile = local.compute_profiles[var.compute_profile_name]
}

# =============================================================================
# Coder Data Sources
# =============================================================================

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# =============================================================================
# EXAMPLE 1: Pod Software Development
# Pairing: swdev-toolchain + base-k8s
# =============================================================================

# Source the toolchain template (portable layer)
module "swdev_toolchain" {
  source = "../../modules/coder/template-architecture/toolchains/swdev-toolchain"
}

# Validate the composition
module "swdev_validation" {
  source = "../../modules/coder/template-architecture/validation"

  toolchain_capabilities = module.swdev_toolchain.capabilities
  base_platform          = "kubernetes"

  override_policy = {
    allow_network_override  = false
    allow_identity_override = false
  }
}

# Source the infrastructure base (instance-specific layer)
module "swdev_infra" {
  source = "../../modules/coder/template-architecture/bases/base-k8s"

  workspace_name = data.coder_workspace.me.name
  owner          = data.coder_workspace_owner.me.name

  compute_profile = local.selected_profile
  image_id        = module.swdev_toolchain.image_id
  capabilities    = module.swdev_toolchain.capabilities

  # Provenance tracking
  toolchain_template = {
    name    = "swdev-toolchain"
    version = module.swdev_toolchain.version
  }
  base_module = {
    name    = "base-k8s"
    version = "1.0.0"
  }

  depends_on = [module.swdev_validation]
}

# Configure Coder agent
resource "coder_agent" "swdev" {
  os   = module.swdev_infra.metadata.os
  arch = module.swdev_infra.metadata.arch

  startup_script = module.swdev_toolchain.bootstrap_script
  env            = module.swdev_infra.runtime_env

  metadata {
    key          = "toolchain"
    display_name = "Toolchain"
    value        = "swdev-toolchain@${module.swdev_toolchain.version}"
  }

  metadata {
    key          = "base"
    display_name = "Infrastructure Base"
    value        = "base-k8s@1.0.0"
  }
}

# =============================================================================
# EXAMPLE 2: Windows Development with GUI
# Pairing: windev-toolchain + base-ec2-windows
# =============================================================================

# Source the toolchain template
module "windev_toolchain" {
  source = "../../modules/coder/template-architecture/toolchains/windev-toolchain"
}

# Validate the composition
module "windev_validation" {
  source = "../../modules/coder/template-architecture/validation"

  toolchain_capabilities = module.windev_toolchain.capabilities
  base_platform          = "ec2-windows"

  override_policy = {
    allow_network_override  = false
    allow_identity_override = false
  }
}

# Source the infrastructure base
module "windev_infra" {
  source = "../../modules/coder/template-architecture/bases/base-ec2-windows"

  workspace_name = data.coder_workspace.me.name
  owner          = data.coder_workspace_owner.me.name

  compute_profile = {
    cpu       = 4
    memory    = "16Gi"
    storage   = "100Gi"
    gpu_count = 0
    gpu_type  = null
  }
  image_id     = module.windev_toolchain.image_id
  capabilities = module.windev_toolchain.capabilities

  toolchain_template = {
    name    = "windev-toolchain"
    version = module.windev_toolchain.version
  }
  base_module = {
    name    = "base-ec2-windows"
    version = "1.0.0"
  }

  depends_on = [module.windev_validation]
}

# Configure Coder agent for Windows
resource "coder_agent" "windev" {
  os   = module.windev_infra.metadata.os
  arch = module.windev_infra.metadata.arch

  startup_script = module.windev_toolchain.bootstrap_script
  env            = module.windev_infra.runtime_env

  metadata {
    key          = "toolchain"
    display_name = "Toolchain"
    value        = "windev-toolchain@${module.windev_toolchain.version}"
  }

  metadata {
    key          = "base"
    display_name = "Infrastructure Base"
    value        = "base-ec2-windows@1.0.0"
  }
}

# =============================================================================
# EXAMPLE 3: Data Science with GPU
# Pairing: datasci-toolchain + base-ec2-gpu
# =============================================================================

# Source the toolchain template
module "datasci_toolchain" {
  source = "../../modules/coder/template-architecture/toolchains/datasci-toolchain"
}

# Validate the composition
module "datasci_validation" {
  source = "../../modules/coder/template-architecture/validation"

  toolchain_capabilities = module.datasci_toolchain.capabilities
  base_platform          = "ec2-gpu"

  override_policy = {
    allow_network_override  = false
    allow_identity_override = false
  }
}

# Source the infrastructure base
module "datasci_infra" {
  source = "../../modules/coder/template-architecture/bases/base-ec2-gpu"

  workspace_name = data.coder_workspace.me.name
  owner          = data.coder_workspace_owner.me.name

  compute_profile = local.compute_profiles["datasci-large"]
  image_id        = module.datasci_toolchain.image_id
  capabilities    = module.datasci_toolchain.capabilities

  toolchain_template = {
    name    = "datasci-toolchain"
    version = module.datasci_toolchain.version
  }
  base_module = {
    name    = "base-ec2-gpu"
    version = "1.0.0"
  }

  depends_on = [module.datasci_validation]
}

# Configure Coder agent for GPU workspace
resource "coder_agent" "datasci" {
  os   = module.datasci_infra.metadata.os
  arch = module.datasci_infra.metadata.arch

  startup_script = module.datasci_toolchain.bootstrap_script
  env            = module.datasci_infra.runtime_env

  metadata {
    key          = "toolchain"
    display_name = "Toolchain"
    value        = "datasci-toolchain@${module.datasci_toolchain.version}"
  }

  metadata {
    key          = "base"
    display_name = "Infrastructure Base"
    value        = "base-ec2-gpu@1.0.0"
  }

  metadata {
    key          = "gpu"
    display_name = "GPU"
    value        = "${local.compute_profiles["datasci-large"].gpu_count}x ${local.compute_profiles["datasci-large"].gpu_type}"
  }
}

# =============================================================================
# Composition Module Usage (Alternative Approach)
# =============================================================================

# The composition module provides a higher-level abstraction
module "composed_pod_swdev" {
  source = "../../modules/coder/template-architecture/composition"

  toolchain_name    = "swdev-toolchain"
  toolchain_version = "1.0.0"
  base_name         = "base-k8s"
  base_version      = "1.0.0"

  workspace_name       = data.coder_workspace.me.name
  owner                = data.coder_workspace_owner.me.name
  compute_profile_name = var.compute_profile_name
}

# =============================================================================
# Outputs
# =============================================================================

output "swdev_provenance" {
  description = "Software development template provenance"
  value = {
    toolchain = "swdev-toolchain@${module.swdev_toolchain.version}"
    base      = "base-k8s@1.0.0"
    platform  = module.swdev_infra.metadata.platform
    os        = module.swdev_infra.metadata.os
    arch      = module.swdev_infra.metadata.arch
  }
}

output "windev_provenance" {
  description = "Windows development template provenance"
  value = {
    toolchain = "windev-toolchain@${module.windev_toolchain.version}"
    base      = "base-ec2-windows@1.0.0"
    platform  = module.windev_infra.metadata.platform
    os        = module.windev_infra.metadata.os
    arch      = module.windev_infra.metadata.arch
  }
}

output "datasci_provenance" {
  description = "Data science template provenance"
  value = {
    toolchain = "datasci-toolchain@${module.datasci_toolchain.version}"
    base      = "base-ec2-gpu@1.0.0"
    platform  = module.datasci_infra.metadata.platform
    os        = module.datasci_infra.metadata.os
    arch      = module.datasci_infra.metadata.arch
    gpu       = "${local.compute_profiles["datasci-large"].gpu_count}x ${local.compute_profiles["datasci-large"].gpu_type}"
  }
}

output "composition_provenance" {
  description = "Composition module provenance record"
  value       = module.composed_pod_swdev.provenance
}
