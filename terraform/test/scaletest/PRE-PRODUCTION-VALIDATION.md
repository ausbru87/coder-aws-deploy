# Pre-Production Scale Validation Runbook

This runbook documents the procedures for executing scale validation tests against a pre-production Coder deployment. These tests validate that the deployment meets performance and capacity requirements before production use.

## Overview

**Purpose:** Validate Coder deployment meets performance requirements before production release.

**Requirements Validated:**
| Requirement | Description | Target |
|-------------|-------------|--------|
| 14.6 | Pod workspace provisioning time | < 2 minutes (P95) |
| 14.7 | EC2 workspace provisioning time | < 5 minutes (P95) |
| 14.9 | API response time (P95) | < 500ms |
| 14.10 | API response time (P99) | < 1 second |
| 14.11 | Concurrent provisioning capacity | 1000 workspaces |

**Estimated Duration:** 2-3 hours for full validation

## Prerequisites Checklist

Before executing scale tests, verify the following:

### Infrastructure Readiness

- [ ] Pre-production Coder deployment is accessible
- [ ] EKS cluster is healthy with all node groups operational
- [ ] Aurora database is healthy with sufficient capacity
- [ ] NLB is healthy with all targets registered
- [ ] VPC endpoints are operational

### Coder Configuration

- [ ] Templates deployed: `pod-swdev`, `ec2-datasci`
- [ ] Workspace quota set to minimum 1100 workspaces
- [ ] External provisioners are running and healthy
- [ ] Provisioner nodes scaled to handle concurrent operations

### Access Requirements

- [ ] Coder CLI installed (version 2.x or later)
- [ ] Admin API token with sufficient permissions
- [ ] AWS CLI configured for CloudWatch access
- [ ] `jq` installed for JSON parsing

### Environment Variables

```bash
# Required environment variables
export CODER_URL="https://coder.pre-prod.example.com"
export CODER_SESSION_TOKEN="your-admin-api-token"

# Optional: AWS region for CloudWatch metrics
export AWS_REGION="us-east-1"
```

## Pre-Test Validation

Run these checks before starting scale tests:

```bash
# 1. Verify Coder connectivity
coder whoami

# 2. Verify templates exist
coder templates list | grep -E "(pod-swdev|ec2-datasci)"

# 3. Check current workspace count
coder list --all | wc -l

# 4. Verify node capacity
kubectl get nodes -l coder.com/node-type=workspace -o wide
kubectl get nodes -l coder.com/node-type=provisioner -o wide

# 5. Check provisioner health
kubectl get pods -n coder-prov -l app=coder-provisioner

# 6. Verify database connectivity
kubectl exec -n coder deploy/coder -- coder server dbcrypt status 2>/dev/null || echo "DB check via logs"
```

---

## Test 1: Workspace Creation Scale Test

**Task:** 33.1 Run workspace creation scale test  
**Requirements:** 14.6, 14.7, 14.11  
**Duration:** 45-60 minutes

### Objective

Verify the system can provision 1000 concurrent workspaces:
- 700 pod-based workspaces (target P95 < 2 minutes)
- 300 EC2-based workspaces (target P95 < 5 minutes)

### Execution Steps

#### Step 1: Prepare Environment

```bash
cd terraform/test/scaletest

# Create results directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p scaletest-results/${TIMESTAMP}
export RESULTS_DIR="scaletest-results/${TIMESTAMP}"
```

#### Step 2: Run Pod Workspace Test (700 workspaces)

```bash
# Execute pod workspace creation test
coder scaletest create-workspaces \
  --count 700 \
  --template pod-swdev \
  --concurrency 100 \
  --timeout 30m \
  --cleanup \
  --cleanup-concurrency 50 \
  --output json \
  > "${RESULTS_DIR}/pod-workspaces.json" 2>&1

# Check results
echo "Pod Workspace Test Results:"
jq '{
  total: .total,
  success: .success,
  failed: .failed,
  p50_seconds: (.provisioning_time_p50_ms / 1000),
  p95_seconds: (.provisioning_time_p95_ms / 1000),
  p99_seconds: (.provisioning_time_p99_ms / 1000)
}' "${RESULTS_DIR}/pod-workspaces.json"
```

#### Step 3: Run EC2 Workspace Test (300 workspaces)

```bash
# Execute EC2 workspace creation test
coder scaletest create-workspaces \
  --count 300 \
  --template ec2-datasci \
  --concurrency 50 \
  --timeout 45m \
  --cleanup \
  --cleanup-concurrency 25 \
  --output json \
  > "${RESULTS_DIR}/ec2-workspaces.json" 2>&1

# Check results
echo "EC2 Workspace Test Results:"
jq '{
  total: .total,
  success: .success,
  failed: .failed,
  p50_seconds: (.provisioning_time_p50_ms / 1000),
  p95_seconds: (.provisioning_time_p95_ms / 1000),
  p99_seconds: (.provisioning_time_p99_ms / 1000)
}' "${RESULTS_DIR}/ec2-workspaces.json"
```

### Validation Criteria

| Metric | Target | Pass Condition |
|--------|--------|----------------|
| Pod P95 provisioning | < 120 seconds | `provisioning_time_p95_ms < 120000` |
| EC2 P95 provisioning | < 300 seconds | `provisioning_time_p95_ms < 300000` |
| Success rate | > 99% | `success / total > 0.99` |
| Error rate | < 1% | `failed / total < 0.01` |

### Validation Script

```bash
#!/bin/bash
# validate-workspace-creation.sh

POD_P95=$(jq -r '.provisioning_time_p95_ms // 0' "${RESULTS_DIR}/pod-workspaces.json")
EC2_P95=$(jq -r '.provisioning_time_p95_ms // 0' "${RESULTS_DIR}/ec2-workspaces.json")
POD_SUCCESS=$(jq -r '.success // 0' "${RESULTS_DIR}/pod-workspaces.json")
POD_TOTAL=$(jq -r '.total // 1' "${RESULTS_DIR}/pod-workspaces.json")
EC2_SUCCESS=$(jq -r '.success // 0' "${RESULTS_DIR}/ec2-workspaces.json")
EC2_TOTAL=$(jq -r '.total // 1' "${RESULTS_DIR}/ec2-workspaces.json")

echo "=== Workspace Creation Validation ==="
echo ""

# Pod workspace validation
if [ "$POD_P95" -lt 120000 ]; then
  echo "✅ PASS: Pod P95 (${POD_P95}ms) < 120000ms target"
else
  echo "❌ FAIL: Pod P95 (${POD_P95}ms) exceeds 120000ms target"
fi

# EC2 workspace validation
if [ "$EC2_P95" -lt 300000 ]; then
  echo "✅ PASS: EC2 P95 (${EC2_P95}ms) < 300000ms target"
else
  echo "❌ FAIL: EC2 P95 (${EC2_P95}ms) exceeds 300000ms target"
fi

# Success rate validation
POD_RATE=$(echo "scale=4; $POD_SUCCESS / $POD_TOTAL" | bc)
EC2_RATE=$(echo "scale=4; $EC2_SUCCESS / $EC2_TOTAL" | bc)

echo ""
echo "Pod success rate: ${POD_RATE} (${POD_SUCCESS}/${POD_TOTAL})"
echo "EC2 success rate: ${EC2_RATE} (${EC2_SUCCESS}/${EC2_TOTAL})"
```

### Troubleshooting

If workspace creation fails:

1. **Check provisioner logs:**
   ```bash
   kubectl logs -n coder-prov -l app=coder-provisioner --tail=100
   ```

2. **Check node autoscaling:**
   ```bash
   kubectl get nodes -l coder.com/node-type=workspace
   kubectl describe nodes | grep -A 10 "Conditions:"
   ```

3. **Check AWS quotas:**
   ```bash
   aws service-quotas get-service-quota \
     --service-code ec2 \
     --quota-code L-1216C47A
   ```

---

## Test 2: API Latency Scale Test

**Task:** 33.2 Run API latency scale test  
**Requirements:** 14.9, 14.10  
**Duration:** 10-15 minutes

### Objective

Verify API response times under load:
- P95 latency < 500ms
- P99 latency < 1 second

### Execution Steps

```bash
# Execute dashboard load test
coder scaletest dashboard \
  --concurrency 50 \
  --duration 5m \
  --output json \
  > "${RESULTS_DIR}/dashboard-results.json" 2>&1

# Check results
echo "API Latency Test Results:"
jq '{
  total_requests: .total_requests,
  successful_requests: .successful_requests,
  failed_requests: .failed_requests,
  p50_ms: .latency_p50_ms,
  p95_ms: .latency_p95_ms,
  p99_ms: .latency_p99_ms,
  error_rate_percent: ((.failed_requests / .total_requests) * 100)
}' "${RESULTS_DIR}/dashboard-results.json"
```

### Validation Criteria

| Metric | Target | Pass Condition |
|--------|--------|----------------|
| P95 latency | < 500ms | `latency_p95_ms < 500` |
| P99 latency | < 1000ms | `latency_p99_ms < 1000` |
| Error rate | < 1% | `failed_requests / total_requests < 0.01` |

### Validation Script

```bash
#!/bin/bash
# validate-api-latency.sh

P95=$(jq -r '.latency_p95_ms // 0' "${RESULTS_DIR}/dashboard-results.json")
P99=$(jq -r '.latency_p99_ms // 0' "${RESULTS_DIR}/dashboard-results.json")
FAILED=$(jq -r '.failed_requests // 0' "${RESULTS_DIR}/dashboard-results.json")
TOTAL=$(jq -r '.total_requests // 1' "${RESULTS_DIR}/dashboard-results.json")

echo "=== API Latency Validation ==="
echo ""

# P95 validation
if [ "$P95" -lt 500 ]; then
  echo "✅ PASS: P95 latency (${P95}ms) < 500ms target"
else
  echo "❌ FAIL: P95 latency (${P95}ms) exceeds 500ms target"
fi

# P99 validation
if [ "$P99" -lt 1000 ]; then
  echo "✅ PASS: P99 latency (${P99}ms) < 1000ms target"
else
  echo "❌ FAIL: P99 latency (${P99}ms) exceeds 1000ms target"
fi

# Error rate
ERROR_RATE=$(echo "scale=4; $FAILED / $TOTAL * 100" | bc)
echo ""
echo "Error rate: ${ERROR_RATE}% (${FAILED}/${TOTAL} failed)"
```

### Troubleshooting

If API latency exceeds targets:

1. **Check coderd pod resources:**
   ```bash
   kubectl top pods -n coder -l app.kubernetes.io/name=coder
   ```

2. **Check database performance:**
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/RDS \
     --metric-name CPUUtilization \
     --dimensions Name=DBClusterIdentifier,Value=coder-aurora \
     --start-time $(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
     --period 60 \
     --statistics Average Maximum
   ```

3. **Check NLB target health:**
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn <target-group-arn>
   ```

---

## Test 3: Workspace Traffic Test

**Task:** 33.3 Run workspace traffic test  
**Requirements:** 14.6, 14.7 (network throughput)  
**Duration:** 15-20 minutes

### Objective

Verify network throughput and connection stability for workspace connectivity.

### Execution Steps

```bash
# Execute workspace traffic test
coder scaletest workspace-traffic \
  --bytes-per-tick 1024 \
  --tick-interval 100ms \
  --duration 10m \
  --output json \
  > "${RESULTS_DIR}/workspace-traffic-results.json" 2>&1

# Check results
echo "Workspace Traffic Test Results:"
jq '{
  total_bytes_sent: .total_bytes_sent,
  total_bytes_received: .total_bytes_received,
  avg_latency_ms: .avg_latency_ms,
  max_latency_ms: .max_latency_ms,
  connection_errors: .connection_errors,
  packet_loss_percent: .packet_loss_percent
}' "${RESULTS_DIR}/workspace-traffic-results.json"
```

### Validation Criteria

| Metric | Target | Pass Condition |
|--------|--------|----------------|
| Connection errors | 0 | `connection_errors == 0` |
| Packet loss | < 1% | `packet_loss_percent < 1.0` |
| Avg latency | < 200ms | `avg_latency_ms < 200` |

### Validation Script

```bash
#!/bin/bash
# validate-workspace-traffic.sh

ERRORS=$(jq -r '.connection_errors // 0' "${RESULTS_DIR}/workspace-traffic-results.json")
PACKET_LOSS=$(jq -r '.packet_loss_percent // 0' "${RESULTS_DIR}/workspace-traffic-results.json")
AVG_LATENCY=$(jq -r '.avg_latency_ms // 0' "${RESULTS_DIR}/workspace-traffic-results.json")

echo "=== Workspace Traffic Validation ==="
echo ""

# Connection errors
if [ "$ERRORS" -eq 0 ]; then
  echo "✅ PASS: No connection errors"
else
  echo "❌ FAIL: ${ERRORS} connection errors detected"
fi

# Packet loss
LOSS_INT=$(echo "$PACKET_LOSS" | cut -d. -f1)
if [ "${LOSS_INT:-0}" -lt 1 ]; then
  echo "✅ PASS: Packet loss (${PACKET_LOSS}%) < 1% target"
else
  echo "❌ FAIL: Packet loss (${PACKET_LOSS}%) exceeds 1% target"
fi

# Average latency
LATENCY_INT=$(echo "$AVG_LATENCY" | cut -d. -f1)
if [ "${LATENCY_INT:-0}" -lt 200 ]; then
  echo "✅ PASS: Avg latency (${AVG_LATENCY}ms) < 200ms target"
else
  echo "⚠️ WARNING: Avg latency (${AVG_LATENCY}ms) exceeds 200ms target"
fi
```

### Troubleshooting

If traffic test fails:

1. **Check DERP relay status:**
   ```bash
   curl -s "${CODER_URL}/derp/latency-check" | jq .
   ```

2. **Check NAT Gateway metrics:**
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/NATGateway \
     --metric-name PacketsDropCount \
     --dimensions Name=NatGatewayId,Value=<nat-gw-id> \
     --start-time $(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
     --period 60 \
     --statistics Sum
   ```

3. **Check security group rules:**
   ```bash
   aws ec2 describe-security-groups \
     --group-ids <workspace-sg-id> \
     --query 'SecurityGroups[].IpPermissions'
   ```

---

## Post-Test Summary Report

After completing all tests, generate a summary report:

```bash
#!/bin/bash
# generate-summary-report.sh

cat > "${RESULTS_DIR}/VALIDATION-SUMMARY.md" << EOF
# Pre-Production Scale Validation Summary

**Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Environment:** ${CODER_URL}
**Test Run ID:** ${TIMESTAMP}

## Test Results

### 1. Workspace Creation (Req 14.6, 14.7, 14.11)

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Pod P95 | < 120s | $(jq -r '(.provisioning_time_p95_ms // 0) / 1000' "${RESULTS_DIR}/pod-workspaces.json")s | $([ $(jq -r '.provisioning_time_p95_ms // 999999' "${RESULTS_DIR}/pod-workspaces.json") -lt 120000 ] && echo "✅ PASS" || echo "❌ FAIL") |
| EC2 P95 | < 300s | $(jq -r '(.provisioning_time_p95_ms // 0) / 1000' "${RESULTS_DIR}/ec2-workspaces.json")s | $([ $(jq -r '.provisioning_time_p95_ms // 999999' "${RESULTS_DIR}/ec2-workspaces.json") -lt 300000 ] && echo "✅ PASS" || echo "❌ FAIL") |
| Total workspaces | 1000 | $(( $(jq -r '.total // 0' "${RESULTS_DIR}/pod-workspaces.json") + $(jq -r '.total // 0' "${RESULTS_DIR}/ec2-workspaces.json") )) | - |

### 2. API Latency (Req 14.9, 14.10)

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| P95 latency | < 500ms | $(jq -r '.latency_p95_ms // 0' "${RESULTS_DIR}/dashboard-results.json")ms | $([ $(jq -r '.latency_p95_ms // 999999' "${RESULTS_DIR}/dashboard-results.json") -lt 500 ] && echo "✅ PASS" || echo "❌ FAIL") |
| P99 latency | < 1000ms | $(jq -r '.latency_p99_ms // 0' "${RESULTS_DIR}/dashboard-results.json")ms | $([ $(jq -r '.latency_p99_ms // 999999' "${RESULTS_DIR}/dashboard-results.json") -lt 1000 ] && echo "✅ PASS" || echo "❌ FAIL") |

### 3. Workspace Traffic

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Connection errors | 0 | $(jq -r '.connection_errors // 0' "${RESULTS_DIR}/workspace-traffic-results.json") | $([ $(jq -r '.connection_errors // 999' "${RESULTS_DIR}/workspace-traffic-results.json") -eq 0 ] && echo "✅ PASS" || echo "❌ FAIL") |
| Packet loss | < 1% | $(jq -r '.packet_loss_percent // 0' "${RESULTS_DIR}/workspace-traffic-results.json")% | - |

## Overall Status

**Validation Result:** [PENDING REVIEW]

## Sign-off

- [ ] Platform Engineer: _________________ Date: _________
- [ ] Security Engineer: _________________ Date: _________
- [ ] Operations Lead: _________________ Date: _________

## Notes

[Add any observations, issues, or recommendations here]

EOF

echo "Summary report generated: ${RESULTS_DIR}/VALIDATION-SUMMARY.md"
```

---

## Automated Execution

For convenience, run all tests using the automated script:

```bash
cd terraform/test/scaletest

# Run all scale tests
./run-scaletest.sh --test all

# Or run individual tests
./run-scaletest.sh --test create-workspaces
./run-scaletest.sh --test dashboard
./run-scaletest.sh --test workspace-traffic

# Dry run to preview commands
./run-scaletest.sh --test all --dry-run
```

## CI/CD Integration

For automated pre-production validation in CI/CD pipelines, see the GitHub Actions workflow example in `terraform/docs/scale-testing-guide.md`.

## References

- [Coder Scale Testing Utility](https://coder.com/docs/admin/infrastructure/scale-utility)
- [Scale Testing Guide](../../docs/scale-testing-guide.md)
- [Scale Test Configuration](./scaletest-config.yaml)
- [Scale Test Runner Script](./run-scaletest.sh)
