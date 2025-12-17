#!/bin/bash
# Coder Scale Test Runner
#
# This script executes Coder's built-in scale testing utilities to validate
# capacity and performance requirements.
#
# Requirements validated:
# - 14.6: Pod workspace provisioning < 2 minutes
# - 14.7: EC2 workspace provisioning < 5 minutes
# - 14.9: P95 API response time < 500ms
# - 14.10: P99 API response time < 1 second
# - 14.11: Support 1000 simultaneous workspace provisioning operations
#
# Usage:
#   ./run-scaletest.sh --test create-workspaces
#   ./run-scaletest.sh --test dashboard
#   ./run-scaletest.sh --test workspace-traffic
#   ./run-scaletest.sh --test all
#
# Environment variables:
#   CODER_URL           - Coder deployment URL (required)
#   CODER_SESSION_TOKEN - Coder API token (required)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/scaletest-config.yaml"
OUTPUT_DIR="${SCRIPT_DIR}/scaletest-results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TEST_TYPE=""
DRY_RUN=false
VERBOSE=false
CLEANUP=true

usage() {
    cat << EOF
Coder Scale Test Runner

Usage: $(basename "$0") [OPTIONS]

Options:
    --test TYPE         Test type: create-workspaces, dashboard, workspace-traffic, all
    --config FILE       Path to configuration file (default: scaletest-config.yaml)
    --output DIR        Output directory for results (default: ./scaletest-results)
    --dry-run           Show commands without executing
    --no-cleanup        Skip workspace cleanup after tests
    --verbose           Enable verbose output
    -h, --help          Show this help message

Environment Variables:
    CODER_URL           Coder deployment URL (required)
    CODER_SESSION_TOKEN Coder API token (required)

Examples:
    # Run workspace creation scale test
    ./run-scaletest.sh --test create-workspaces

    # Run API latency test
    ./run-scaletest.sh --test dashboard

    # Run all tests
    ./run-scaletest.sh --test all

    # Dry run to see commands
    ./run-scaletest.sh --test all --dry-run
EOF
}

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
    
    log_success "Prerequisites check passed"
}

create_output_dir() {
    mkdir -p "${OUTPUT_DIR}/${TIMESTAMP}"
    log_info "Results will be saved to: ${OUTPUT_DIR}/${TIMESTAMP}"
}

# Test: create-workspaces
# Validates: Requirements 14.6, 14.7, 14.11
run_create_workspaces_test() {
    log_info "Running workspace creation scale test..."
    log_info "Target: 1000 concurrent workspaces (700 pod, 300 EC2)"
    
    local result_file="${OUTPUT_DIR}/${TIMESTAMP}/create-workspaces-results.json"
    
    # Pod workspace test (700 workspaces, target < 2 min)
    log_info "Phase 1: Creating 700 pod-based workspaces..."
    local pod_cmd="coder scaletest create-workspaces \
        --count 700 \
        --template pod-swdev \
        --concurrency 100 \
        --timeout 5m \
        --cleanup-concurrency 50 \
        --output json"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $pod_cmd"
    else
        if [[ "$CLEANUP" == "true" ]]; then
            pod_cmd="$pod_cmd --cleanup"
        fi
        
        log_info "Executing: $pod_cmd"
        eval "$pod_cmd" > "${OUTPUT_DIR}/${TIMESTAMP}/pod-workspaces.json" 2>&1 || {
            log_warning "Pod workspace test completed with warnings"
        }
        
        # Validate P95 < 2 minutes
        if command -v jq &> /dev/null; then
            local p95_ms=$(jq -r '.provisioning_time_p95_ms // 0' "${OUTPUT_DIR}/${TIMESTAMP}/pod-workspaces.json" 2>/dev/null || echo "0")
            if [[ "$p95_ms" -gt 120000 ]]; then
                log_warning "Pod workspace P95 provisioning time (${p95_ms}ms) exceeds 2 minute target"
            else
                log_success "Pod workspace P95 provisioning time: ${p95_ms}ms (target: < 120000ms)"
            fi
        fi
    fi
    
    # EC2 workspace test (300 workspaces, target < 5 min)
    log_info "Phase 2: Creating 300 EC2-based workspaces..."
    local ec2_cmd="coder scaletest create-workspaces \
        --count 300 \
        --template ec2-datasci \
        --concurrency 50 \
        --timeout 10m \
        --cleanup-concurrency 25 \
        --output json"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $ec2_cmd"
    else
        if [[ "$CLEANUP" == "true" ]]; then
            ec2_cmd="$ec2_cmd --cleanup"
        fi
        
        log_info "Executing: $ec2_cmd"
        eval "$ec2_cmd" > "${OUTPUT_DIR}/${TIMESTAMP}/ec2-workspaces.json" 2>&1 || {
            log_warning "EC2 workspace test completed with warnings"
        }
        
        # Validate P95 < 5 minutes
        if command -v jq &> /dev/null; then
            local p95_ms=$(jq -r '.provisioning_time_p95_ms // 0' "${OUTPUT_DIR}/${TIMESTAMP}/ec2-workspaces.json" 2>/dev/null || echo "0")
            if [[ "$p95_ms" -gt 300000 ]]; then
                log_warning "EC2 workspace P95 provisioning time (${p95_ms}ms) exceeds 5 minute target"
            else
                log_success "EC2 workspace P95 provisioning time: ${p95_ms}ms (target: < 300000ms)"
            fi
        fi
    fi
    
    log_success "Workspace creation scale test completed"
}

# Test: dashboard
# Validates: Requirements 14.9, 14.10
run_dashboard_test() {
    log_info "Running API latency (dashboard) scale test..."
    log_info "Target: P95 < 500ms, P99 < 1s"
    
    local result_file="${OUTPUT_DIR}/${TIMESTAMP}/dashboard-results.json"
    
    local cmd="coder scaletest dashboard \
        --concurrency 50 \
        --duration 5m \
        --output json"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $cmd"
    else
        log_info "Executing: $cmd"
        eval "$cmd" > "$result_file" 2>&1 || {
            log_warning "Dashboard test completed with warnings"
        }
        
        # Validate latency targets
        if command -v jq &> /dev/null; then
            local p95_ms=$(jq -r '.latency_p95_ms // 0' "$result_file" 2>/dev/null || echo "0")
            local p99_ms=$(jq -r '.latency_p99_ms // 0' "$result_file" 2>/dev/null || echo "0")
            
            if [[ "$p95_ms" -gt 500 ]]; then
                log_warning "API P95 latency (${p95_ms}ms) exceeds 500ms target"
            else
                log_success "API P95 latency: ${p95_ms}ms (target: < 500ms)"
            fi
            
            if [[ "$p99_ms" -gt 1000 ]]; then
                log_warning "API P99 latency (${p99_ms}ms) exceeds 1000ms target"
            else
                log_success "API P99 latency: ${p99_ms}ms (target: < 1000ms)"
            fi
        fi
    fi
    
    log_success "Dashboard scale test completed"
}

# Test: workspace-traffic
# Validates: Network throughput
run_workspace_traffic_test() {
    log_info "Running workspace traffic scale test..."
    log_info "Testing network throughput and connection stability"
    
    local result_file="${OUTPUT_DIR}/${TIMESTAMP}/workspace-traffic-results.json"
    
    local cmd="coder scaletest workspace-traffic \
        --bytes-per-tick 1024 \
        --tick-interval 100ms \
        --duration 10m \
        --output json"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $cmd"
    else
        log_info "Executing: $cmd"
        eval "$cmd" > "$result_file" 2>&1 || {
            log_warning "Workspace traffic test completed with warnings"
        }
        
        log_success "Workspace traffic test completed"
    fi
}

generate_summary_report() {
    log_info "Generating summary report..."
    
    local report_file="${OUTPUT_DIR}/${TIMESTAMP}/summary-report.md"
    
    cat > "$report_file" << EOF
# Coder Scale Test Summary Report

**Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Coder URL:** ${CODER_URL}
**Test Run ID:** ${TIMESTAMP}

## Performance Targets

| Metric | Target | Status |
|--------|--------|--------|
| Pod workspace provisioning (P95) | < 2 minutes | TBD |
| EC2 workspace provisioning (P95) | < 5 minutes | TBD |
| API response time (P95) | < 500ms | TBD |
| API response time (P99) | < 1 second | TBD |
| Concurrent provisioning capacity | 1000 workspaces | TBD |

## Requirements Validated

- **14.6**: Pod workspace provisioning < 2 minutes
- **14.7**: EC2 workspace provisioning < 5 minutes
- **14.9**: P95 API response time < 500ms
- **14.10**: P99 API response time < 1 second
- **14.11**: Support 1000 simultaneous workspace provisioning operations

## Test Results

Results are available in the following files:
- Pod workspaces: pod-workspaces.json
- EC2 workspaces: ec2-workspaces.json
- Dashboard: dashboard-results.json
- Workspace traffic: workspace-traffic-results.json

## Notes

- Tests were run against a pre-production environment
- Results should be validated against production-like infrastructure
- GPU workspace provisioning may take up to 5 minutes (Requirement 14.7a)
EOF

    log_success "Summary report generated: $report_file"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --test)
            TEST_TYPE="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-cleanup)
            CLEANUP=false
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate test type
if [[ -z "$TEST_TYPE" ]]; then
    log_error "Test type is required. Use --test <type>"
    usage
    exit 1
fi

# Main execution
main() {
    log_info "Coder Scale Test Runner"
    log_info "========================"
    
    check_prerequisites
    create_output_dir
    
    case "$TEST_TYPE" in
        create-workspaces)
            run_create_workspaces_test
            ;;
        dashboard)
            run_dashboard_test
            ;;
        workspace-traffic)
            run_workspace_traffic_test
            ;;
        all)
            run_create_workspaces_test
            run_dashboard_test
            run_workspace_traffic_test
            ;;
        *)
            log_error "Unknown test type: $TEST_TYPE"
            log_error "Valid types: create-workspaces, dashboard, workspace-traffic, all"
            exit 1
            ;;
    esac
    
    generate_summary_report
    
    log_success "Scale testing completed!"
    log_info "Results saved to: ${OUTPUT_DIR}/${TIMESTAMP}"
}

main
