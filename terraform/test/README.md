# Terraform Tests

This directory contains tests for the Coder deployment Terraform modules using Terratest.

## Prerequisites

- Go 1.24+
- Terraform 1.5+
- AWS credentials configured (for integration tests)

## Test Types

### Unit Tests (`terraform_test.go`)

Validates Terraform module syntax and configuration without deploying resources:

```bash
go test -v -run TestTerraformValidate
```

### Property-Based Tests (`property_test.go`)

Validates correctness properties defined in the design document:

| Test | Property | Requirements |
|------|----------|--------------|
| TestProperty_InfrastructureProvisioningCompleteness | Property 1 | 2.1, 2.2, 2.3, 2.4 |
| TestProperty_StaticControlPlaneConfiguration | Property 4 | 4.1 |
| TestProperty_BackupFrequencyRPO | Property 5 | 8.4 |
| TestProperty_ExternalProvisionerConfiguration | Property 6 | 11.1 |
| TestProperty_HTTPSEnforcement | Property 8 | 12.7, 12.8 |
| TestProperty_DeclarativeConfigurationConsistency | Property 11 | 16.3 |
| TestProperty_DNSConfigurationCompleteness | Property 12 | 6.4 |

## Running Tests

### Run All Tests

```bash
cd terraform/test
go mod tidy
go test -v ./...
```

### Run Specific Test

```bash
go test -v -run TestProperty_HTTPSEnforcement
```

### Run with Coverage

```bash
go test -v -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

## Test Configuration

Tests use mock values for AWS resources. For integration tests that deploy real infrastructure, set the following environment variables:

```bash
export AWS_REGION=us-east-1
export TF_VAR_base_domain=example.com
export TF_VAR_acm_certificate_arn=arn:aws:acm:...
```

### Scale Tests (`scaletest/`)

Validates performance and capacity requirements using Coder's built-in scale testing utilities:

| Test | Command | Requirements |
|------|---------|--------------|
| Workspace Creation | `coder scaletest create-workspaces` | 14.6, 14.7, 14.11 |
| API Latency | `coder scaletest dashboard` | 14.9, 14.10 |
| Network Throughput | `coder scaletest workspace-traffic` | - |

**Running Scale Tests:**

```bash
cd terraform/test/scaletest

# Set environment variables
export CODER_URL=https://coder.example.com
export CODER_SESSION_TOKEN=your-api-token

# Run all scale tests
./run-scaletest.sh --test all

# Run specific test
./run-scaletest.sh --test dashboard
```

See [Scale Testing Guide](../docs/scale-testing-guide.md) for detailed procedures.

## Adding New Tests

1. Add test function to appropriate file
2. Include property annotation comment:
   ```go
   // **Feature: coder-deployment-guide, Property N: Property Name**
   // **Validates: Requirements X.Y**
   ```
3. Run tests to verify
