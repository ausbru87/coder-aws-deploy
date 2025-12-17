#!/bin/bash
# Infrastructure Base Module Validation Script
# Requirements: 11b.3 - Validate infrastructure bases via CI/CD
#
# Usage: ./validate-infra-base.sh <bases-directory>

set -e

BASES_DIR="${1:-.}"
ERRORS=0

echo "=== Infrastructure Base Module Validation ==="
echo "Directory: ${BASES_DIR}"
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
# Validate each base module
# ==========================================================================
for base_dir in "${BASES_DIR}"/*/; do
    if [ ! -d "$base_dir" ]; then
        continue
    fi
    
    base_name=$(basename "$base_dir")
    echo ""
    echo "--- Validating ${base_name} ---"
    
    # Check required files
    if [ -f "${base_dir}/main.tf" ]; then
        log_success "main.tf exists"
    else
        log_error "${base_name}: main.tf not found"
    fi
    
    if [ -f "${base_dir}/variables.tf" ]; then
        log_success "variables.tf exists"
    else
        log_error "${base_name}: variables.tf not found"
    fi
    
    if [ -f "${base_dir}/outputs.tf" ]; then
        log_success "outputs.tf exists"
    else
        log_error "${base_name}: outputs.tf not found"
    fi
    
    # Check for required contract inputs
    echo "  Checking contract inputs..."
    REQUIRED_INPUTS=(
        "workspace_name"
        "owner"
        "compute_profile"
        "image_id"
        "capabilities"
        "toolchain_template"
        "base_module"
    )
    
    if [ -f "${base_dir}/variables.tf" ]; then
        for input in "${REQUIRED_INPUTS[@]}"; do
            if grep -q "variable \"${input}\"" "${base_dir}/variables.tf"; then
                log_success "  Input '${input}' defined"
            else
                log_error "${base_name}: Required input '${input}' not found"
            fi
        done
    fi
    
    # Check for required contract outputs
    echo "  Checking contract outputs..."
    REQUIRED_OUTPUTS=(
        "agent_endpoint"
        "runtime_env"
        "volume_mounts"
        "metadata"
    )
    
    if [ -f "${base_dir}/outputs.tf" ]; then
        for output in "${REQUIRED_OUTPUTS[@]}"; do
            if grep -q "output \"${output}\"" "${base_dir}/outputs.tf"; then
                log_success "  Output '${output}' defined"
            else
                log_error "${base_name}: Required output '${output}' not found"
            fi
        done
    fi
    
    # Validate Terraform syntax
    echo "  Validating Terraform..."
    if command -v terraform &> /dev/null; then
        if terraform -chdir="${base_dir}" init -backend=false > /dev/null 2>&1; then
            log_success "  Terraform init successful"
            
            if terraform -chdir="${base_dir}" validate > /dev/null 2>&1; then
                log_success "  Terraform validate successful"
            else
                log_error "${base_name}: Terraform validate failed"
            fi
        else
            log_error "${base_name}: Terraform init failed"
        fi
    fi
    
    # Check for metadata output with provenance fields
    echo "  Checking provenance fields in metadata..."
    if [ -f "${base_dir}/outputs.tf" ]; then
        PROVENANCE_FIELDS=(
            "toolchain_version"
            "base_version"
            "provisioned_at"
        )
        
        for field in "${PROVENANCE_FIELDS[@]}"; do
            if grep -q "${field}" "${base_dir}/outputs.tf"; then
                log_success "  Provenance field '${field}' found"
            else
                log_error "${base_name}: Provenance field '${field}' not found in metadata"
            fi
        done
    fi
done

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
