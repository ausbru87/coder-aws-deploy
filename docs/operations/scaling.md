# Scaling and Performance Testing Guide

This guide documents procedures for validating Coder platform performance and scaling capacity using Coder's built-in scale testing utilities.

## Overview

Scale testing validates that the Coder deployment meets performance requirements before production use. The tests use `coder scaletest` commands to simulate load and measure response times.

**Requirements Validated:**
- **14.6**: Pod workspace provisioning < 2 minutes
- **14.7**: EC2 workspace provisioning < 5 minutes
- **14.9**: P95 API response time < 500ms
- **14.10**: P99 API response time < 1 second
- **14.11**: Support 1000 simultaneous workspace provisioning operations

For performance targets specific to the SR-HA pattern, see [SR-HA Capacity Planning](../deployment-patterns/sr-ha/capacity-planning.md).

## Prerequisites

1. Coder CLI installed and authenticated
2. Access to a Coder deployment with admin privileges
3. Sufficient infrastructure capacity (nodes, quotas)
4. Scale test configuration file (`terraform/test/scaletest/scaletest-config.yaml`)
5. Required templates deployed (pod-swdev, ec2-datasci)
6. Minimum workspace quota of 1100 workspaces

### Environment Setup

```bash
# Set Coder URL
export CODER_URL=https://coder.example.com

# Authenticate with Coder
coder login $CODER_URL

# Set session token for automated scripts
export CODER_SESSION_TOKEN=$(coder tokens create --lifetime 24h -q)

# Verify authentication
coder whoami
```

## Quick Start: Automated Scale Testing

The recommended approach is to use the automated scale test runner:

```bash
cd terraform/test/scaletest

# Run all scale tests
./run-scaletest.sh --test all

# Run individual tests
./run-scaletest.sh --test create-workspaces  # Workspace provisioning
./run-scaletest.sh --test dashboard          # API latency
./run-scaletest.sh --test workspace-traffic  # Network throughput

# Dry run to preview commands
./run-scaletest.sh --test all --dry-run
```

Results are saved to `terraform/test/scaletest/scaletest-results/<timestamp>/`.

## Scale Test Commands (Manual)

### 1. Workspace Creation Test

Validates concurrent workspace provisioning capacity (Req 14.11) and provisioning times (Req 14.6, 14.7).

```bash
# Run workspace creation scale test with 1000 workspaces
coder scaletest create-workspaces \
  --count 1000 \
  --template pod-swdev \
  --concurrency 100 \
  --timeout 30m \
  --cleanup \
  --output json \
  --output-file workspace-creation-results.json
```

**Parameters:**
- `--count`: Number of workspaces to create (target: 1000)
- `--template`: Template to use for workspace creation
- `--concurrency`: Number of concurrent operations (recommended: 100)
- `--timeout`: Maximum test duration
- `--cleanup`: Remove workspaces after test completion
- `--output`: Output format (json recommended for analysis)

**Expected Results:**
- All 1000 workspaces created successfully
- P95 provisioning time < 2 minutes (pod) or < 5 minutes (EC2)
- Success rate > 99%

### 2. Dashboard Load Test

Validates API latency under load (Req 14.9, 14.10).

```bash
# Run dashboard load test
coder scaletest dashboard \
  --concurrency 50 \
  --duration 5m \
  --output json \
  --output-file dashboard-results.json
```

**Parameters:**
- `--concurrency`: Number of simulated concurrent users
- `--duration`: Test duration
- `--output`: Output format

**Expected Results:**
- P95 response time < 500ms
- P99 response time < 1 second
- No errors or timeouts

### 3. Workspace Traffic Test

Validates network throughput and workspace connectivity.

```bash
# Run workspace traffic test
coder scaletest workspace-traffic \
  --bytes-per-tick 1024 \
  --tick-interval 100ms \
  --duration 10m \
  --output json \
  --output-file traffic-results.json
```

**Parameters:**
- `--bytes-per-tick`: Data volume per interval
- `--tick-interval`: Interval between data transmissions
- `--duration`: Test duration

**Expected Results:**
- Consistent throughput throughout test
- No connection drops or timeouts
- Latency within acceptable bounds

## Pre-Production Validation Runbook

### Phase 1: Infrastructure Readiness

1. **Verify Node Capacity**
   ```bash
   kubectl get nodes -l coder.com/node-type=workspace
   kubectl describe nodes | grep -A 5 "Allocatable"
   ```

2. **Check AWS Quotas**
   ```bash
   # Run quota validation
   cd terraform/modules/quota-validation
   ./scripts/check-quotas.sh
   ```

3. **Verify Database Capacity**
   ```bash
   # Check Aurora metrics in CloudWatch
   aws cloudwatch get-metric-statistics \
     --namespace AWS/RDS \
     --metric-name CPUUtilization \
     --dimensions Name=DBClusterIdentifier,Value=coder-aurora \
     --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
     --period 300 \
     --statistics Average
   ```

### Phase 2: Baseline Performance

1. **Single Workspace Test**
   ```bash
   # Create single workspace and measure time
   time coder create test-workspace --template pod-swdev --yes
   coder delete test-workspace --yes
   ```

2. **Small Scale Test (10 workspaces)**
   ```bash
   coder scaletest create-workspaces \
     --count 10 \
     --template pod-swdev \
     --concurrency 10 \
     --cleanup \
     --output json
   ```

3. **API Latency Baseline**
   ```bash
   coder scaletest dashboard \
     --concurrency 5 \
     --duration 1m \
     --output json
   ```

### Phase 3: Full Scale Validation

1. **Workspace Creation at Scale**
   ```bash
   # Pod-based workspaces
   coder scaletest create-workspaces \
     --count 1000 \
     --template pod-swdev \
     --concurrency 100 \
     --timeout 30m \
     --cleanup \
     --output json \
     --output-file pod-scale-results.json

   # EC2-based workspaces (smaller count due to longer provisioning)
   coder scaletest create-workspaces \
     --count 100 \
     --template ec2-datasci \
     --concurrency 25 \
     --timeout 45m \
     --cleanup \
     --output json \
     --output-file ec2-scale-results.json
   ```

2. **API Load Test**
   ```bash
   coder scaletest dashboard \
     --concurrency 50 \
     --duration 5m \
     --output json \
     --output-file api-load-results.json
   ```

3. **Network Throughput Test**
   ```bash
   coder scaletest workspace-traffic \
     --bytes-per-tick 1024 \
     --tick-interval 100ms \
     --duration 10m \
     --output json \
     --output-file traffic-results.json
   ```

### Phase 4: Results Analysis

1. **Parse Results**
   ```bash
   # Extract P95 provisioning time
   jq '.provisioning.p95_seconds' pod-scale-results.json

   # Extract API latency percentiles
   jq '.latency | {p50: .p50_ms, p95: .p95_ms, p99: .p99_ms}' api-load-results.json

   # Check success rate
   jq '.success_rate' pod-scale-results.json
   ```

2. **Validate Against Criteria**
   ```bash
   # Check if results meet acceptance criteria
   POD_P95=$(jq '.provisioning.p95_seconds' pod-scale-results.json)
   API_P95=$(jq '.latency.p95_ms' api-load-results.json)
   API_P99=$(jq '.latency.p99_ms' api-load-results.json)

   echo "Pod P95: ${POD_P95}s (target: <120s)"
   echo "API P95: ${API_P95}ms (target: <500ms)"
   echo "API P99: ${API_P99}ms (target: <1000ms)"
   ```

3. **Generate Report**
   ```bash
   # Combine results into summary report
   cat > scale-test-report.json << EOF
   {
     "test_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
     "environment": "$CODER_URL",
     "results": {
       "workspace_creation": $(cat pod-scale-results.json),
       "api_latency": $(cat api-load-results.json),
       "network_traffic": $(cat traffic-results.json)
     },
     "pass": true
   }
   EOF
   ```

## Monitoring During Tests

### CloudWatch Metrics to Monitor

| Metric | Namespace | Threshold |
|--------|-----------|-----------|
| CPUUtilization | AWS/EKS | < 80% |
| MemoryUtilization | ContainerInsights | < 80% |
| DatabaseConnections | AWS/RDS | < max_connections |
| NetworkIn/Out | AWS/EC2 | No drops |
| TargetResponseTime | AWS/ApplicationELB | < 1s |

### CloudWatch Dashboard Query

```sql
-- API Latency during scale test
SELECT AVG(latency) as avg_latency,
       PERCENTILE(latency, 95) as p95_latency,
       PERCENTILE(latency, 99) as p99_latency
FROM coder_api_metrics
WHERE timestamp BETWEEN start_time AND end_time
```

### Alerts to Watch

- `coder-api-latency-high`: P95 > 500ms
- `coder-provisioning-slow`: Provisioning > 5 min
- `coder-error-rate-high`: Error rate > 1%
- `eks-node-pressure`: Node CPU/Memory > 80%

## Post-Test Cleanup

```bash
# Remove any remaining test workspaces
coder list --all | grep scaletest | awk '{print $1}' | xargs -I {} coder delete {} --yes

# Verify cleanup
coder list --all | grep scaletest
```

## Scale Test Configuration

The scale test configuration file (`terraform/test/scaletest/scaletest-config.yaml`) defines all test parameters:

```yaml
# Key configuration sections:

# Workspace creation test settings
create_workspaces:
  count: 1000                    # Total workspaces to create
  templates:
    pod_workspaces:
      template: "pod-swdev"
      count: 700                 # 700 pod-based workspaces
      concurrency: 100           # 100 concurrent operations
      expected_p95: "2m"         # Target: < 2 minutes
    ec2_workspaces:
      template: "ec2-datasci"
      count: 300                 # 300 EC2-based workspaces
      concurrency: 50            # 50 concurrent operations
      expected_p95: "5m"         # Target: < 5 minutes

# API latency test settings
dashboard:
  concurrency: 50                # 50 simulated users
  duration: "5m"                 # 5 minute test duration
  targets:
    p95_latency_ms: 500          # Target: < 500ms
    p99_latency_ms: 1000         # Target: < 1 second

# Network throughput test settings
workspace_traffic:
  bytes_per_tick: 1024           # 1KB per tick
  tick_interval: "100ms"         # 100ms between ticks
  duration: "10m"                # 10 minute test duration
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Scale Test Validation

on:
  workflow_dispatch:
  schedule:
    - cron: '0 6 * * 1'  # Weekly Monday 6 AM UTC

jobs:
  scale-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Coder CLI
        run: |
          curl -fsSL https://coder.com/install.sh | sh

      - name: Run Scale Tests
        env:
          CODER_URL: ${{ secrets.CODER_URL }}
          CODER_SESSION_TOKEN: ${{ secrets.CODER_TOKEN }}
        run: |
          cd terraform/test/scaletest
          ./run-scaletest.sh --test all

      - name: Upload Results
        uses: actions/upload-artifact@v4
        with:
          name: scale-test-results
          path: terraform/test/scaletest/scaletest-results/

      - name: Validate Results
        run: |
          # Check if tests passed acceptance criteria
          RESULTS_DIR=$(ls -td terraform/test/scaletest/scaletest-results/*/ | head -1)

          # Validate pod provisioning P95 < 2 minutes
          POD_P95=$(jq -r '.provisioning_time_p95_ms // 0' "${RESULTS_DIR}/pod-workspaces.json")
          if [ "$POD_P95" -gt 120000 ]; then
            echo "FAIL: Pod P95 (${POD_P95}ms) exceeds 2 minute target"
            exit 1
          fi

          # Validate API P95 < 500ms
          API_P95=$(jq -r '.latency_p95_ms // 0' "${RESULTS_DIR}/dashboard-results.json")
          if [ "$API_P95" -gt 500 ]; then
            echo "FAIL: API P95 (${API_P95}ms) exceeds 500ms target"
            exit 1
          fi

          echo "All scale tests passed acceptance criteria"
```

## Scheduled Scale Testing

For production environments, schedule regular scale tests to detect performance regressions:

| Frequency | Test Type | Purpose |
|-----------|-----------|---------|
| Weekly | Full scale test | Validate capacity after changes |
| Monthly | Extended duration | Detect memory leaks, resource exhaustion |
| After upgrades | Full scale test | Validate performance after Coder/K8s upgrades |
| After scaling | Targeted test | Validate new capacity limits |

## Pre-Production Validation

For formal pre-production validation before production deployment, use the comprehensive validation runbook:

```bash
cd terraform/test/scaletest

# Execute full pre-production validation suite
./scripts/execute-pre-production-validation.sh

# Or run individual tests with the main runner
./run-scaletest.sh --test create-workspaces  # Task 33.1
./run-scaletest.sh --test dashboard          # Task 33.2
./run-scaletest.sh --test workspace-traffic  # Task 33.3

# Validate results against acceptance criteria
./scripts/validate-results.sh ./scaletest-results/<timestamp>
```

See [Pre-Production Validation Runbook](../test/scaletest/PRE-PRODUCTION-VALIDATION.md) for detailed execution procedures.

## Related Documentation

- [SR-HA Capacity Planning](../deployment-patterns/sr-ha/capacity-planning.md) - Performance targets and sizing
- [Troubleshooting Guide](./troubleshooting.md) - Common scale testing issues
- [Day 2 Operations](./day2-operations.md) - Ongoing scaling and monitoring
- [Coder Scale Testing Utility](https://coder.com/docs/admin/infrastructure/scale-utility)
- [Coder Validated Architectures](https://coder.com/docs/admin/infrastructure/validated-architectures)
