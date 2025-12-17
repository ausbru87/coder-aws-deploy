# Data Science Toolchain - Terraform Outputs
# These outputs are consumed by infrastructure base modules during composition.
#
# Requirements Covered:
# - 11c.2: Toolchain template declares capabilities without infrastructure details
# - 11d.2: Specify toolchain template inputs (capabilities, compute profile)
# - 11.9: GPU instance types and pre-installed ML tooling

# ============================================================================
# TOOLCHAIN METADATA
# ============================================================================

output "name" {
  description = "Toolchain template name"
  value       = "datasci-toolchain"
}

output "version" {
  description = "Toolchain template version"
  value       = "1.0.0"
}

output "description" {
  description = "Toolchain description"
  value       = "Data science and ML workspace with Python, Jupyter, PyTorch, and TensorFlow"
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
    gpu_support       = var.enable_gpu
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
    datasci-standard = {
      cpu       = 8
      memory    = "32Gi"
      storage   = "500Gi"
      gpu_count = 0
      gpu_type  = null
    }
    datasci-large = {
      cpu       = 16
      memory    = "64Gi"
      storage   = "1Ti"
      gpu_count = var.enable_gpu ? 1 : 0
      gpu_type  = var.enable_gpu ? var.gpu_type : null
    }
    datasci-xlarge = {
      cpu       = 32
      memory    = "64Gi"
      storage   = "2Ti"
      gpu_count = var.enable_gpu ? 4 : 0
      gpu_type  = var.enable_gpu ? var.gpu_type : null
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
    
    echo "=== Data Science Workspace Bootstrap ==="
    echo "Toolchain: datasci-toolchain v1.0.0"
    echo "Started at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    
    # Create standard directories
    echo "Setting up directories..."
    mkdir -p ~/projects ~/data ~/models ~/notebooks ~/.jupyter ~/.config
    
    # Configure Jupyter
    echo "Configuring Jupyter..."
    if [ ! -f ~/.jupyter/jupyter_lab_config.py ]; then
      jupyter lab --generate-config 2>/dev/null || true
    fi
    
    # Configure Git if not already configured
    if [ -z "$(git config --global user.email)" ]; then
      echo "Git user.email not configured - will be set via Coder external auth"
    fi
    
    # Verify GPU availability
    echo ""
    echo "--- Hardware Status ---"
    if command -v nvidia-smi &> /dev/null; then
      echo "GPU detected:"
      nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>/dev/null || echo "  GPU query failed"
    else
      echo "No GPU detected (CPU-only mode)"
    fi
    
    # Verify Python environment
    echo ""
    echo "--- Python Environment ---"
    echo "Python: $(python3 --version 2>&1)"
    
    # Check ML frameworks
    echo ""
    echo "--- ML Frameworks ---"
    python3 -c "import torch; print(f'PyTorch: {torch.__version__}')" 2>/dev/null || echo "PyTorch: not installed"
    python3 -c "import tensorflow as tf; print(f'TensorFlow: {tf.__version__}')" 2>/dev/null || echo "TensorFlow: not installed"
    python3 -c "import sklearn; print(f'scikit-learn: {sklearn.__version__}')" 2>/dev/null || echo "scikit-learn: not installed"
    python3 -c "import pandas; print(f'pandas: {pandas.__version__}')" 2>/dev/null || echo "pandas: not installed"
    
    # Check GPU support in frameworks
    if command -v nvidia-smi &> /dev/null; then
      echo ""
      echo "--- GPU Support ---"
      python3 -c "import torch; print(f'PyTorch CUDA: {torch.cuda.is_available()}')" 2>/dev/null || true
      python3 -c "import tensorflow as tf; print(f'TensorFlow GPU: {len(tf.config.list_physical_devices(\"GPU\")) > 0}')" 2>/dev/null || true
    fi
    
    ${var.custom_startup_script}
    
    echo ""
    echo "=== Workspace Ready ==="
    echo "Completed at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
    echo "Quick start:"
    echo "  cd ~/notebooks"
    echo "  jupyter lab"
    echo ""
  EOT
}

output "environment_variables" {
  description = "Environment variables to set in the workspace"
  value = {
    JUPYTER_ENABLE_LAB   = "yes"
    PYTHONUNBUFFERED     = "1"
    TF_CPP_MIN_LOG_LEVEL = "2"
    LANG                 = "en_US.UTF-8"
    LC_ALL               = "en_US.UTF-8"
  }
}

# ============================================================================
# TOOLCHAIN COMPONENTS
# Information about installed languages and tools
# ============================================================================

output "languages" {
  description = "Programming languages included in this toolchain"
  value = merge(
    {
      python = {
        version         = "3.12"
        package_manager = "pip"
      }
    },
    var.install_r ? {
      r = {
        version         = "4.x"
        package_manager = "CRAN"
      }
    } : {}
  )
}

output "tools" {
  description = "Tools included in this toolchain"
  value = concat(
    [
      "jupyter-lab",
      "git"
    ],
    var.enable_gpu ? ["cuda-toolkit"] : [],
    var.install_tensorboard ? ["tensorboard"] : [],
    var.install_mlflow ? ["mlflow"] : [],
    var.install_dvc ? ["dvc"] : [],
    var.install_wandb ? ["wandb"] : [],
    var.install_ray ? ["ray"] : []
  )
}

output "libraries" {
  description = "ML libraries included in this toolchain"
  value = {
    python = concat(
      [
        "pandas",
        "numpy",
        "scipy",
        "scikit-learn",
        "matplotlib",
        "seaborn",
        "plotly",
        "xgboost",
        "lightgbm"
      ],
      var.install_pytorch ? ["pytorch", "transformers"] : [],
      var.install_tensorflow ? ["tensorflow"] : [],
      var.additional_pip_packages
    )
    r = var.install_r ? [
      "tidyverse",
      "ggplot2",
      "caret",
      "shiny"
    ] : []
  }
}

# ============================================================================
# IMAGE REFERENCE
# Container image or artifact reference for this toolchain
# ============================================================================

output "image_id" {
  description = "Container image reference for this toolchain"
  value       = var.enable_gpu ? "ghcr.io/org/toolchains/datasci-gpu:1.0.0" : "ghcr.io/org/toolchains/datasci:1.0.0"
}

output "supported_os" {
  description = "Operating systems supported by this toolchain"
  value       = ["amazon-linux-2023", "ubuntu-22.04", "ubuntu-24.04"]
}

# ============================================================================
# GPU CONFIGURATION
# ============================================================================

output "gpu_config" {
  description = "GPU configuration for this toolchain"
  value = {
    enabled      = var.enable_gpu
    type         = var.enable_gpu ? var.gpu_type : null
    count        = local.compute_profiles[var.compute_profile].gpu_count
    cuda_version = var.enable_gpu ? "12.x" : null
  }
}

# ============================================================================
# VALIDATION
# Health check commands for verifying toolchain installation
# ============================================================================

output "health_checks" {
  description = "Commands to verify toolchain is correctly installed"
  value = concat(
    [
      {
        name             = "python_version"
        command          = "python3 --version"
        expected_pattern = "Python 3\\.12"
      },
      {
        name             = "jupyter_available"
        command          = "jupyter --version"
        expected_pattern = "jupyter"
      },
      {
        name             = "pandas_import"
        command          = "python3 -c 'import pandas; print(pandas.__version__)'"
        expected_pattern = "2\\."
      },
      {
        name             = "sklearn_import"
        command          = "python3 -c 'import sklearn; print(sklearn.__version__)'"
        expected_pattern = "1\\."
      }
    ],
    var.install_pytorch ? [
      {
        name             = "pytorch_import"
        command          = "python3 -c 'import torch; print(torch.__version__)'"
        expected_pattern = "2\\."
      }
    ] : [],
    var.install_tensorflow ? [
      {
        name             = "tensorflow_import"
        command          = "python3 -c 'import tensorflow as tf; print(tf.__version__)'"
        expected_pattern = "2\\."
      }
    ] : [],
    var.enable_gpu ? [
      {
        name             = "nvidia_smi"
        command          = "nvidia-smi"
        expected_pattern = "NVIDIA-SMI"
      },
      {
        name             = "cuda_available"
        command          = "python3 -c 'import torch; print(torch.cuda.is_available())'"
        expected_pattern = "True"
      }
    ] : []
  )
}
