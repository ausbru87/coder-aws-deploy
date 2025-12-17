# Software Development Toolchain - Terraform Variables
# This file defines the variables that this toolchain template exposes.
#
# Requirements Covered:
# - 11c.2: Toolchain template declares capabilities without infrastructure details
# - 11c.4: Define capabilities (compute profile, network egress, persistent home)
# - 11f.2: Declare required capabilities and toolchain dependencies

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
      "sw-dev-small",
      "sw-dev-medium",
      "sw-dev-large",
      "platform-devsecops"
    ], var.compute_profile)
    error_message = "Compute profile must be one of: sw-dev-small, sw-dev-medium, sw-dev-large, platform-devsecops."
  }
}

# ============================================================================
# OPTIONAL CAPABILITY TOGGLES
# ============================================================================

variable "enable_gui" {
  type        = bool
  description = "Enable VNC-based GUI desktop environment"
  default     = false
}

variable "enable_docker" {
  type        = bool
  description = "Enable Docker-in-Docker or Docker socket access"
  default     = true
}

# ============================================================================
# OPTIONAL TOOLS
# ============================================================================

variable "install_aws_cli" {
  type        = bool
  description = "Install AWS CLI v2"
  default     = true
}

variable "install_helm" {
  type        = bool
  description = "Install Helm Kubernetes package manager"
  default     = true
}

variable "install_k9s" {
  type        = bool
  description = "Install k9s Kubernetes TUI"
  default     = false
}

# ============================================================================
# CUSTOMIZATION
# ============================================================================

variable "additional_packages" {
  type        = list(string)
  description = "Additional system packages to install"
  default     = []
}

variable "custom_startup_script" {
  type        = string
  description = "Custom script to run after standard bootstrap"
  default     = ""
}
