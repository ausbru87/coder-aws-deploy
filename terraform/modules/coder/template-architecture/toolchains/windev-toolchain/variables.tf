# Windows Development Toolchain - Terraform Variables
# This file defines the variables that this toolchain template exposes.
#
# Requirements Covered:
# - 11c.2: Toolchain template declares capabilities without infrastructure details
# - 11c.4: Define capabilities (compute profile, network egress, persistent home)

terraform {
  required_version = ">= 1.0"
}

# ============================================================================
# COMPUTE PROFILE SELECTION
# ============================================================================

variable "compute_profile" {
  type        = string
  description = "T-shirt size for the workspace compute resources"
  default     = "sw-dev-medium"

  validation {
    condition = contains([
      "sw-dev-medium",
      "sw-dev-large"
    ], var.compute_profile)
    error_message = "Compute profile must be one of: sw-dev-medium, sw-dev-large."
  }
}

# ============================================================================
# VISUAL STUDIO CONFIGURATION
# ============================================================================

variable "vs_edition" {
  type        = string
  description = "Visual Studio 2022 edition"
  default     = "Professional"

  validation {
    condition     = contains(["Professional", "Enterprise"], var.vs_edition)
    error_message = "VS edition must be Professional or Enterprise."
  }
}

variable "vs_workloads" {
  type        = list(string)
  description = "Visual Studio workloads to install"
  default = [
    "Microsoft.VisualStudio.Workload.NetWeb",
    "Microsoft.VisualStudio.Workload.Azure",
    "Microsoft.VisualStudio.Workload.ManagedDesktop"
  ]
}

# ============================================================================
# OPTIONAL TOOLS
# ============================================================================

variable "install_ssms" {
  type        = bool
  description = "Install SQL Server Management Studio"
  default     = false
}

variable "install_azure_data_studio" {
  type        = bool
  description = "Install Azure Data Studio"
  default     = false
}

variable "install_postman" {
  type        = bool
  description = "Install Postman API client"
  default     = false
}

variable "install_docker_desktop" {
  type        = bool
  description = "Install Docker Desktop for Windows"
  default     = false
}

# ============================================================================
# CUSTOMIZATION
# ============================================================================

variable "additional_packages" {
  type        = list(string)
  description = "Additional Chocolatey packages to install"
  default     = []
}

variable "custom_startup_script" {
  type        = string
  description = "Custom PowerShell script to run after standard bootstrap"
  default     = ""
}
