# Default Template Pairings - Main
# Requirement 11c.8: Instance administrators select toolchain + base pairings
#
# This module defines the default pairings between toolchain templates and
# infrastructure base modules.

terraform {
  required_version = ">= 1.0"
}

# =============================================================================
# PAIRING DEFINITIONS
# =============================================================================

locals {
  # Define all available pairings
  # Requirement 11c.8: swdev-toolchain + base-k8s → pod-swdev
  #                    windev-toolchain + base-ec2-windows → ec2-windev-gui
  #                    datasci-toolchain + base-ec2-linux → ec2-datasci
  #                    datasci-toolchain + base-ec2-gpu → ec2-datasci-gpu

  all_pairings = {
    "pod-swdev" = {
      toolchain_name = "swdev-toolchain"
      base_name      = "base-k8s"
      display_name   = "Pod Software Development"
      description    = "Kubernetes pod-based workspace for software development with Go, Node.js, Python, and DevOps tools"
      icon           = "/icon/code.svg"
      tags           = ["pod", "development", "linux"]
      platform       = "kubernetes"

      # Default compute profile
      default_compute_profile = "sw-dev-medium"
      allowed_compute_profiles = [
        "sw-dev-small",
        "sw-dev-medium",
        "sw-dev-large",
        "platform-devsecops"
      ]

      # Capabilities
      capabilities = {
        persistent_home   = true
        network_egress    = "https-only"
        identity_mode     = "iam"
        gpu_support       = false
        artifact_cache    = false
        secrets_injection = "variables"
        gui_vnc           = false
        gui_rdp           = false
      }

      # Auto-stop configuration (Requirements 5.9, 13.1, 13.2)
      autostop_days_of_week = ["monday", "tuesday", "wednesday", "thursday", "friday"]
    }

    "ec2-windev-gui" = {
      toolchain_name = "windev-toolchain"
      base_name      = "base-ec2-windows"
      display_name   = "EC2 Windows Development"
      description    = "EC2-based Windows Server 2022 workspace with Visual Studio, NICE DCV remote desktop"
      icon           = "/icon/windows.svg"
      tags           = ["ec2", "windows", "gui", "development"]
      platform       = "ec2-windows"

      default_compute_profile = "sw-dev-medium"
      allowed_compute_profiles = [
        "sw-dev-medium",
        "sw-dev-large"
      ]

      capabilities = {
        persistent_home   = true
        network_egress    = "https-only"
        identity_mode     = "iam"
        gpu_support       = false
        artifact_cache    = false
        secrets_injection = "variables"
        gui_vnc           = false
        gui_rdp           = true
      }

      autostop_days_of_week = ["monday", "tuesday", "wednesday", "thursday", "friday"]
    }

    "ec2-datasci" = {
      toolchain_name = "datasci-toolchain"
      base_name      = "base-ec2-linux"
      display_name   = "EC2 Data Science"
      description    = "EC2-based data science workspace with Jupyter Lab, Python, R, and ML tooling (CPU)"
      icon           = "/icon/jupyter.svg"
      tags           = ["ec2", "data-science", "ml", "linux"]
      platform       = "ec2-linux"

      default_compute_profile = "datasci-standard"
      allowed_compute_profiles = [
        "datasci-standard",
        "datasci-large"
      ]

      capabilities = {
        persistent_home   = true
        network_egress    = "https-only"
        identity_mode     = "iam"
        gpu_support       = false
        artifact_cache    = true
        secrets_injection = "variables"
        gui_vnc           = false
        gui_rdp           = false
      }

      autostop_days_of_week = ["monday", "tuesday", "wednesday", "thursday", "friday"]
    }

    "ec2-datasci-gpu" = {
      toolchain_name = "datasci-toolchain"
      base_name      = "base-ec2-gpu"
      display_name   = "EC2 Data Science (GPU)"
      description    = "EC2-based data science workspace with GPU support, CUDA, PyTorch, TensorFlow"
      icon           = "/icon/gpu.svg"
      tags           = ["ec2", "gpu", "data-science", "ml"]
      platform       = "ec2-gpu"

      default_compute_profile = "datasci-large"
      allowed_compute_profiles = [
        "datasci-large",
        "datasci-xlarge"
      ]

      capabilities = {
        persistent_home   = true
        network_egress    = "https-only"
        identity_mode     = "iam"
        gpu_support       = true
        artifact_cache    = true
        secrets_injection = "variables"
        gui_vnc           = false
        gui_rdp           = false
      }

      autostop_days_of_week = ["monday", "tuesday", "wednesday", "thursday", "friday"]
    }
  }

  # Filter to only enabled pairings
  enabled_pairing_configs = {
    for name, config in local.all_pairings :
    name => config if contains(var.enabled_pairings, name)
  }
}

# =============================================================================
# PAIRING CONFIGURATIONS WITH VERSIONS
# =============================================================================

locals {
  # Build full pairing configurations with versions and sources
  pairing_configs = {
    for name, config in local.enabled_pairing_configs :
    name => merge(config, {
      # Version information
      toolchain_version = lookup(var.toolchain_versions, config.toolchain_name, "1.0.0")
      base_version      = lookup(var.base_versions, config.base_name, "1.0.0")

      # Source URLs
      toolchain_source = var.toolchain_source_base != "" ? "${var.toolchain_source_base}//${config.toolchain_name}" : ""
      base_source      = var.base_source_base != "" ? "${var.base_source_base}//${config.base_name}" : ""

      # Infrastructure context
      namespace          = var.namespace
      storage_class      = var.storage_class
      aws_region         = var.aws_region
      vpc_id             = var.vpc_id
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids

      # Template lifecycle configuration
      default_ttl_ms                 = var.default_ttl_ms
      activity_bump_ms               = var.activity_bump_ms
      failure_ttl_ms                 = var.failure_ttl_ms
      time_til_dormant_ms            = var.time_til_dormant_ms
      time_til_dormant_autodelete_ms = var.time_til_dormant_autodelete_ms

      # Tags
      tags = merge(var.tags, {
        "coder.pairing"           = name
        "coder.toolchain"         = config.toolchain_name
        "coder.base"              = config.base_name
        "coder.toolchain-version" = lookup(var.toolchain_versions, config.toolchain_name, "1.0.0")
        "coder.base-version"      = lookup(var.base_versions, config.base_name, "1.0.0")
      })
    })
  }
}

# =============================================================================
# PAIRING METADATA
# =============================================================================

locals {
  # Generate metadata for each pairing
  pairing_metadata = {
    for name, config in local.pairing_configs :
    name => {
      name              = name
      display_name      = config.display_name
      description       = config.description
      toolchain         = config.toolchain_name
      toolchain_version = config.toolchain_version
      base              = config.base_name
      base_version      = config.base_version
      platform          = config.platform
      capabilities      = config.capabilities
      compute_profiles  = config.allowed_compute_profiles
      default_profile   = config.default_compute_profile
    }
  }
}
