#!/bin/bash
# AWS Service Quota Increase Request Script
# Requirements: 2a.3
#
# This script requests quota increases for AWS services
# required by the Coder deployment.

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
DRY_RUN="${DRY_RUN:-false}"

# Check dependencies
check_dependencies() {
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}Error: AWS CLI is not installed${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is not installed${NC}"
        exit 1
    fi
}

# Get current quota value
get_current_quota() {
    local service_code="$1"
    local quota_code="$2"
    
    aws service-quotas get-service-quota \
        --service-code "$service_code" \
        --quota-code "$quota_code" \
        --region "$AWS_REGION" \
        --query 'Quota.Value' \
        --output text 2>/dev/null || \
    aws service-quotas get-aws-default-service-quota \
        --service-code "$service_code" \
        --quota-code "$quota_code" \
        --region "$AWS_REGION" \
        --query 'Quota.Value' \
        --output text 2>/dev/null || echo "0"
}

# Check if quota is adjustable
is_quota_adjustable() {
    local service_code="$1"
    local quota_code="$2"
    
    local adjustable
    adjustable=$(aws service-quotas get-service-quota \
        --service-code "$service_code" \
        --quota-code "$quota_code" \
        --region "$AWS_REGION" \
        --query 'Quota.Adjustable' \
        --output text 2>/dev/null || echo "false")
    
    [ "$adjustable" = "True" ] || [ "$adjustable" = "true" ]
}

# Request quota increase
request_quota_increase() {
    local service_code="$1"
    local quota_code="$2"
    local desired_value="$3"
    local quota_name="$4"
    
    echo -e "${BLUE}Requesting increase for: $quota_name${NC}"
    echo "  Service: $service_code"
    echo "  Quota Code: $quota_code"
    echo "  Desired Value: $desired_value"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "  ${YELLOW}[DRY RUN] Would request increase to $desired_value${NC}"
        return 0
    fi
    
    local result
    result=$(aws service-quotas request-service-quota-increase \
        --service-code "$service_code" \
        --quota-code "$quota_code" \
        --desired-value "$desired_value" \
        --region "$AWS_REGION" \
        --output json 2>&1) || {
        echo -e "  ${RED}Failed to request increase: $result${NC}"
        return 1
    }
    
    local case_id
    case_id=$(echo "$result" | jq -r '.RequestedQuota.CaseId // "N/A"')
    local status
    status=$(echo "$result" | jq -r '.RequestedQuota.Status // "UNKNOWN"')
    
    echo -e "  ${GREEN}Request submitted${NC}"
    echo "  Case ID: $case_id"
    echo "  Status: $status"
    echo ""
}

# Check pending requests
check_pending_requests() {
    local service_code="$1"
    local quota_code="$2"
    
    aws service-quotas list-requested-service-quota-change-history-by-quota \
        --service-code "$service_code" \
        --quota-code "$quota_code" \
        --region "$AWS_REGION" \
        --query 'RequestedQuotas[?Status==`PENDING`]' \
        --output json 2>/dev/null | jq -r 'length'
}

# Main function
request_increases() {
    echo "=============================================="
    echo "AWS Service Quota Increase Requests"
    echo "Region: $AWS_REGION"
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}DRY RUN MODE - No changes will be made${NC}"
    fi
    echo "=============================================="
    echo ""
    
    # Define quotas to check and potentially increase
    local quotas=(
        "ec2|L-1216C47A|Running On-Demand Standard instances|1000"
        "ec2|L-34B43A08|All Standard Spot Instance Requests|2000"
        "ec2|L-DB2E81BA|Running On-Demand G and VT instances|256"
        "ec2|L-417A185B|Running On-Demand P instances|128"
        "ec2|L-0263D0A3|EC2-VPC Elastic IPs|6"
        "ebs|L-7A658B76|Storage for gp3 volumes (TiB)|500"
        "vpc|L-F678F1CE|VPCs per Region|5"
        "vpc|L-DF5E4CA3|Network interfaces per Region|10000"
        "eks|L-1194D53C|EKS Clusters|10"
        "eks|L-6D54EA21|Managed node groups per cluster|30"
        "eks|L-BD136A63|Nodes per managed node group|450"
        "rds|L-952B80B8|DB clusters|40"
    )
    
    local requests_made=0
    local requests_skipped=0
    local requests_failed=0
    
    for quota_def in "${quotas[@]}"; do
        IFS='|' read -r service_code quota_code name required <<< "$quota_def"
        
        current=$(get_current_quota "$service_code" "$quota_code")
        
        # Skip if current quota is sufficient
        if (( $(echo "$current >= $required" | bc -l 2>/dev/null || echo "0") )); then
            echo -e "${GREEN}✓${NC} $name: Current ($current) >= Required ($required)"
            ((requests_skipped++))
            continue
        fi
        
        # Check if quota is adjustable
        if ! is_quota_adjustable "$service_code" "$quota_code"; then
            echo -e "${YELLOW}⚠${NC} $name: Not adjustable via API (contact AWS Support)"
            ((requests_skipped++))
            continue
        fi
        
        # Check for pending requests
        pending=$(check_pending_requests "$service_code" "$quota_code")
        if [ "$pending" -gt 0 ]; then
            echo -e "${YELLOW}⏳${NC} $name: Request already pending"
            ((requests_skipped++))
            continue
        fi
        
        # Request increase
        if request_quota_increase "$service_code" "$quota_code" "$required" "$name"; then
            ((requests_made++))
        else
            ((requests_failed++))
        fi
    done
    
    echo ""
    echo "=============================================="
    echo "Summary"
    echo "=============================================="
    echo "Requests made: $requests_made"
    echo "Requests skipped: $requests_skipped"
    echo "Requests failed: $requests_failed"
    echo ""
    
    if [ $requests_made -gt 0 ]; then
        echo -e "${YELLOW}Note: Quota increase requests may take 1-5 business days to process.${NC}"
        echo "Check status with: aws service-quotas list-requested-service-quota-change-history --region $AWS_REGION"
    fi
    
    return $requests_failed
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --requirements-file)
            QUOTA_REQUIREMENTS_FILE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --region REGION           AWS region (default: us-east-1)"
            echo "  --dry-run                 Show what would be requested without making changes"
            echo "  --requirements-file FILE  Path to quota requirements JSON"
            echo "  --help                    Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run
check_dependencies
request_increases
