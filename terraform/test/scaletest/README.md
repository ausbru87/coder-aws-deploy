# Coder Scale Testing

This directory contains configuration and scripts for running Coder's built-in scale testing utilities to validate capacity and performance requirements.

## Overview

The scale tests validate the following requirements:

| Requirement | Description | Target |
|-------------|-------------|--------|
| 14.6 | Pod workspace provisioning time | < 2 minutes (P95) |
| 14.7 | EC2 workspace provisioning time | < 5 minutes (P95) |
| 14.9 | API response time (P95) | < 500ms |
| 14.10 | API response time (P99) | < 1 second |
| 14.11 | Concurrent provisioning capacity | 1000 workspaces |

## Prerequisites

1. **Coder CLI**: Install from https://coder.com/docs/install
2. **Coder Access**: Valid API token with admin permissions
3. **Templates**: Required templates deployed (pod-swdev, ec2-datasci)
4. **Quota**: Sufficient workspace quota (minimum 1100 workspaces)

## Configuration

### Environment Variables

```bash
export CODER_URL="https://coder.example.com"
export CODER_SESSION_TOKEN="your-api-token"
```

### Configuration File

The `scaletest-config.yaml` file contains all test parameters:

- **create_workspaces**: Workspace provisioning test settings
- **dashboard**: API latency test settings
- **workspace_traffic**: Network throughput test settings

## Usage

### Run All Tests

```bash
./run-scaletest.sh --test all
```

### Run Individual Tests

```bash
# Workspace creation test (validates 14.6, 14.7, 14.11)
./run-scaletest.sh --test create-workspaces

# API latency test (validates 14.9, 14.10)
./run-scaletest.sh --test dashboard

# Network throughput test
./run-scaletest.sh --test workspace-traffic
```

### Dry Run

Preview commands without executing:

```bash
./run-scaletest.sh --test all --dry-run
```

### Skip Cleanup

Keep workspaces after test for debugging:

```bash
./run-scaletest.sh --test create-workspaces --no-cleanup
```

## Test Details

### 1. Workspace Creation Test (`create-workspaces`)

Tests concurrent workspace provisioning capacity:

- **Pod workspaces**: 700 workspaces, 100 concurrent, target P95 < 2 min
- **EC2 workspaces**: 300 workspaces, 50 concurrent, target P95 < 5 min

```bash
# Equivalent coder CLI commands:
coder scaletest create-workspaces --count 700 --template pod-swdev --concurrency 100 --timeout 5m --cleanup
coder scaletest create-workspaces --count 300 --template ec2-datasci --concurrency 50 --timeout 10m --cleanup
```

### 2. Dashboard Test (`dashboard`)

Tests API latency under load:

- **Concurrency**: 50 simulated users
- **Duration**: 5 minutes
- **Targets**: P95 < 500ms, P99 < 1s

```bash
# Equivalent coder CLI command:
coder scaletest dashboard --concurrency 50 --duration 5m
```

### 3. Workspace Traffic Test (`workspace-traffic`)

Tests network throughput and connection stability:

- **Traffic**: 1024 bytes per tick
- **Interval**: 100ms between ticks
- **Duration**: 10 minutes

```bash
# Equivalent coder CLI command:
coder scaletest workspace-traffic --bytes-per-tick 1024 --tick-interval 100ms --duration 10m
```

## Results

Test results are saved to `./scaletest-results/<timestamp>/`:

| File | Description |
|------|-------------|
| `pod-workspaces.json` | Pod workspace provisioning results |
| `ec2-workspaces.json` | EC2 workspace provisioning results |
| `dashboard-results.json` | API latency test results |
| `workspace-traffic-results.json` | Network throughput results |
| `summary-report.md` | Human-readable summary |

## Performance Acceptance Criteria

### Pass Criteria

| Metric | Target | Pass Condition |
|--------|--------|----------------|
| Pod provisioning P95 | < 2 min | 95% of pods ready in < 120s |
| EC2 provisioning P95 | < 5 min | 95% of EC2 instances ready in < 300s |
| API P95 latency | < 500ms | 95% of requests complete in < 500ms |
| API P99 latency | < 1s | 99% of requests complete in < 1000ms |
| Error rate | < 1% | Less than 1% of operations fail |

### Fail Conditions

- Any metric exceeds 2x the target value
- Error rate exceeds 5%
- Test cannot complete due to infrastructure issues

## Troubleshooting

### Common Issues

1. **Insufficient quota**: Increase workspace quota in Coder admin settings
2. **Template not found**: Ensure templates are deployed and accessible
3. **API timeout**: Check Coder server health and network connectivity
4. **Node scaling delays**: Verify EKS node group autoscaling configuration

### Debug Mode

Enable verbose logging:

```bash
./run-scaletest.sh --test all --verbose
```

## Integration with CI/CD

For automated scale testing in CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run Scale Tests
  env:
    CODER_URL: ${{ secrets.CODER_URL }}
    CODER_SESSION_TOKEN: ${{ secrets.CODER_TOKEN }}
  run: |
    cd terraform/test/scaletest
    ./run-scaletest.sh --test all
```

## Pre-Production Validation

For formal pre-production validation before production deployment:

```bash
# Execute full pre-production validation suite
./scripts/execute-pre-production-validation.sh

# Validate results against acceptance criteria
./scripts/validate-results.sh ./scaletest-results/<timestamp>
```

See [Pre-Production Validation Runbook](./PRE-PRODUCTION-VALIDATION.md) for detailed execution procedures.

## References

- [Coder Scale Testing Utility](https://coder.com/docs/admin/infrastructure/scale-utility)
- [Coder Validated Architectures](https://coder.com/docs/admin/infrastructure/validated-architectures)
- [Performance Tuning Guide](https://coder.com/docs/admin/infrastructure/scale-testing)
- [Pre-Production Validation Runbook](./PRE-PRODUCTION-VALIDATION.md)
- [Scale Testing Guide](../../docs/scale-testing-guide.md)
