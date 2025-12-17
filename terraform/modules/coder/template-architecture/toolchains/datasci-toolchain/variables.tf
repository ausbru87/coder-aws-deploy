# Data Science Toolchain - Terraform Variables
# This file defines the variables that this toolchain template exposes.
#
# Requirements Covered:
# - 11c.2: Toolchain template declares capabilities without infrastructure details
# - 11c.4: Define capabilities (compute profile, network egress, persistent home)
# - 11.9: GPU instance types and pre-installed ML tooling

terraform {
  required_version = ">= 1.0"
}

# ============================================================================
# COMPUTE PROFILE SELECTION
# ============================================================================

variable "compute_profile" {
  type        = string
  description = "T-shirt size for the workspace compute resources"
  default     = "datasci-standard"

  validation {
    condition = contains([
      "datasci-standard",
      "datasci-large",
      "datasci-xlarge"
    ], var.compute_profile)
    error_message = "Compute profile must be one of: datasci-standard, datasci-large, datasci-xlarge."
  }
}

# ============================================================================
# GPU CONFIGURATION
# ============================================================================

variable "enable_gpu" {
  type        = bool
  description = "Enable GPU support (requires datasci-large or datasci-xlarge profile)"
  default     = false
}

variable "gpu_type" {
  type        = string
  description = "GPU type when enable_gpu is true"
  default     = "nvidia-t4"

  validation {
    condition = contains([
      "nvidia-t4",
      "nvidia-a10g",
      "nvidia-v100",
      "nvidia-a100"
    ], var.gpu_type)
    error_message = "GPU type must be one of: nvidia-t4, nvidia-a10g, nvidia-v100, nvidia-a100."
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

# ============================================================================
# FRAMEWORK SELECTION
# ============================================================================

variable "install_pytorch" {
  type        = bool
  description = "Install PyTorch deep learning framework"
  default     = true
}

variable "install_tensorflow" {
  type        = bool
  description = "Install TensorFlow deep learning framework"
  default     = true
}

variable "install_r" {
  type        = bool
  description = "Install R and common R packages"
  default     = false
}

# ============================================================================
# OPTIONAL TOOLS
# ============================================================================

variable "install_tensorboard" {
  type        = bool
  description = "Install TensorBoard visualization"
  default     = true
}

variable "install_mlflow" {
  type        = bool
  description = "Install MLflow experiment tracking"
  default     = true
}

variable "install_dvc" {
  type        = bool
  description = "Install DVC for data version control"
  default     = true
}

variable "install_wandb" {
  type        = bool
  description = "Install Weights & Biases"
  default     = false
}

variable "install_ray" {
  type        = bool
  description = "Install Ray distributed computing"
  default     = false
}

# ============================================================================
# CUSTOMIZATION
# ============================================================================

variable "additional_pip_packages" {
  type        = list(string)
  description = "Additional pip packages to install"
  default     = []
}

variable "additional_conda_packages" {
  type        = list(string)
  description = "Additional conda packages to install"
  default     = []
}

variable "custom_startup_script" {
  type        = string
  description = "Custom script to run after standard bootstrap"
  default     = ""
}
