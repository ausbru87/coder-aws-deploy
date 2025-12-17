#!/bin/bash
# Toolchain Template Validation Script
# Requirements: 11f.3 - Validate templates locally before publishing
#
# Usage: ./validate-toolchain.sh <toolchain-directory>

set -e

TOOLCHAIN_DIR="${1:-.}"
ERRORS=0

echo "=== Toolchain Template Validation ==="
echo "Directory: ${TOOLCHAIN_DIR}"
echo ""

# Function to log errors
log_error() {
    echo "ERROR: $1"
    ERRORS=$((ERRORS + 1))
}

# Function to log success
log_success() {
    echo "✓ $1"
}

# ==========================================================================
# Check required files exist
# ==========================================================================
echo "--- Checking required files ---"

if [ -f "${TOOLCHAIN_DIR}/toolchain.yaml" ]; then
    log_success "toolchain.yaml exists"
else
    log_error "toolchain.yaml not found"
fi

if [ -f "${TOOLCHAIN_DIR}/variables.tf" ]; then
    log_success "variables.tf exists"
else
    log_error "variables.tf not found"
fi

if [ -f "${TOOLCHAIN_DIR}/outputs.tf" ]; then
    log_success "outputs.tf exists"
else
    log_error "outputs.tf not found"
fi

# ==========================================================================
# Validate toolchain.yaml structure
# ==========================================================================
echo ""
echo "--- Validating toolchain.yaml structure ---"

if [ -f "${TOOLCHAIN_DIR}/toolchain.yaml" ]; then
    # Check for required fields
    if python3 -c "
import yaml
import sys

with open('${TOOLCHAIN_DIR}/toolchain.yaml') as f:
    data = yaml.safe_load(f)

required_fields = ['name', 'version', 'toolchain', 'capabilities']
missing = [f for f in required_fields if f not in data]

if missing:
    print(f'Missing required fields: {missing}')
    sys.exit(1)

# Validate version format (semantic versioning)
import re
version = data.get('version', '')
if not re.match(r'^v?\d+\.\d+\.\d+', version):
    print(f'Invalid version format: {version}')
    sys.exit(1)

print('toolchain.yaml structure is valid')
sys.exit(0)
" 2>&1; then
        log_success "toolchain.yaml structure is valid"
    else
        log_error "toolchain.yaml structure validation failed"
    fi
fi

# ==========================================================================
# Validate Terraform syntax
# ==========================================================================
echo ""
echo "--- Validating Terraform syntax ---"

if command -v terraform &> /dev/null; then
    if terraform -chdir="${TOOLCHAIN_DIR}" init -backend=false > /dev/null 2>&1; then
        log_success "Terraform init successful"
        
        if terraform -chdir="${TOOLCHAIN_DIR}" validate > /dev/null 2>&1; then
            log_success "Terraform validate successful"
        else
            log_error "Terraform validate failed"
        fi
    else
        log_error "Terraform init failed"
    fi
else
    echo "WARN: Terraform not installed, skipping Terraform validation"
fi

# ==========================================================================
# Check for required outputs
# ==========================================================================
echo ""
echo "--- Checking required outputs ---"

REQUIRED_OUTPUTS=(
    "name"
    "version"
    "capabilities"
    "compute_profile"
    "bootstrap_script"
    "image_id"
)

if [ -f "${TOOLCHAIN_DIR}/outputs.tf" ]; then
    for output in "${REQUIRED_OUTPUTS[@]}"; do
        if grep -q "output \"${output}\"" "${TOOLCHAIN_DIR}/outputs.tf"; then
            log_success "Output '${output}' defined"
        else
            log_error "Required output '${output}' not found"
        fi
    done
fi

# ==========================================================================
# Check for infrastructure-specific code (should not exist)
# Requirement 11g.1: Toolchain templates should not contain infrastructure primitives
# ==========================================================================
echo ""
echo "--- Checking for infrastructure-specific code ---"

FORBIDDEN_PATTERNS=(
    "aws_instance"
    "aws_security_group"
    "aws_subnet"
    "kubernetes_deployment"
    "kubernetes_pod"
    "node_selector"
    "ami-"
)

for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
    if grep -r "${pattern}" "${TOOLCHAIN_DIR}"/*.tf 2>/dev/null; then
        log_error "Found infrastructure-specific pattern: ${pattern}"
    fi
done

if [ $ERRORS -eq 0 ]; then
    log_success "No infrastructure-specific code found"
fi

# ==========================================================================
# Summary
# ==========================================================================
echo ""
echo "=== Validation Summary ==="
if [ $ERRORS -eq 0 ]; then
    echo "✓ All validations passed"
    exit 0
else
    echo "✗ ${ERRORS} error(s) found"
    exit 1
fi
