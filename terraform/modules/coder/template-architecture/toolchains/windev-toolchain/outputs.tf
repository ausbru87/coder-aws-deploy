# Windows Development Toolchain - Terraform Outputs
# These outputs are consumed by infrastructure base modules during composition.
#
# Requirements Covered:
# - 11c.2: Toolchain template declares capabilities without infrastructure details
# - 11d.2: Specify toolchain template inputs (capabilities, compute profile)

# ============================================================================
# TOOLCHAIN METADATA
# ============================================================================

output "name" {
  description = "Toolchain template name"
  value       = "windev-toolchain"
}

output "version" {
  description = "Toolchain template version"
  value       = "1.0.0"
}

output "description" {
  description = "Toolchain description"
  value       = "Windows development workspace with Visual Studio 2022, .NET 8, and Azure tools"
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
    gui_vnc           = false
    gui_rdp           = true # Windows requires RDP
  }
}

# ============================================================================
# COMPUTE PROFILE
# Resolved compute resources based on selected t-shirt size
# ============================================================================

locals {
  compute_profiles = {
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
  description = "Startup script for workspace initialization (PowerShell)"
  value       = <<-EOT
    # Windows Development Workspace Bootstrap
    # Toolchain: windev-toolchain v1.0.0
    
    Write-Host "=== Windows Development Workspace Bootstrap ==="
    Write-Host "Started at: $$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
    
    # Create standard directories
    $$directories = @(
        "$$env:USERPROFILE\Projects",
        "$$env:USERPROFILE\bin",
        "$$env:USERPROFILE\.config"
    )
    
    foreach ($$dir in $$directories) {
        if (-not (Test-Path $$dir)) {
            New-Item -ItemType Directory -Path $$dir -Force | Out-Null
            Write-Host "Created: $$dir"
        }
    }
    
    # Configure Git defaults
    $$gitEmail = git config --global user.email 2>$$null
    if (-not $$gitEmail) {
        Write-Host "Git user.email not configured - will be set via Coder external auth"
    }
    
    git config --global core.autocrlf true
    git config --global init.defaultBranch main
    
    # Verify toolchain installation
    Write-Host ""
    Write-Host "--- Toolchain Verification ---"
    
    # .NET SDK
    $$dotnetVersion = dotnet --version 2>$$null
    if ($$dotnetVersion) {
        Write-Host "  .NET SDK: $$dotnetVersion"
    } else {
        Write-Host "  .NET SDK: NOT FOUND"
    }
    
    # PowerShell
    Write-Host "  PowerShell: $$($$PSVersionTable.PSVersion)"
    
    # Git
    $$gitVersion = git --version 2>$$null
    if ($$gitVersion) {
        Write-Host "  Git: $$gitVersion"
    }
    
    # Azure CLI
    $$azVersion = az --version 2>$$null | Select-Object -First 1
    if ($$azVersion) {
        Write-Host "  Azure CLI: $$azVersion"
    }
    
    # Visual Studio
    $$vsPath = "$${env:ProgramFiles}\Microsoft Visual Studio\2022\${var.vs_edition}\Common7\IDE\devenv.exe"
    if (Test-Path $$vsPath) {
        Write-Host "  Visual Studio 2022 ${var.vs_edition}: OK"
    } else {
        Write-Host "  Visual Studio 2022: Not found"
    }
    
    ${var.custom_startup_script}
    
    Write-Host ""
    Write-Host "=== Workspace Ready ==="
    Write-Host "Completed at: $$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
  EOT
}

output "environment_variables" {
  description = "Environment variables to set in the workspace"
  value = {
    DOTNET_CLI_TELEMETRY_OPTOUT = "1"
    DOTNET_NOLOGO               = "1"
  }
}

# ============================================================================
# TOOLCHAIN COMPONENTS
# Information about installed languages and tools
# ============================================================================

output "languages" {
  description = "Programming languages included in this toolchain"
  value = {
    csharp = {
      version         = "12"
      package_manager = "nuget"
    }
    dotnet = {
      version         = "8"
      package_manager = "nuget"
    }
    powershell = {
      version         = "7"
      package_manager = "PSGallery"
    }
  }
}

output "tools" {
  description = "Tools included in this toolchain"
  value = concat(
    [
      "visual-studio-2022",
      "git",
      "azure-cli",
      "powershell-core",
      "nuget",
      "dotnet-cli"
    ],
    var.install_ssms ? ["sql-server-management-studio"] : [],
    var.install_azure_data_studio ? ["azure-data-studio"] : [],
    var.install_postman ? ["postman"] : [],
    var.install_docker_desktop ? ["docker-desktop"] : []
  )
}

# ============================================================================
# IMAGE REFERENCE
# AMI or artifact reference for this toolchain
# ============================================================================

output "image_id" {
  description = "AMI reference for this toolchain (placeholder - resolved by infrastructure base)"
  value       = "ami-windows-server-2022-vs2022"
}

output "supported_os" {
  description = "Operating systems supported by this toolchain"
  value       = ["windows-server-2022"]
}

# ============================================================================
# VISUAL STUDIO CONFIGURATION
# ============================================================================

output "vs_config" {
  description = "Visual Studio configuration"
  value = {
    edition   = var.vs_edition
    workloads = var.vs_workloads
  }
}

# ============================================================================
# VALIDATION
# Health check commands for verifying toolchain installation
# ============================================================================

output "health_checks" {
  description = "Commands to verify toolchain is correctly installed"
  value = [
    {
      name             = "dotnet_version"
      command          = "dotnet --version"
      expected_pattern = "8\\."
    },
    {
      name             = "powershell_version"
      command          = "pwsh --version"
      expected_pattern = "PowerShell 7\\."
    },
    {
      name             = "git_available"
      command          = "git --version"
      expected_pattern = "git version"
    },
    {
      name             = "azure_cli_available"
      command          = "az --version"
      expected_pattern = "azure-cli"
    }
  ]
}
