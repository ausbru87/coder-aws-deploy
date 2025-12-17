# Software Development Toolchain - Terraform Outputs
# These outputs are consumed by infrastructure base modules during composition.
#
# Requirements Covered:
# - 11c.2: Toolchain template declares capabilities without infrastructure details
# - 11d.2: Specify toolchain template inputs (capabilities, compute profile)
# - 11f.1: Write toolchain templates once without infrastructure-specific details

# ============================================================================
# TOOLCHAIN METADATA
# ============================================================================

output "name" {
  description = "Toolchain template name"
  value       = "swdev-toolchain"
}

output "version" {
  description = "Toolchain template version"
  value       = "1.0.0"
}

output "description" {
  description = "Toolchain description"
  value       = "Software development workspace with Go, Node.js, Python, and DevOps tools"
}

# ============================================================================
# CAPABILITY DECLARATIONS
# These are passed to infrastructure base modules
# ============================================================================

output "capabilities" {
  description = "Capabilities required by this toolchain"
  value = {
    persistent_home   = true
    network_egress    = "https-only"
    identity_mode     = "iam"
    gpu_support       = false
    artifact_cache    = false
    secrets_injection = "variables"
    gui_vnc           = var.enable_gui
    gui_rdp           = false
  }
}

# ============================================================================
# COMPUTE PROFILE
# Resolved compute resources based on selected t-shirt size
# ============================================================================

locals {
  compute_profiles = {
    sw-dev-small = {
      cpu       = 2
      memory    = "4Gi"
      storage   = "20Gi"
      gpu_count = 0
      gpu_type  = null
    }
    sw-dev-medium = {
      cpu       = 4
      memory    = "8Gi"
      storage   = "50Gi"
      gpu_count = 0
      gpu_type  = null
    }
    sw-dev-large = {
      cpu       = 8
      memory    = "16Gi"
      storage   = "100Gi"
      gpu_count = 0
      gpu_type  = null
    }
    platform-devsecops = {
      cpu       = 4
      memory    = "8Gi"
      storage   = "100Gi"
      gpu_count = 0
      gpu_type  = null
    }
  }
}

output "compute_profile" {
  description = "Resolved compute profile for the selected t-shirt size"
  value       = local.compute_profiles[var.compute_profile]
}

output "compute_profile_name" {
  description = "Name of the selected compute profile"
  value       = var.compute_profile
}

# ============================================================================
# BOOTSTRAP CONFIGURATION
# Scripts and environment for workspace initialization
# ============================================================================

output "bootstrap_script" {
  description = "Startup script for workspace initialization"
  value       = <<-EOT
    #!/bin/bash
    set -e
    
    echo "Initializing software development workspace..."
    
    # Configure Git if not already configured
    if [ -z "$(git config --global user.email)" ]; then
      echo "Git user.email not configured - will be set via Coder external auth"
    fi
    
    # Ensure common directories exist
    mkdir -p ~/projects ~/bin ~/.local/bin ~/.profile.d
    
    # Add local bin to PATH if not present
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile.d/path.sh
    fi
    
    # Configure Go environment
    mkdir -p ~/go/{bin,src,pkg}
    echo 'export GOPATH="$HOME/go"' >> ~/.profile.d/go.sh
    echo 'export PATH="$GOPATH/bin:$PATH"' >> ~/.profile.d/go.sh
    
    # Source profile additions
    for f in ~/.profile.d/*.sh; do
      [ -f "$f" ] && source "$f"
    done
    
    ${var.custom_startup_script}
    
    echo "Software development workspace ready!"
  EOT
}

output "environment_variables" {
  description = "Environment variables to set in the workspace"
  value = {
    EDITOR = "code --wait"
    VISUAL = "code --wait"
    GOPATH = "$HOME/go"
    LANG   = "en_US.UTF-8"
    LC_ALL = "en_US.UTF-8"
  }
}

# ============================================================================
# TOOLCHAIN COMPONENTS
# Information about installed languages and tools
# ============================================================================

output "languages" {
  description = "Programming languages included in this toolchain"
  value = {
    go = {
      version         = "1.23"
      package_manager = "go mod"
    }
    node = {
      version         = "22"
      package_manager = "npm"
    }
    python = {
      version         = "3.12"
      package_manager = "pip"
    }
  }
}

output "tools" {
  description = "Tools included in this toolchain"
  value = concat(
    [
      "terraform",
      "kubectl",
      "gh",
      "git",
      "make",
      "jq",
      "yq"
    ],
    var.enable_docker ? ["docker-cli"] : [],
    var.install_aws_cli ? ["aws-cli"] : [],
    var.install_helm ? ["helm"] : [],
    var.install_k9s ? ["k9s"] : []
  )
}

# ============================================================================
# IMAGE REFERENCE
# Container image or artifact reference for this toolchain
# ============================================================================

output "image_id" {
  description = "Container image reference for this toolchain"
  value       = "ghcr.io/org/toolchains/swdev:1.0.0"
}

output "supported_os" {
  description = "Operating systems supported by this toolchain"
  value       = ["amazon-linux-2023", "ubuntu-22.04", "ubuntu-24.04"]
}

# ============================================================================
# VALIDATION
# Health check commands for verifying toolchain installation
# ============================================================================

output "health_checks" {
  description = "Commands to verify toolchain is correctly installed"
  value = [
    {
      name             = "go_version"
      command          = "go version"
      expected_pattern = "go1\\.23"
    },
    {
      name             = "node_version"
      command          = "node --version"
      expected_pattern = "v22\\."
    },
    {
      name             = "python_version"
      command          = "python3 --version"
      expected_pattern = "Python 3\\.12"
    },
    {
      name             = "terraform_available"
      command          = "terraform version"
      expected_pattern = "Terraform v"
    },
    {
      name             = "kubectl_available"
      command          = "kubectl version --client"
      expected_pattern = "Client Version"
    }
  ]
}
