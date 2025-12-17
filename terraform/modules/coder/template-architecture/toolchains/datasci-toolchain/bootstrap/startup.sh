#!/bin/bash
# Data Science Toolchain - Bootstrap Script
# This script initializes the workspace environment on startup.
#
# Requirements Covered:
# - 11c.3: Toolchain manifest with bootstrap scripts
# - 11.9: GPU instance types and pre-installed ML tooling

set -e

echo "=== Data Science Workspace Bootstrap ==="
echo "Toolchain: datasci-toolchain v1.0.0"
echo "Started at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# ============================================================================
# DIRECTORY SETUP
# ============================================================================

echo ""
echo "Setting up directories..."

# Create standard data science directories
mkdir -p ~/projects
mkdir -p ~/data
mkdir -p ~/models
mkdir -p ~/notebooks
mkdir -p ~/.jupyter
mkdir -p ~/.config
mkdir -p ~/.local/bin

echo "  Created: ~/projects, ~/data, ~/models, ~/notebooks"

# ============================================================================
# JUPYTER CONFIGURATION
# ============================================================================

echo ""
echo "Configuring Jupyter..."

# Generate Jupyter config if not exists
if [ ! -f ~/.jupyter/jupyter_lab_config.py ]; then
  jupyter lab --generate-config 2>/dev/null || true
  echo "  Generated Jupyter Lab configuration"
fi

# Set Jupyter to use ~/notebooks as default directory
if [ -f ~/.jupyter/jupyter_lab_config.py ]; then
  if ! grep -q "c.ServerApp.root_dir" ~/.jupyter/jupyter_lab_config.py; then
    echo "c.ServerApp.root_dir = '$HOME/notebooks'" >> ~/.jupyter/jupyter_lab_config.py
    echo "  Set default notebook directory to ~/notebooks"
  fi
fi

# ============================================================================
# GIT CONFIGURATION
# ============================================================================

echo ""
echo "Checking Git configuration..."

# Git will be configured via Coder external auth
if [ -z "$(git config --global user.email 2>/dev/null)" ]; then
  echo "  Git user.email not configured - will be set via Coder external auth"
fi

# Set useful Git defaults
git config --global init.defaultBranch main 2>/dev/null || true
git config --global core.editor "code --wait" 2>/dev/null || true

# ============================================================================
# HARDWARE DETECTION
# ============================================================================

echo ""
echo "--- Hardware Status ---"

# CPU info
echo "CPU: $(nproc) cores"
echo "Memory: $(free -h | awk '/^Mem:/ {print $2}')"

# GPU detection
if command -v nvidia-smi &> /dev/null; then
  echo ""
  echo "GPU detected:"
  nvidia-smi --query-gpu=index,name,memory.total,driver_version --format=csv,noheader 2>/dev/null | while read line; do
    echo "  $line"
  done
  
  # CUDA version
  if command -v nvcc &> /dev/null; then
    echo "CUDA: $(nvcc --version | grep release | awk '{print $6}' | cut -d',' -f1)"
  fi
else
  echo "No GPU detected (CPU-only mode)"
fi

# ============================================================================
# PYTHON ENVIRONMENT VERIFICATION
# ============================================================================

echo ""
echo "--- Python Environment ---"

echo "Python: $(python3 --version 2>&1)"
echo "pip: $(pip3 --version 2>&1 | awk '{print $2}')"

# Check virtual environment
if [ -n "$VIRTUAL_ENV" ]; then
  echo "Virtual env: $VIRTUAL_ENV"
fi

# ============================================================================
# ML FRAMEWORK VERIFICATION
# ============================================================================

echo ""
echo "--- ML Frameworks ---"

# PyTorch
pytorch_version=$(python3 -c "import torch; print(torch.__version__)" 2>/dev/null) && \
  echo "PyTorch: $pytorch_version" || echo "PyTorch: not installed"

# TensorFlow
tf_version=$(python3 -c "import tensorflow as tf; print(tf.__version__)" 2>/dev/null) && \
  echo "TensorFlow: $tf_version" || echo "TensorFlow: not installed"

# scikit-learn
sklearn_version=$(python3 -c "import sklearn; print(sklearn.__version__)" 2>/dev/null) && \
  echo "scikit-learn: $sklearn_version" || echo "scikit-learn: not installed"

# pandas
pandas_version=$(python3 -c "import pandas; print(pandas.__version__)" 2>/dev/null) && \
  echo "pandas: $pandas_version" || echo "pandas: not installed"

# ============================================================================
# GPU FRAMEWORK SUPPORT
# ============================================================================

if command -v nvidia-smi &> /dev/null; then
  echo ""
  echo "--- GPU Support in Frameworks ---"
  
  # PyTorch CUDA
  pytorch_cuda=$(python3 -c "import torch; print(f'available={torch.cuda.is_available()}, devices={torch.cuda.device_count()}')" 2>/dev/null) && \
    echo "PyTorch CUDA: $pytorch_cuda" || true
  
  # TensorFlow GPU
  tf_gpu=$(python3 -c "import tensorflow as tf; gpus=tf.config.list_physical_devices('GPU'); print(f'available={len(gpus)>0}, devices={len(gpus)}')" 2>/dev/null) && \
    echo "TensorFlow GPU: $tf_gpu" || true
fi

# ============================================================================
# ADDITIONAL TOOLS
# ============================================================================

echo ""
echo "--- Additional Tools ---"

# Jupyter
jupyter_version=$(jupyter --version 2>/dev/null | head -1) && \
  echo "Jupyter: $jupyter_version" || echo "Jupyter: not installed"

# MLflow
mlflow_version=$(mlflow --version 2>/dev/null) && \
  echo "MLflow: $mlflow_version" || echo "MLflow: not installed"

# DVC
dvc_version=$(dvc --version 2>/dev/null) && \
  echo "DVC: $dvc_version" || echo "DVC: not installed"

# ============================================================================
# COMPLETION
# ============================================================================

echo ""
echo "=== Workspace Ready ==="
echo "Completed at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""
echo "Quick start:"
echo "  cd ~/notebooks"
echo "  jupyter lab --ip=0.0.0.0 --port=8888"
echo ""
echo "Or start a new project:"
echo "  cd ~/projects"
echo "  git clone <repository>"
echo ""
