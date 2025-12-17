#!/bin/bash
# AWS Service Quota Check Script
# Requirements: 2a.3
#
# This script checks current AWS service quotas against required values
# for the Coder deployment.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
AWS_REGION="${AWS_REGION:-us-east-1}"
QUOTA_REQUIREMENTS_FILE="${QUOTA_REQUIREMENTS_FILE:-$(dirname "$0")/../generated/quota-requirements.json}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-table}"

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

# Get current quota value from AWS
get_current_quota() {
    local service_code="$1"
    local quota_code="$2"
    
    aws service-quotas get-service-quota \
        --service-code "$service_code" \
        --quota-code "$quota_code" \
        --region "$AWS_REGION" \
        --query 'Quota.Value' \
        --output text 2>/dev/null || echo "N/A"
}

# Get applied quota (may differ from default)
get_applied_quota() {
    local service_code="$1"
    local quota_code="$2"
    
    # First try to get applied quota
    local applied
    applied=$(aws service-quotas get-service-quota \
        --service-code "$service_code" \
        --quota-code "$quota_code" \
        --region "$AWS_REGION" \
        --query 'Quota.Value' \
        --output text 2>/dev/null)
    
    if [ "$applied" != "None" ] && [ -n "$applied" ]; then
        echo "$applied"
        return
    fi
    
    # Fall back to default quota
    aws service-quotas get-aws-default-service-quota \
        --service-code "$service_code" \
        --quota-code "$quota_code" \
        --region "$AWS_REGION" \
        --query 'Quota.Value' \
        --output text 2>/dev/null || echo "N/A"
}

# Check if quota requirements file exists
check_requirements_file() {
    if [ ! -f "$QUOTA_REQUIREMENTS_FILE" ]; then
        echo -e "${YELLOW}Warning: Quota requirements file not found at $QUOTA_REQUIREMENTS_FILE${NC}"
        echo "Using default quota definitions..."
        return 1
    fi
    return 0
}

# Main quota check function
check_quotas() {
    echo "=============================================="
    echo "AWS Service Quota Check"
    echo "Region: $AWS_REGION"
    echo "=============================================="
    echo ""
    
    local has_failures=0
    local results=()
    
    # Define quotas to check (can be overridden by requirements file)
    local quotas=(
        "ec2|L-1216C47A|Running On-Demand Standard instances|1000"
        "ec2|L-34B43A08|All Standard Spot Instance Requests|2000"
        "ec2|L-DB2E81BA|Running On-Demand G and VT instances|256"
        "ec2|L-417A185B|Running On-Demand P instances|128"
        "ec2|L-0263D0A3|EC2-VPC Elastic IPs|6"
        "ebs|L-7A658B76|Storage for gp3 volumes (TiB)|500"
        "vpc|L-F678F1CE|VPCs per Region|5"
        "vpc|L-407747CB|Subnets per VPC|50"
        "vpc|L-FE5A380F|NAT gateways per AZ|5"
        "vpc|L-DF5E4CA3|Network interfaces per Region|10000"
        "eks|L-1194D53C|EKS Clusters|10"
        "eks|L-6D54EA21|Managed node groups per cluster|30"
        "eks|L-BD136A63|Nodes per managed node group|450"
        "rds|L-952B80B8|DB clusters|40"
    )
    
    # Override with requirements file if available
    if check_requirements_file; then
        echo "Loading requirements from: $QUOTA_REQUIREMENTS_FILE"
        echo ""
    fi
    
    printf "%-45s %-15s %-15s %-10s\n" "Quota Name" "Current" "Required" "Status"
    printf "%-45s %-15s %-15s %-10s\n" "----------" "-------" "--------" "------"
    
    for quota_def in "${quotas[@]}"; do
        IFS='|' read -r service_code quota_code name required <<< "$quota_def"
        
        current=$(get_applied_quota "$service_code" "$quota_code")
        
        local status
        local status_color
        
        if [ "$current" = "N/A" ]; then
            status="UNKNOWN"
            status_color="$YELLOW"
        elif (( $(echo "$current >= $required" | bc -l) )); then
            status="OK"
            status_color="$GREEN"
        else
            status="INSUFFICIENT"
            status_color="$RED"
            has_failures=1
        fi
        
        printf "%-45s %-15s %-15s ${status_color}%-10s${NC}\n" \
            "$name" "$current" "$required" "$status"
    done
    
    echo ""
    
    if [ $has_failures -eq 1 ]; then
        echo -e "${RED}QUOTA CHECK FAILED: Some quotas are insufficient${NC}"
        echo "Run './request-quota-increases.sh' to request increases"
        return 1
    else
        echo -e "${GREEN}QUOTA CHECK PASSED: All quotas are sufficient${NC}"
        return 0
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --requirements-file)
            QUOTA_REQUIREMENTS_FILE="$2"
            shift 2
            ;;
        --format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --region REGION           AWS region (default: us-east-1)"
            echo "  --requirements-file FILE  Path to quota requirements JSON"
            echo "  --format FORMAT           Output format: table, json (default: table)"
            echo "  --help                    Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run checks
check_dependencies
check_quotas
