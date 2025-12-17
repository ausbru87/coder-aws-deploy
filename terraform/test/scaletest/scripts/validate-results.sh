#!/bin/bash
# Scale Test Results Validator
#
# This script validates scale test results against acceptance criteria.
#
# Requirements validated:
# - 14.6: Pod workspace provisioning < 2 minutes (P95)
# - 14.7: EC2 workspace provisioning < 5 minutes (P95)
# - 14.9: P95 API response time < 500ms
# - 14.10: P99 API response time < 1 second
# - 14.11: Support 1000 simultaneous workspace provisioning operations
#
# Usage:
#   ./validate-results.sh <results-directory>
#
# Example:
#   ./validate-results.sh ./scaletest-results/20241216_143000

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Acceptance criteria thresholds
POD_P95_TARGET_MS=120000      # 2 minutes in milliseconds
EC2_P95_TARGET_MS=300000      # 5 minutes in milliseconds
API_P95_TARGET_MS=500         # 500 milliseconds
API_P99_TARGET_MS=1000        # 1 second in milliseconds
MAX_ERROR_RATE=0.01           # 1% error rate

# Track overall pass/fail
OVERALL_PASS=true
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
    OVERALL_PASS=false
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

usage() {
    cat << EOF
Scale Test Results Validator

Usage: $(basename "$0") <results-directory>

Arguments:
    results-directory    Path to directory containing scale test result JSON files

Expected files in results directory:
    - pod-workspaces.json         Pod workspace creation results
    - ec2-workspaces.json         EC2 workspace creation results
    - dashboard-results.json      API latency test results
    - workspace-traffic-results.json  Network traffic test results

Example:
    $(basename "$0") ./scaletest-results/20241216_143000
EOF
}

validate_file_exists() {
    local file="$1"
    local name="$2"
    
    if [[ -f "$file" ]]; then
        return 0
    else
        log_warn "$name results file not found: $file"
        return 1
    fi
}

get_json_value() {
    local file="$1"
    local key="$2"
    local default="${3:-0}"
    
    jq -r "${key} // ${default}" "$file" 2>/dev/null || echo "$default"
}

validate_workspace_creation() {
    local results_dir="$1"
    
    echo ""
    echo "=========================================="
    echo "Workspace Creation Validation"
    echo "Requirements: 14.6, 14.7, 14.11"
    echo "=========================================="
    
    # Validate pod workspaces
    local pod_file="${results_dir}/pod-workspaces.json"
    if validate_file_exists "$pod_file" "Pod workspaces"; then
        ((TESTS_RUN++))
        
        local pod_p95=$(get_json_value "$pod_file" ".provisioning_time_p95_ms")
        local pod_total=$(get_json_value "$pod_file" ".total" "1")
        local pod_success=$(get_json_value "$pod_file" ".success" "0")
        local pod_failed=$(get_json_value "$pod_file" ".failed" "0")
        
        echo ""
        log_info "Pod Workspace Results:"
        echo "  Total: $pod_total"
        echo "  Success: $pod_success"
        echo "  Failed: $pod_failed"
        echo "  P95 Provisioning: ${pod_p95}ms"
        
        # Validate P95 < 2 minutes (Req 14.6)
        if [[ "$pod_p95" -lt "$POD_P95_TARGET_MS" ]]; then
            log_pass "Pod P95 (${pod_p95}ms) < ${POD_P95_TARGET_MS}ms target [Req 14.6]"
        else
            log_fail "Pod P95 (${pod_p95}ms) exceeds ${POD_P95_TARGET_MS}ms target [Req 14.6]"
        fi
        
        # Validate success rate
        ((TESTS_RUN++))
        if [[ "$pod_total" -gt 0 ]]; then
            local pod_error_rate=$(echo "scale=4; $pod_failed / $pod_total" | bc)
            if (( $(echo "$pod_error_rate < $MAX_ERROR_RATE" | bc -l) )); then
                log_pass "Pod error rate (${pod_error_rate}) < ${MAX_ERROR_RATE} target"
            else
                log_fail "Pod error rate (${pod_error_rate}) exceeds ${MAX_ERROR_RATE} target"
            fi
        fi
    fi
    
    # Validate EC2 workspaces
    local ec2_file="${results_dir}/ec2-workspaces.json"
    if validate_file_exists "$ec2_file" "EC2 workspaces"; then
        ((TESTS_RUN++))
        
        local ec2_p95=$(get_json_value "$ec2_file" ".provisioning_time_p95_ms")
        local ec2_total=$(get_json_value "$ec2_file" ".total" "1")
        local ec2_success=$(get_json_value "$ec2_file" ".success" "0")
        local ec2_failed=$(get_json_value "$ec2_file" ".failed" "0")
        
        echo ""
        log_info "EC2 Workspace Results:"
        echo "  Total: $ec2_total"
        echo "  Success: $ec2_success"
        echo "  Failed: $ec2_failed"
        echo "  P95 Provisioning: ${ec2_p95}ms"
        
        # Validate P95 < 5 minutes (Req 14.7)
        if [[ "$ec2_p95" -lt "$EC2_P95_TARGET_MS" ]]; then
            log_pass "EC2 P95 (${ec2_p95}ms) < ${EC2_P95_TARGET_MS}ms target [Req 14.7]"
        else
            log_fail "EC2 P95 (${ec2_p95}ms) exceeds ${EC2_P95_TARGET_MS}ms target [Req 14.7]"
        fi
        
        # Validate success rate
        ((TESTS_RUN++))
        if [[ "$ec2_total" -gt 0 ]]; then
            local ec2_error_rate=$(echo "scale=4; $ec2_failed / $ec2_total" | bc)
            if (( $(echo "$ec2_error_rate < $MAX_ERROR_RATE" | bc -l) )); then
                log_pass "EC2 error rate (${ec2_error_rate}) < ${MAX_ERROR_RATE} target"
            else
                log_fail "EC2 error rate (${ec2_error_rate}) exceeds ${MAX_ERROR_RATE} target"
            fi
        fi
    fi
    
    # Validate total capacity (Req 14.11)
    if [[ -f "$pod_file" ]] && [[ -f "$ec2_file" ]]; then
        ((TESTS_RUN++))
        local total_workspaces=$(($(get_json_value "$pod_file" ".total" "0") + $(get_json_value "$ec2_file" ".total" "0")))
        echo ""
        log_info "Total workspaces provisioned: $total_workspaces"
        
        if [[ "$total_workspaces" -ge 1000 ]]; then
            log_pass "Concurrent capacity ($total_workspaces) >= 1000 target [Req 14.11]"
        else
            log_warn "Concurrent capacity ($total_workspaces) < 1000 target [Req 14.11]"
        fi
    fi
}

validate_api_latency() {
    local results_dir="$1"
    
    echo ""
    echo "=========================================="
    echo "API Latency Validation"
    echo "Requirements: 14.9, 14.10"
    echo "=========================================="
    
    local dashboard_file="${results_dir}/dashboard-results.json"
    if ! validate_file_exists "$dashboard_file" "Dashboard"; then
        return
    fi
    
    local p95=$(get_json_value "$dashboard_file" ".latency_p95_ms")
    local p99=$(get_json_value "$dashboard_file" ".latency_p99_ms")
    local total=$(get_json_value "$dashboard_file" ".total_requests" "1")
    local failed=$(get_json_value "$dashboard_file" ".failed_requests" "0")
    
    echo ""
    log_info "API Latency Results:"
    echo "  Total requests: $total"
    echo "  Failed requests: $failed"
    echo "  P95 latency: ${p95}ms"
    echo "  P99 latency: ${p99}ms"
    
    # Validate P95 < 500ms (Req 14.9)
    ((TESTS_RUN++))
    if [[ "$p95" -lt "$API_P95_TARGET_MS" ]]; then
        log_pass "API P95 (${p95}ms) < ${API_P95_TARGET_MS}ms target [Req 14.9]"
    else
        log_fail "API P95 (${p95}ms) exceeds ${API_P95_TARGET_MS}ms target [Req 14.9]"
    fi
    
    # Validate P99 < 1s (Req 14.10)
    ((TESTS_RUN++))
    if [[ "$p99" -lt "$API_P99_TARGET_MS" ]]; then
        log_pass "API P99 (${p99}ms) < ${API_P99_TARGET_MS}ms target [Req 14.10]"
    else
        log_fail "API P99 (${p99}ms) exceeds ${API_P99_TARGET_MS}ms target [Req 14.10]"
    fi
    
    # Validate error rate
    ((TESTS_RUN++))
    if [[ "$total" -gt 0 ]]; then
        local error_rate=$(echo "scale=4; $failed / $total" | bc)
        if (( $(echo "$error_rate < $MAX_ERROR_RATE" | bc -l) )); then
            log_pass "API error rate (${error_rate}) < ${MAX_ERROR_RATE} target"
        else
            log_fail "API error rate (${error_rate}) exceeds ${MAX_ERROR_RATE} target"
        fi
    fi
}

validate_workspace_traffic() {
    local results_dir="$1"
    
    echo ""
    echo "=========================================="
    echo "Workspace Traffic Validation"
    echo "=========================================="
    
    local traffic_file="${results_dir}/workspace-traffic-results.json"
    if ! validate_file_exists "$traffic_file" "Workspace traffic"; then
        return
    fi
    
    local errors=$(get_json_value "$traffic_file" ".connection_errors")
    local packet_loss=$(get_json_value "$traffic_file" ".packet_loss_percent")
    local avg_latency=$(get_json_value "$traffic_file" ".avg_latency_ms")
    
    echo ""
    log_info "Workspace Traffic Results:"
    echo "  Connection errors: $errors"
    echo "  Packet loss: ${packet_loss}%"
    echo "  Avg latency: ${avg_latency}ms"
    
    # Validate connection errors
    ((TESTS_RUN++))
    if [[ "$errors" -eq 0 ]]; then
        log_pass "No connection errors detected"
    else
        log_fail "${errors} connection errors detected"
    fi
    
    # Validate packet loss
    ((TESTS_RUN++))
    if (( $(echo "$packet_loss < 1.0" | bc -l) )); then
        log_pass "Packet loss (${packet_loss}%) < 1% target"
    else
        log_fail "Packet loss (${packet_loss}%) exceeds 1% target"
    fi
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "VALIDATION SUMMARY"
    echo "=========================================="
    echo ""
    echo "Tests run: $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo ""
    
    if [[ "$OVERALL_PASS" == "true" ]]; then
        echo -e "${GREEN}OVERALL RESULT: PASS${NC}"
        echo ""
        echo "All acceptance criteria met. Deployment is ready for production."
        return 0
    else
        echo -e "${RED}OVERALL RESULT: FAIL${NC}"
        echo ""
        echo "Some acceptance criteria not met. Review failures before production deployment."
        return 1
    fi
}

# Main execution
main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi
    
    local results_dir="$1"
    
    if [[ ! -d "$results_dir" ]]; then
        echo "Error: Results directory not found: $results_dir"
        exit 1
    fi
    
    echo "=========================================="
    echo "CODER SCALE TEST VALIDATION"
    echo "=========================================="
    echo ""
    echo "Results directory: $results_dir"
    echo "Validation date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    
    validate_workspace_creation "$results_dir"
    validate_api_latency "$results_dir"
    validate_workspace_traffic "$results_dir"
    
    print_summary
}

main "$@"
