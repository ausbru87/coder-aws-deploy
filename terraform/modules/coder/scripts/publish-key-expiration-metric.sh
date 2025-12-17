#!/bin/bash
# publish-key-expiration-metric.sh
# Publishes provisioner key expiration metrics to CloudWatch
#
# Requirements:
# - 12f.2: Keys SHALL be rotated every 90 days
#
# This script should be run daily via cron or Kubernetes CronJob:
# 0 6 * * * /opt/coder/scripts/publish-key-expiration-metric.sh
#
# Prerequisites:
# - AWS CLI configured with appropriate permissions
# - Coder CLI configured with CODER_URL and CODER_SESSION_TOKEN
# - jq installed for JSON parsing

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

CODER_URL="${CODER_URL:-https://coder.example.com}"
AWS_REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="Coder/Security"
ROTATION_DAYS="${ROTATION_DAYS:-90}"
ORG="${CODER_ORG:-default}"

# =============================================================================
# Functions
# =============================================================================

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Calculate days between two dates
days_between() {
    local start_date="$1"
    local end_date="$2"
    
    # Handle different date formats (macOS vs Linux)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        local start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${start_date%%.*}" +%s 2>/dev/null || \
                          date -j -f "%Y-%m-%d" "${start_date%%T*}" +%s)
        local end_epoch=$(date +%s)
    else
        # Linux
        local start_epoch=$(date -d "$start_date" +%s)
        local end_epoch=$(date +%s)
    fi
    
    echo $(( (end_epoch - start_epoch) / 86400 ))
}

# Publish metric to CloudWatch
publish_metric() {
    local key_name="$1"
    local days_until_expiration="$2"
    
    aws cloudwatch put-metric-data \
        --region "$AWS_REGION" \
        --namespace "$NAMESPACE" \
        --metric-name "ProvisionerKeyDaysUntilExpiration" \
        --dimensions "KeyName=$key_name" \
        --value "$days_until_expiration" \
        --unit "Count" \
        --timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    log_info "Published metric for key '$key_name': $days_until_expiration days until expiration"
}

# Publish provisioner count metric
publish_provisioner_count() {
    local count="$1"
    
    aws cloudwatch put-metric-data \
        --region "$AWS_REGION" \
        --namespace "Coder/Provisioners" \
        --metric-name "ProvisionerConnectedCount" \
        --value "$count" \
        --unit "Count" \
        --timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    log_info "Published provisioner count metric: $count"
}

# =============================================================================
# Main Script
# =============================================================================

main() {
    log_info "Starting provisioner key expiration metric collection"
    log_info "Coder URL: $CODER_URL"
    log_info "AWS Region: $AWS_REGION"
    log_info "Rotation Policy: $ROTATION_DAYS days"
    
    # Verify Coder CLI is available
    if ! command -v coder &> /dev/null; then
        log_error "Coder CLI not found. Please install it first."
        exit 1
    fi
    
    # Verify AWS CLI is available
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install it first."
        exit 1
    fi
    
    # Verify jq is available
    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Please install it first."
        exit 1
    fi
    
    # Get provisioner keys
    log_info "Fetching provisioner keys from Coder..."
    keys=$(coder provisioner keys list --org "$ORG" -o json 2>/dev/null || echo "[]")
    
    if [ "$keys" == "[]" ] || [ -z "$keys" ]; then
        log_warn "No provisioner keys found"
        # Publish zero metric to indicate no keys
        aws cloudwatch put-metric-data \
            --region "$AWS_REGION" \
            --namespace "$NAMESPACE" \
            --metric-name "ProvisionerKeyCount" \
            --value 0 \
            --unit "Count"
        exit 0
    fi
    
    # Process each key
    key_count=0
    echo "$keys" | jq -c '.[]' | while read -r key; do
        key_name=$(echo "$key" | jq -r '.name')
        created_at=$(echo "$key" | jq -r '.created_at')
        
        if [ -z "$key_name" ] || [ "$key_name" == "null" ]; then
            log_warn "Skipping key with missing name"
            continue
        fi
        
        if [ -z "$created_at" ] || [ "$created_at" == "null" ]; then
            log_warn "Skipping key '$key_name' with missing creation date"
            continue
        fi
        
        # Calculate days since creation
        days_since_creation=$(days_between "$created_at" "now")
        days_until_expiration=$((ROTATION_DAYS - days_since_creation))
        
        # Ensure non-negative
        if [ "$days_until_expiration" -lt 0 ]; then
            days_until_expiration=0
            log_warn "Key '$key_name' has EXPIRED (created $days_since_creation days ago)"
        fi
        
        # Publish metric
        publish_metric "$key_name" "$days_until_expiration"
        
        # Log warning if approaching expiration
        if [ "$days_until_expiration" -le 14 ]; then
            log_warn "Key '$key_name' expires in $days_until_expiration days - rotation required!"
        fi
        
        key_count=$((key_count + 1))
    done
    
    # Publish key count metric
    aws cloudwatch put-metric-data \
        --region "$AWS_REGION" \
        --namespace "$NAMESPACE" \
        --metric-name "ProvisionerKeyCount" \
        --value "$key_count" \
        --unit "Count"
    
    # Get connected provisioner count
    log_info "Fetching connected provisioners..."
    provisioners=$(coder provisioner list --org "$ORG" -o json 2>/dev/null || echo "[]")
    provisioner_count=$(echo "$provisioners" | jq 'length')
    
    publish_provisioner_count "$provisioner_count"
    
    log_info "Metric collection complete"
}

# Run main function
main "$@"
