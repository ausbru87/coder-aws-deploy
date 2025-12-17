#!/bin/bash
# Data Science Toolchain - Validation Tests
# This script validates that the toolchain is correctly configured.
#
# Requirements Covered:
# - 11f.3: Validate templates locally using lint and contract checks
# - 11.9: GPU instance types and pre-installed ML tooling

set -e

echo "=== Toolchain Validation Tests ==="
echo "Toolchain: datasci-toolchain v1.0.0"
echo ""

PASS=0
FAIL=0
SKIP=0

# Test function
run_test() {
  local name=$1
  local command=$2
  local expected_pattern=$3
  
  echo -n "Testing $name... "
  
  if output=$(eval "$command" 2>&1); then
    if echo "$output" | grep -qE "$expected_pattern"; then
      echo "PASS"
      ((PASS++))
    else
      echo "FAIL (pattern not matched)"
      echo "  Expected pattern: $expected_pattern"
      echo "  Got: $output"
      ((FAIL++))
    fi
  else
    echo "FAIL (command failed)"
    echo "  Command: $command"
    echo "  Output: $output"
    ((FAIL++))
  fi
}

# Skip test function
skip_test() {
  local name=$1
  local reason=$2
  
  echo "Testing $name... SKIPPED ($reason)"
  ((SKIP++))
}

# ============================================================================
# LANGUAGE TESTS
# ============================================================================

echo "--- Language Tests ---"

run_test "Python version" "python3 --version" "Python 3\\.12"

# R is optional
if command -v R &> /dev/null; then
  run_test "R version" "R --version | head -1" "R version 4\\."
else
  skip_test "R version" "R not installed"
fi

# ============================================================================
# CORE LIBRARY TESTS
# ============================================================================

echo ""
echo "--- Core Library Tests ---"

run_test "pandas" "python3 -c 'import pandas; print(pandas.__version__)'" "2\\."
run_test "numpy" "python3 -c 'import numpy; print(numpy.__version__)'" "1\\."
run_test "scipy" "python3 -c 'import scipy; print(scipy.__version__)'" "1\\."
run_test "scikit-learn" "python3 -c 'import sklearn; print(sklearn.__version__)'" "1\\."
run_test "matplotlib" "python3 -c 'import matplotlib; print(matplotlib.__version__)'" "3\\."

# ============================================================================
# ML FRAMEWORK TESTS
# ============================================================================

echo ""
echo "--- ML Framework Tests ---"

# PyTorch (may be optional)
if python3 -c "import torch" 2>/dev/null; then
  run_test "PyTorch" "python3 -c 'import torch; print(torch.__version__)'" "2\\."
else
  skip_test "PyTorch" "not installed"
fi

# TensorFlow (may be optional)
if python3 -c "import tensorflow" 2>/dev/null; then
  run_test "TensorFlow" "python3 -c 'import tensorflow as tf; print(tf.__version__)'" "2\\."
else
  skip_test "TensorFlow" "not installed"
fi

# ============================================================================
# TOOL TESTS
# ============================================================================

echo ""
echo "--- Tool Tests ---"

run_test "Jupyter" "jupyter --version | head -1" "jupyter"
run_test "Git" "git --version" "git version"

# Optional tools
if command -v mlflow &> /dev/null; then
  run_test "MLflow" "mlflow --version" "mlflow"
else
  skip_test "MLflow" "not installed"
fi

if command -v dvc &> /dev/null; then
  run_test "DVC" "dvc --version" "dvc"
else
  skip_test "DVC" "not installed"
fi

# ============================================================================
# GPU TESTS (if GPU available)
# ============================================================================

echo ""
echo "--- GPU Tests ---"

if command -v nvidia-smi &> /dev/null; then
  run_test "nvidia-smi" "nvidia-smi" "NVIDIA-SMI"
  
  # PyTorch CUDA
  if python3 -c "import torch" 2>/dev/null; then
    run_test "PyTorch CUDA" "python3 -c 'import torch; print(torch.cuda.is_available())'" "True"
  fi
  
  # TensorFlow GPU
  if python3 -c "import tensorflow" 2>/dev/null; then
    run_test "TensorFlow GPU" "python3 -c 'import tensorflow as tf; print(len(tf.config.list_physical_devices(\"GPU\")) > 0)'" "True"
  fi
else
  skip_test "nvidia-smi" "no GPU detected"
  skip_test "PyTorch CUDA" "no GPU detected"
  skip_test "TensorFlow GPU" "no GPU detected"
fi

# ============================================================================
# ENVIRONMENT TESTS
# ============================================================================

echo ""
echo "--- Environment Tests ---"

echo -n "Testing home directory writable... "
if touch ~/test_write_$$ && rm ~/test_write_$$; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL"
  ((FAIL++))
fi

echo -n "Testing notebooks directory exists... "
if [ -d ~/notebooks ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL"
  ((FAIL++))
fi

echo -n "Testing data directory exists... "
if [ -d ~/data ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL"
  ((FAIL++))
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "=== Validation Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Skipped: $SKIP"
echo ""

if [ $FAIL -gt 0 ]; then
  echo "VALIDATION FAILED"
  exit 1
else
  echo "VALIDATION PASSED"
  exit 0
fi
