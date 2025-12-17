#!/bin/bash
# Pre-flight Quota Validation Script
# Requirements: 2a.4, 2a.5
#
# This script performs pre-flight validation of AWS service quotas
# and blocks deployment if quotas are insufficient.
#
# Exit codes:
#   0 - All quotas sufficient
#   1 - Insufficient quotas (deployment blocked)
#   2 - Error during validation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
AWS_REGION="${AWS_REGION:-us-east-1}"
QUOTA_REQUIREMENTS_FILE="${QUOTA_REQUIREMENTS_FILE:-$(dirname "$0")/../generated/quota-requirements.json}"
AUTO_REQUEST_INCREASES="${AUTO_REQUEST_INCREASES:-false}"
STRICT_MODE="${STRICT_MODE:-true}"

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v aws &> /dev/null; then
        missing_deps+=("aws-cli")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if ! command -v bc &> /dev/null; then
        missing_deps+=("bc")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        echo "Please install the missing dependencies and try again."
        exit 2
    fi
}

# Verify AWS credentials
verify_aws_credentials() {
    log_info "Verifying AWS credentials..."
    
    if ! aws sts get-caller-identity --region "$AWS_REGION" &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        echo "Please configure AWS credentials with 'aws configure' or set AWS_* environment variables"
        exit 2
    fi
    
    local account_id
    account_id=$(aws sts get-caller-identity --query 'Account' --output text)
    log_success "AWS credentials valid (Account: $account_id)"
}

# Get current quota value
get_current_quota() {
    local service_code="$1"
    local quota_code="$2"
    
    # Try to get applied quota first
    local value
    value=$(aws service-quotas get-service-quota \
        --service-code "$service_code" \
        --quota-code "$quota_code" \
        --region "$AWS_REGION" \
        --query 'Quota.Value' \
        --output text 2>/dev/null)
    
    if [ -n "$value" ] && [ "$value" != "None" ] && [ "$value" != "null" ]; then
        echo "$value"
        return
    fi
    
    # Fall back to default quota
    value=$(aws service-quotas get-aws-default-service-quota \
        --service-code "$service_code" \
        --quota-code "$quota_code" \
        --region "$AWS_REGION" \
        --query 'Quota.Value' \
        --output text 2>/dev/null)
    
    if [ -n "$value" ] && [ "$value" != "None" ] && [ "$value" != "null" ]; then
        echo "$value"
    else
        echo "-1"
    fi
}

# Check single quota
check_quota() {
    local service_code="$1"
    local quota_code="$2"
    local quota_name="$3"
    local required="$4"
    
    local current
    current=$(get_current_quota "$service_code" "$quota_code")
    
    if [ "$current" = "-1" ]; then
        log_warning "$quota_name: Unable to retrieve quota (may require manual verification)"
        return 2
    fi
    
    # Compare values (handle floating point)
    if (( $(echo "$current >= $required" | bc -l) )); then
        log_success "$quota_name: $current >= $required (required)"
        return 0
    else
        log_error "$quota_name: $current < $required (required) - INSUFFICIENT"
        return 1
    fi
}

# Main pre-flight validation
run_preflight_validation() {
    echo ""
    echo "=============================================="
    echo "  Coder Deployment Pre-flight Quota Check"
    echo "=============================================="
    echo "Region: $AWS_REGION"
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
    
    # Track results
    local total_checks=0
    local passed_checks=0
    local failed_checks=0
    local warning_checks=0
    local failed_quotas=()
    
    # Define critical quotas (deployment will be blocked if insufficient)
    local critical_quotas=(
        "ec2|L-1216C47A|EC2 On-Demand Standard vCPUs|1000"
        "ec2|L-34B43A08|EC2 Spot Standard vCPUs|2000"
        "vpc|L-F678F1CE|VPCs per Region|5"
        "vpc|L-DF5E4CA3|Network Interfaces|10000"
        "eks|L-1194D53C|EKS Clusters|10"
        "eks|L-BD136A63|Nodes per Managed Node Group|450"
        "rds|L-952B80B8|RDS DB Clusters|40"
    )
    
    # Define non-critical quotas (warnings only)
    local noncritical_quotas=(
        "ec2|L-DB2E81BA|EC2 On-Demand G/VT vCPUs|256"
        "ec2|L-417A185B|EC2 On-Demand P vCPUs|128"
        "ec2|L-0263D0A3|Elastic IPs|15"
        "ebs|L-7A658B76|EBS GP3 Storage (TiB)|500"
        "eks|L-6D54EA21|Managed Node Groups per Cluster|30"
    )
    
    echo "Checking critical quotas..."
    echo "-------------------------------------------"
    
    for quota_def in "${critical_quotas[@]}"; do
        IFS='|' read -r service_code quota_code name required <<< "$quota_def"
        ((total_checks++))
        
        if check_quota "$service_code" "$quota_code" "$name" "$required"; then
            ((passed_checks++))
        else
            ((failed_checks++))
            failed_quotas+=("$name (requires $required)")
        fi
    done
    
    echo ""
    echo "Checking non-critical quotas..."
    echo "-------------------------------------------"
    
    for quota_def in "${noncritical_quotas[@]}"; do
        IFS='|' read -r service_code quota_code name required <<< "$quota_def"
        ((total_checks++))
        
        result=0
        check_quota "$service_code" "$quota_code" "$name" "$required" || result=$?
        
        case $result in
            0) ((passed_checks++)) ;;
            1) ((warning_checks++)) ;;
            2) ((warning_checks++)) ;;
        esac
    done
    
    # Summary
    echo ""
    echo "=============================================="
    echo "  Pre-flight Validation Summary"
    echo "=============================================="
    echo "Total checks: $total_checks"
    echo -e "Passed: ${GREEN}$passed_checks${NC}"
    echo -e "Failed (critical): ${RED}$failed_checks${NC}"
    echo -e "Warnings: ${YELLOW}$warning_checks${NC}"
    echo ""
    
    # Decision
    if [ $failed_checks -gt 0 ]; then
        echo -e "${RED}╔════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  PRE-FLIGHT VALIDATION FAILED              ║${NC}"
        echo -e "${RED}║  Deployment blocked due to insufficient    ║${NC}"
        echo -e "${RED}║  AWS service quotas.                       ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════╝${NC}"
        echo ""
        echo "Insufficient quotas:"
        for quota in "${failed_quotas[@]}"; do
            echo "  - $quota"
        done
        echo ""
        echo "To resolve:"
        echo "  1. Run: ./scripts/request-quota-increases.sh"
        echo "  2. Wait for quota increases to be approved (1-5 business days)"
        echo "  3. Re-run terraform plan/apply"
        echo ""
        echo "To skip quota validation (NOT RECOMMENDED):"
        echo "  Set skip_quota_check = true in module configuration"
        echo ""
        
        if [ "$AUTO_REQUEST_INCREASES" = "true" ]; then
            log_info "Auto-requesting quota increases..."
            "$(dirname "$0")/request-quota-increases.sh" --region "$AWS_REGION"
        fi
        
        exit 1
    fi
    
    if [ $warning_checks -gt 0 ]; then
        echo -e "${YELLOW}╔════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  PRE-FLIGHT VALIDATION PASSED WITH WARNINGS║${NC}"
        echo -e "${YELLOW}║  Some non-critical quotas may need attention║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════╝${NC}"
        echo ""
        echo "Deployment can proceed, but consider requesting quota increases"
        echo "for GPU workspaces and other optional features."
        echo ""
    else
        echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  PRE-FLIGHT VALIDATION PASSED              ║${NC}"
        echo -e "${GREEN}║  All AWS service quotas are sufficient.    ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
        echo ""
    fi
    
    echo "Deployment may proceed."
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --auto-request)
            AUTO_REQUEST_INCREASES="true"
            shift
            ;;
        --non-strict)
            STRICT_MODE="false"
            shift
            ;;
        --requirements-file)
            QUOTA_REQUIREMENTS_FILE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Pre-flight validation for AWS service quotas."
            echo "Blocks deployment if critical quotas are insufficient."
            echo ""
            echo "Options:"
            echo "  --region REGION           AWS region (default: us-east-1)"
            echo "  --auto-request            Automatically request quota increases if needed"
            echo "  --non-strict              Don't fail on non-critical quota issues"
            echo "  --requirements-file FILE  Path to quota requirements JSON"
            echo "  --help                    Show this help message"
            echo ""
            echo "Exit codes:"
            echo "  0 - All quotas sufficient"
            echo "  1 - Insufficient quotas (deployment blocked)"
            echo "  2 - Error during validation"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 2
            ;;
    esac
done

# Run validation
check_dependencies
verify_aws_credentials
run_preflight_validation
