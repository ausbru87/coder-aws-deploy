# Template Composition Module - Main
# Requirements: 11c.7, 11d.7
#
# This module implements the composition logic that combines toolchain templates
# with infrastructure base modules to produce deployable Coder templates.

terraform {
  required_version = ">= 1.0"
}

# =============================================================================
# COMPUTE PROFILE DEFINITIONS
# =============================================================================

locals {
  # Standard compute profiles (t-shirt sizes) per Requirement 14.16
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

  # Resolve compute profile with optional overrides
  base_compute_profile = local.compute_profiles[var.compute_profile_name]
  resolved_compute_profile = {
    cpu       = coalesce(var.compute_profile_override.cpu, local.base_compute_profile.cpu)
    memory    = coalesce(var.compute_profile_override.memory, local.base_compute_profile.memory)
    storage   = coalesce(var.compute_profile_override.storage, local.base_compute_profile.storage)
    gpu_count = coalesce(var.compute_profile_override.gpu_count, local.base_compute_profile.gpu_count)
    gpu_type  = coalesce(var.compute_profile_override.gpu_type, local.base_compute_profile.gpu_type)
  }
}

# =============================================================================
# TOOLCHAIN CAPABILITY DEFINITIONS
# =============================================================================

locals {
  # Default capabilities per toolchain template
  toolchain_capabilities = {
    "swdev-toolchain" = {
      required = ["persistent-home", "network-egress", "identity-mode"]
      optional = ["gui-vnc", "artifact-cache"]
    }
    "windev-toolchain" = {
      required = ["persistent-home", "network-egress", "identity-mode", "gui-rdp"]
      optional = []
    }
    "datasci-toolchain" = {
      required = ["persistent-home", "network-egress", "identity-mode"]
      optional = ["gpu-support", "gui-vnc", "artifact-cache"]
    }
  }

  # Default capability values per toolchain
  toolchain_capability_values = {
    "swdev-toolchain" = {
      persistent_home   = true
      network_egress    = "https-only"
      identity_mode     = "iam"
      gpu_support       = false
      artifact_cache    = false
      secrets_injection = "variables"
      gui_vnc           = false
      gui_rdp           = false
    }
    "windev-toolchain" = {
      persistent_home   = true
      network_egress    = "https-only"
      identity_mode     = "iam"
      gpu_support       = false
      artifact_cache    = false
      secrets_injection = "variables"
      gui_vnc           = false
      gui_rdp           = true
    }
    "datasci-toolchain" = {
      persistent_home   = true
      network_egress    = "https-only"
      identity_mode     = "iam"
      gpu_support       = local.resolved_compute_profile.gpu_count > 0
      artifact_cache    = true
      secrets_injection = "variables"
      gui_vnc           = false
      gui_rdp           = false
    }
  }

  # Resolve capabilities with optional overrides
  base_capabilities = local.toolchain_capability_values[var.toolchain_name]
  resolved_capabilities = {
    persistent_home   = coalesce(var.capability_overrides.persistent_home, local.base_capabilities.persistent_home)
    network_egress    = coalesce(var.capability_overrides.network_egress, local.base_capabilities.network_egress)
    identity_mode     = coalesce(var.capability_overrides.identity_mode, local.base_capabilities.identity_mode)
    gpu_support       = coalesce(var.capability_overrides.gpu_support, local.base_capabilities.gpu_support)
    artifact_cache    = coalesce(var.capability_overrides.artifact_cache, local.base_capabilities.artifact_cache)
    secrets_injection = coalesce(var.capability_overrides.secrets_injection, local.base_capabilities.secrets_injection)
    gui_vnc           = coalesce(var.capability_overrides.gui_vnc, local.base_capabilities.gui_vnc)
    gui_rdp           = coalesce(var.capability_overrides.gui_rdp, local.base_capabilities.gui_rdp)
  }
}

# =============================================================================
# PLATFORM MAPPING
# =============================================================================

locals {
  # Map base module names to platform types
  base_to_platform = {
    "base-k8s"         = "kubernetes"
    "base-ec2-linux"   = "ec2-linux"
    "base-ec2-windows" = "ec2-windows"
    "base-ec2-gpu"     = "ec2-gpu"
  }

  platform = local.base_to_platform[var.base_name]
}

# =============================================================================
# VALIDATION
# =============================================================================

module "validation" {
  source = "../validation"

  toolchain_capabilities = local.toolchain_capabilities[var.toolchain_name]
  base_platform          = local.platform

  requested_overrides = {
    compute_profile       = var.compute_profile_override != {} ? var.compute_profile_override : {}
    environment_variables = var.overrides.environment_variables
    labels                = var.overrides.labels
    annotations           = var.overrides.annotations
    network_policy        = var.capability_overrides.network_egress != null ? var.capability_overrides.network_egress : null
    identity_binding      = var.capability_overrides.identity_mode != null ? var.capability_overrides.identity_mode : null
    privileged            = null
    mount_permissions     = null
  }

  override_policy = var.override_policy
}

# =============================================================================
# IMAGE RESOLUTION
# =============================================================================

locals {
  # Default image references per toolchain
  toolchain_images = {
    "swdev-toolchain"   = "ghcr.io/org/toolchains/swdev:${var.toolchain_version}"
    "windev-toolchain"  = "ami-windev-${var.toolchain_version}"
    "datasci-toolchain" = "ghcr.io/org/toolchains/datasci:${var.toolchain_version}"
  }

  # Resolve image ID based on toolchain
  resolved_image_id = local.toolchain_images[var.toolchain_name]
}

# =============================================================================
# PROVENANCE RECORD (Requirement 11d.7)
# =============================================================================

locals {
  # Generate provenance record
  provenance = {
    toolchain = {
      name    = var.toolchain_name
      version = var.toolchain_version
      source  = var.toolchain_source != "" ? var.toolchain_source : "local://./toolchains/${var.toolchain_name}"
    }
    base = {
      name    = var.base_name
      version = var.base_version
      source  = var.base_source != "" ? var.base_source : "local://./bases/${var.base_name}"
    }
    artifacts = {
      image_id     = local.resolved_image_id
      image_digest = null # Would be resolved at deployment time
      ami_id       = local.platform == "ec2-linux" || local.platform == "ec2-windows" || local.platform == "ec2-gpu" ? local.resolved_image_id : null
    }
    composition = {
      composed_at       = timestamp()
      composed_by       = "terraform"
      compute_profile   = var.compute_profile_name
      capabilities      = local.resolved_capabilities
      validation_passed = module.validation.validation_passed
    }
  }
}

# =============================================================================
# COMPOSED CONFIGURATION
# =============================================================================

locals {
  # Generate composed template name if not provided
  default_template_name = "${replace(var.toolchain_name, "-toolchain", "")}-${replace(var.base_name, "base-", "")}"
  template_name         = var.composed_template_name != "" ? var.composed_template_name : local.default_template_name

  # Generate description if not provided
  default_description  = "Composed template: ${var.toolchain_name}@${var.toolchain_version} + ${var.base_name}@${var.base_version}"
  template_description = var.composed_template_description != "" ? var.composed_template_description : local.default_description

  # Composed configuration for infrastructure base module
  composed_config = {
    # Contract inputs
    workspace_name  = var.workspace_name
    owner           = var.owner
    compute_profile = local.resolved_compute_profile
    image_id        = local.resolved_image_id
    capabilities    = local.resolved_capabilities

    # Metadata inputs
    toolchain_template = {
      name    = var.toolchain_name
      version = var.toolchain_version
      source  = local.provenance.toolchain.source
    }
    base_module = {
      name    = var.base_name
      version = var.base_version
      source  = local.provenance.base.source
    }

    # Overrides
    overrides = var.overrides

    # Infrastructure context
    namespace          = var.namespace
    storage_class      = var.storage_class
    aws_region         = var.aws_region
    vpc_id             = var.vpc_id
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids

    # Tags
    tags = merge(var.tags, {
      "coder.toolchain"         = var.toolchain_name
      "coder.toolchain-version" = var.toolchain_version
      "coder.base"              = var.base_name
      "coder.base-version"      = var.base_version
      "coder.composed-at"       = local.provenance.composition.composed_at
    })
  }

  # Agent configuration for Coder
  agent_config = {
    os   = local.platform == "ec2-windows" ? "windows" : "linux"
    arch = "amd64"
    env = merge(var.overrides.environment_variables, {
      CODER_TOOLCHAIN         = var.toolchain_name
      CODER_TOOLCHAIN_VERSION = var.toolchain_version
      CODER_BASE              = var.base_name
      CODER_BASE_VERSION      = var.base_version
    })
  }
}

# =============================================================================
# VALIDATION CHECKPOINT
# =============================================================================

# This resource ensures composition fails if validation doesn't pass
resource "null_resource" "composition_checkpoint" {
  triggers = {
    validation_hash = sha256(jsonencode(local.provenance))
  }

  lifecycle {
    precondition {
      condition     = module.validation.validation_passed
      error_message = "Template composition failed validation. Missing capabilities: ${join(", ", module.validation.missing_capabilities)}. Override violations: ${join("; ", module.validation.override_violations)}"
    }
  }
}
