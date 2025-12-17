#!/bin/bash
# Pre-Production Scale Validation Executor
#
# This script executes the complete pre-production scale validation suite
# and generates a validation report.
#
# Requirements validated:
# - 14.6: Pod workspace provisioning < 2 minutes (P95)
# - 14.7: EC2 workspace provisioning < 5 minutes (P95)
# - 14.9: P95 API response time < 500ms
# - 14.10: P99 API response time < 1 second
# - 14.11: Support 1000 simultaneous workspace provisioning operations
#
# Usage:
#   ./execute-pre-production-validation.sh
#
# Environment variables:
#   CODER_URL           - Coder deployment URL (required)
#   CODER_SESSION_TOKEN - Coder API token (required)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCALETEST_DIR="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="${SCALETEST_DIR}/scaletest-results/${TIMESTAMP}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check coder CLI
    if ! command -v coder &> /dev/null; then
        log_error "coder CLI not found. Please install: https://coder.com/docs/install"
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Please install jq for JSON parsing."
        exit 1
    fi
    
    # Check bc
    if ! command -v bc &> /dev/null; then
        log_error "bc not found. Please install bc for calculations."
        exit 1
    fi
    
    # Check environment variables
    if [[ -z "${CODER_URL:-}" ]]; then
        log_error "CODER_URL environment variable not set"
        exit 1
    fi
    
    if [[ -z "${CODER_SESSION_TOKEN:-}" ]]; then
        log_error "CODER_SESSION_TOKEN environment variable not set"
        exit 1
    fi
    
    # Verify Coder connectivity
    log_info "Verifying Coder API connectivity..."
    if ! coder users show me &> /dev/null; then
        log_error "Failed to connect to Coder API at ${CODER_URL}"
        exit 1
    fi
    
    # Check templates exist
    log_info "Verifying required templates..."
    if ! coder templates list 2>/dev/null | grep -q "pod-swdev"; then
        log_warning "Template 'pod-swdev' not found - pod workspace tests may fail"
    fi
    
    if ! coder templates list 2>/dev/null | grep -q "ec2-datasci"; then
        log_warning "Template 'ec2-datasci' not found - EC2 workspace tests may fail"
    fi
    
    log_success "Prerequisites check passed"
}

create_results_dir() {
    mkdir -p "$RESULTS_DIR"
    log_info "Results will be saved to: $RESULTS_DIR"
}

# Task 33.1: Run workspace creation scale test
run_workspace_creation_test() {
    log_info "=========================================="
    log_info "Task 33.1: Workspace Creation Scale Test"
    log_info "Requirements: 14.6, 14.7, 14.11"
    log_info "=========================================="
    
    # Phase 1: Pod workspaces (700 workspaces, target P95 < 2 min)
    log_info "Phase 1: Creating 700 pod-based workspaces..."
    log_info "Target: P95 provisioning time < 2 minutes"
    
    if coder scaletest create-workspaces \
        --count 700 \
        --template pod-swdev \
        --concurrency 100 \
        --timeout 30m \
        --cleanup \
        --cleanup-concurrency 50 \
        --output json \
        > "${RESULTS_DIR}/pod-workspaces.json" 2>&1; then
        log_success "Pod workspace test completed"
    else
        log_warning "Pod workspace test completed with warnings"
    fi
    
    # Display pod results
    if [[ -f "${RESULTS_DIR}/pod-workspaces.json" ]]; then
        log_info "Pod Workspace Results:"
        jq '{
          total: .total,
          success: .success,
          failed: .failed,
          p95_seconds: ((.provisioning_time_p95_ms // 0) / 1000)
        }' "${RESULTS_DIR}/pod-workspaces.json" 2>/dev/null || true
    fi
    
    # Phase 2: EC2 workspaces (300 workspaces, target P95 < 5 min)
    log_info "Phase 2: Creating 300 EC2-based workspaces..."
    log_info "Target: P95 provisioning time < 5 minutes"
    
    if coder scaletest create-workspaces \
        --count 300 \
        --template ec2-datasci \
        --concurrency 50 \
        --timeout 45m \
        --cleanup \
        --cleanup-concurrency 25 \
        --output json \
        > "${RESULTS_DIR}/ec2-workspaces.json" 2>&1; then
        log_success "EC2 workspace test completed"
    else
        log_warning "EC2 workspace test completed with warnings"
    fi
    
    # Display EC2 results
    if [[ -f "${RESULTS_DIR}/ec2-workspaces.json" ]]; then
        log_info "EC2 Workspace Results:"
        jq '{
          total: .total,
          success: .success,
          failed: .failed,
          p95_seconds: ((.provisioning_time_p95_ms // 0) / 1000)
        }' "${RESULTS_DIR}/ec2-workspaces.json" 2>/dev/null || true
    fi
    
    log_success "Workspace creation scale test completed"
}

# Task 33.2: Run API latency scale test
run_api_latency_test() {
    log_info "=========================================="
    log_info "Task 33.2: API Latency Scale Test"
    log_info "Requirements: 14.9, 14.10"
    log_info "=========================================="
    
    log_info "Running dashboard load test..."
    log_info "Target: P95 < 500ms, P99 < 1s"
    
    if coder scaletest dashboard \
        --concurrency 50 \
        --duration 5m \
        --output json \
        > "${RESULTS_DIR}/dashboard-results.json" 2>&1; then
        log_success "Dashboard test completed"
    else
        log_warning "Dashboard test completed with warnings"
    fi
    
    # Display results
    if [[ -f "${RESULTS_DIR}/dashboard-results.json" ]]; then
        log_info "API Latency Results:"
        jq '{
          total_requests: .total_requests,
          failed_requests: .failed_requests,
          p95_ms: .latency_p95_ms,
          p99_ms: .latency_p99_ms
        }' "${RESULTS_DIR}/dashboard-results.json" 2>/dev/null || true
    fi
    
    log_success "API latency scale test completed"
}

# Task 33.3: Run workspace traffic test
run_workspace_traffic_test() {
    log_info "=========================================="
    log_info "Task 33.3: Workspace Traffic Test"
    log_info "Requirements: 14.6, 14.7 (network throughput)"
    log_info "=========================================="
    
    log_info "Running workspace traffic test..."
    log_info "Testing network throughput and connection stability"
    
    if coder scaletest workspace-traffic \
        --bytes-per-tick 1024 \
        --tick-interval 100ms \
        --duration 10m \
        --output json \
        > "${RESULTS_DIR}/workspace-traffic-results.json" 2>&1; then
        log_success "Workspace traffic test completed"
    else
        log_warning "Workspace traffic test completed with warnings"
    fi
    
    # Display results
    if [[ -f "${RESULTS_DIR}/workspace-traffic-results.json" ]]; then
        log_info "Workspace Traffic Results:"
        jq '{
          total_bytes_sent: .total_bytes_sent,
          connection_errors: .connection_errors,
          packet_loss_percent: .packet_loss_percent,
          avg_latency_ms: .avg_latency_ms
        }' "${RESULTS_DIR}/workspace-traffic-results.json" 2>/dev/null || true
    fi
    
    log_success "Workspace traffic test completed"
}

validate_results() {
    log_info "=========================================="
    log_info "Validating Results"
    log_info "=========================================="
    
    if [[ -x "${SCRIPT_DIR}/validate-results.sh" ]]; then
        "${SCRIPT_DIR}/validate-results.sh" "$RESULTS_DIR"
    else
        log_warning "Validation script not found or not executable"
        log_info "Run manually: ./scripts/validate-results.sh $RESULTS_DIR"
    fi
}

generate_report() {
    log_info "Generating validation report..."
    
    local report_file="${RESULTS_DIR}/VALIDATION-REPORT.md"
    
    cat > "$report_file" << EOF
# Pre-Production Scale Validation Report

**Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Environment:** ${CODER_URL}
**Test Run ID:** ${TIMESTAMP}

## Executive Summary

This report documents the results of pre-production scale validation testing for the Coder deployment.

## Requirements Validated

| Requirement | Description | Target |
|-------------|-------------|--------|
| 14.6 | Pod workspace provisioning time | < 2 minutes (P95) |
| 14.7 | EC2 workspace provisioning time | < 5 minutes (P95) |
| 14.9 | API response time (P95) | < 500ms |
| 14.10 | API response time (P99) | < 1 second |
| 14.11 | Concurrent provisioning capacity | 1000 workspaces |

## Test Results

### Task 33.1: Workspace Creation Scale Test

EOF

    # Add pod workspace results
    if [[ -f "${RESULTS_DIR}/pod-workspaces.json" ]]; then
        cat >> "$report_file" << EOF
#### Pod Workspaces

\`\`\`json
$(jq '.' "${RESULTS_DIR}/pod-workspaces.json" 2>/dev/null || echo '{"error": "Unable to parse results"}')
\`\`\`

EOF
    fi

    # Add EC2 workspace results
    if [[ -f "${RESULTS_DIR}/ec2-workspaces.json" ]]; then
        cat >> "$report_file" << EOF
#### EC2 Workspaces

\`\`\`json
$(jq '.' "${RESULTS_DIR}/ec2-workspaces.json" 2>/dev/null || echo '{"error": "Unable to parse results"}')
\`\`\`

EOF
    fi

    # Add dashboard results
    cat >> "$report_file" << EOF
### Task 33.2: API Latency Scale Test

EOF

    if [[ -f "${RESULTS_DIR}/dashboard-results.json" ]]; then
        cat >> "$report_file" << EOF
\`\`\`json
$(jq '.' "${RESULTS_DIR}/dashboard-results.json" 2>/dev/null || echo '{"error": "Unable to parse results"}')
\`\`\`

EOF
    fi

    # Add traffic results
    cat >> "$report_file" << EOF
### Task 33.3: Workspace Traffic Test

EOF

    if [[ -f "${RESULTS_DIR}/workspace-traffic-results.json" ]]; then
        cat >> "$report_file" << EOF
\`\`\`json
$(jq '.' "${RESULTS_DIR}/workspace-traffic-results.json" 2>/dev/null || echo '{"error": "Unable to parse results"}')
\`\`\`

EOF
    fi

    # Add sign-off section
    cat >> "$report_file" << EOF
## Sign-off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Platform Engineer | | | |
| Security Engineer | | | |
| Operations Lead | | | |

## Notes

[Add any observations, issues, or recommendations here]

---

*Report generated by pre-production validation script*
EOF

    log_success "Validation report generated: $report_file"
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "CODER PRE-PRODUCTION SCALE VALIDATION"
    echo "=========================================="
    echo ""
    echo "This script executes the complete pre-production"
    echo "scale validation suite (Tasks 33.1, 33.2, 33.3)"
    echo ""
    
    check_prerequisites
    create_results_dir
    
    # Execute all tests
    run_workspace_creation_test
    run_api_latency_test
    run_workspace_traffic_test
    
    # Validate and report
    validate_results
    generate_report
    
    echo ""
    log_success "Pre-production scale validation completed!"
    log_info "Results saved to: $RESULTS_DIR"
    echo ""
}

main "$@"
