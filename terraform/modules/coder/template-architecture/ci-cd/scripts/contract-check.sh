#!/bin/bash
# Contract Validation Script
# Requirements: 11c.10, 11d.1 - Validate contract satisfaction
#
# Usage: ./contract-check.sh <directory>

set -e

DIR="${1:-.}"
ERRORS=0

echo "=== Contract Validation ==="
echo "Directory: ${DIR}"
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
# Check if this is a toolchain or infrastructure base
# ==========================================================================
if [ -f "${DIR}/toolchain.yaml" ]; then
    TYPE="toolchain"
elif ls "${DIR}"/*/main.tf > /dev/null 2>&1; then
    TYPE="infra-base"
else
    echo "Unable to determine template type"
    exit 1
fi

echo "Template type: ${TYPE}"
echo ""

# ==========================================================================
# Toolchain Contract Validation
# ==========================================================================
if [ "$TYPE" == "toolchain" ]; then
    echo "--- Validating Toolchain Contract ---"
    
    # Check capabilities declaration
    if python3 -c "
import yaml
import sys

with open('${DIR}/toolchain.yaml') as f:
    data = yaml.safe_load(f)

capabilities = data.get('capabilities', {})
required = capabilities.get('required', [])
optional = capabilities.get('optional', [])

valid_capabilities = [
    'persistent-home', 'network-egress', 'identity-mode',
    'gpu-support', 'artifact-cache', 'secrets-injection',
    'gui-vnc', 'gui-rdp'
]

invalid = [c for c in required + optional if c not in valid_capabilities]
if invalid:
    print(f'Invalid capabilities: {invalid}')
    sys.exit(1)

print(f'Required capabilities: {required}')
print(f'Optional capabilities: {optional}')
sys.exit(0)
" 2>&1; then
        log_success "Capabilities declaration is valid"
    else
        log_error "Invalid capabilities declaration"
    fi
    
    # Check compute profiles
    if python3 -c "
import yaml
import sys

with open('${DIR}/toolchain.yaml') as f:
    data = yaml.safe_load(f)

capabilities = data.get('capabilities', {})
compute = capabilities.get('compute', {})
profiles = compute.get('profiles', [])

valid_profiles = [
    'sw-dev-small', 'sw-dev-medium', 'sw-dev-large',
    'platform-devsecops',
    'datasci-standard', 'datasci-large', 'datasci-xlarge'
]

invalid = [p for p in profiles if p not in valid_profiles]
if invalid:
    print(f'Invalid compute profiles: {invalid}')
    sys.exit(1)

print(f'Compute profiles: {profiles}')
sys.exit(0)
" 2>&1; then
        log_success "Compute profiles are valid"
    else
        log_error "Invalid compute profiles"
    fi
    
    # Check version format
    if python3 -c "
import yaml
import re
import sys

with open('${DIR}/toolchain.yaml') as f:
    data = yaml.safe_load(f)

version = data.get('version', '')
if not re.match(r'^v?\d+\.\d+\.\d+', version):
    print(f'Invalid version format: {version}')
    sys.exit(1)

print(f'Version: {version}')
sys.exit(0)
" 2>&1; then
        log_success "Version format is valid (semantic versioning)"
    else
        log_error "Invalid version format"
    fi
fi

# ==========================================================================
# Infrastructure Base Contract Validation
# ==========================================================================
if [ "$TYPE" == "infra-base" ]; then
    echo "--- Validating Infrastructure Base Contract ---"
    
    for base_dir in "${DIR}"/*/; do
        if [ ! -d "$base_dir" ]; then
            continue
        fi
        
        base_name=$(basename "$base_dir")
        echo ""
        echo "Checking ${base_name}..."
        
        # Check contract inputs
        if [ -f "${base_dir}/variables.tf" ]; then
            # Check compute_profile structure
            if grep -q "compute_profile" "${base_dir}/variables.tf"; then
                if grep -A 10 "variable \"compute_profile\"" "${base_dir}/variables.tf" | grep -q "cpu"; then
                    log_success "${base_name}: compute_profile has cpu field"
                else
                    log_error "${base_name}: compute_profile missing cpu field"
                fi
                
                if grep -A 10 "variable \"compute_profile\"" "${base_dir}/variables.tf" | grep -q "memory"; then
                    log_success "${base_name}: compute_profile has memory field"
                else
                    log_error "${base_name}: compute_profile missing memory field"
                fi
            fi
            
            # Check capabilities structure
            if grep -q "capabilities" "${base_dir}/variables.tf"; then
                log_success "${base_name}: capabilities variable defined"
            else
                log_error "${base_name}: capabilities variable not defined"
            fi
        fi
        
        # Check contract outputs
        if [ -f "${base_dir}/outputs.tf" ]; then
            # Check metadata output has required fields
            if grep -q "metadata" "${base_dir}/outputs.tf"; then
                if grep -A 20 "output \"metadata\"" "${base_dir}/outputs.tf" | grep -q "platform"; then
                    log_success "${base_name}: metadata has platform field"
                else
                    log_error "${base_name}: metadata missing platform field"
                fi
                
                if grep -A 20 "output \"metadata\"" "${base_dir}/outputs.tf" | grep -q "os"; then
                    log_success "${base_name}: metadata has os field"
                else
                    log_error "${base_name}: metadata missing os field"
                fi
            fi
        fi
    done
fi

# ==========================================================================
# Summary
# ==========================================================================
echo ""
echo "=== Contract Validation Summary ==="
if [ $ERRORS -eq 0 ]; then
    echo "✓ All contract validations passed"
    exit 0
else
    echo "✗ ${ERRORS} error(s) found"
    exit 1
fi
