# AWS Service Quota Validation Module

This module provides documentation and automation for AWS service quota validation required for the Coder deployment.

## Overview

Before deploying the Coder platform, you must ensure your AWS account has sufficient service quotas to support the target capacity. This module:

1. Documents all required AWS service quotas
2. Provides automation to check current quotas vs required
3. Implements pre-flight validation to block deployment if quotas are insufficient

## Required Quotas

The following quotas are calculated based on maximum capacity of **3000 concurrent workspaces** plus infrastructure overhead.

### EC2 Service Quotas

| Quota Name | Service Code | Quota Code | Required Value | Description |
|------------|--------------|------------|----------------|-------------|
| Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances | ec2 | L-1216C47A | 1000 vCPUs | Control + Provisioner + Workspace nodes |
| Running On-Demand G and VT instances | ec2 | L-DB2E81BA | 256 vCPUs | GPU workspaces (g4dn, g5) |
| Running On-Demand P instances | ec2 | L-417A185B | 128 vCPUs | Large ML workspaces (p3, p4d) |
| All Standard Spot Instance Requests | ec2 | L-34B43A08 | 2000 vCPUs | Spot workspace nodes |
| EC2-VPC Elastic IPs | ec2 | L-0263D0A3 | 6 | NAT Gateways (3) + buffer |

### EBS Service Quotas

| Quota Name | Service Code | Quota Code | Required Value | Description |
|------------|--------------|------------|----------------|-------------|
| Storage for General Purpose SSD (gp3) volumes | ebs | L-7A658B76 | 500 TiB | Workspace persistent volumes |
| General Purpose SSD (gp3) volume IOPS | ebs | L-B3A130E6 | 500000 IOPS | Aggregate IOPS for workspaces |
| Provisioned IOPS SSD (io1) volumes | ebs | L-FD252861 | 50 TiB | High-performance workspaces |

### VPC Service Quotas

| Quota Name | Service Code | Quota Code | Required Value | Description |
|------------|--------------|------------|----------------|-------------|
| VPCs per Region | vpc | L-F678F1CE | 5 | VPC for Coder deployment |
| Subnets per VPC | vpc | L-407747CB | 50 | Multiple subnet tiers across AZs |
| NAT gateways per Availability Zone | vpc | L-FE5A380F | 5 | HA NAT configuration |
| Network interfaces per Region | vpc | L-DF5E4CA3 | 10000 | ENIs for pods and instances |
| Security groups per VPC | vpc | L-E79EC296 | 300 | Security group rules |
| Rules per security group | vpc | L-0EA8095F | 200 | Inbound/outbound rules |
| VPC security groups per elastic network interface | vpc | L-2AFB9258 | 10 | SGs per ENI |

### EKS Service Quotas

| Quota Name | Service Code | Quota Code | Required Value | Description |
|------------|--------------|------------|----------------|-------------|
| Clusters | eks | L-1194D53C | 10 | EKS clusters per region |
| Managed node groups per cluster | eks | L-6D54EA21 | 30 | Node groups for different workloads |
| Nodes per managed node group | eks | L-BD136A63 | 450 | Max nodes in workspace node group |

### RDS/Aurora Service Quotas

| Quota Name | Service Code | Quota Code | Required Value | Description |
|------------|--------------|------------|----------------|-------------|
| DB clusters | rds | L-952B80B8 | 40 | Aurora clusters |
| DB cluster parameter groups | rds | L-E094F43D | 50 | Parameter groups |
| Total storage for all DB instances | rds | L-7B6409FD | 100000 GiB | Aurora storage |

### Secrets Manager Quotas

| Quota Name | Service Code | Quota Code | Required Value | Description |
|------------|--------------|------------|----------------|-------------|
| Secrets | secretsmanager | L-F]2B2B2B2 | 500 | Secrets for credentials |

### Route 53 Quotas

| Quota Name | Service Code | Quota Code | Required Value | Description |
|------------|--------------|------------|----------------|-------------|
| Hosted zones | route53 | L-4EA4796A | 50 | DNS zones |
| Resource record sets per hosted zone | route53 | L-E209CC9F | 10000 | DNS records |

### CloudWatch Quotas

| Quota Name | Service Code | Quota Code | Required Value | Description |
|------------|--------------|------------|----------------|-------------|
| Number of metrics per dashboard | cloudwatch | L-59B7A4E4 | 2500 | Dashboard metrics |
| Number of dashboards | cloudwatch | L-59B7A4E5 | 500 | CloudWatch dashboards |

### ACM Quotas

| Quota Name | Service Code | Quota Code | Required Value | Description |
|------------|--------------|------------|----------------|-------------|
| ACM certificates | acm | L-F141DD1D | 2500 | TLS certificates |

## Quota Calculation Formula

The required quotas are calculated based on:

```
Max Workspaces = 3000
Workspaces per User = 3
Max Users = 1000

Control Nodes: 3 x m5.large = 6 vCPUs
Provisioner Nodes: 20 x c5.2xlarge = 160 vCPUs
Workspace Nodes: 200 x m5.2xlarge = 1600 vCPUs
EC2 Workspaces (GPU): ~50 instances = 400 vCPUs (GPU class)

Total On-Demand vCPUs: ~800 (with buffer)
Total Spot vCPUs: ~1600 (workspace nodes)

Storage per Workspace: 100GB average
Total Storage: 3000 x 100GB = 300 TiB
```

## Usage

### Check Current Quotas

```bash
cd terraform/modules/quota-validation
./scripts/check-quotas.sh
```

### Request Quota Increases

```bash
./scripts/request-quota-increases.sh
```

### Pre-flight Validation

The pre-flight validation is automatically run during `terraform plan` via the `null_resource` that checks quotas.

To run manually:

```bash
./scripts/preflight-check.sh
```

## Integration with Terraform

This module exports a `quota_validation_passed` output that can be used as a dependency for other modules:

```hcl
module "quota_validation" {
  source = "./modules/quota-validation"
  
  max_workspaces = var.max_workspaces
  aws_region     = var.aws_region
}

# Other modules depend on quota validation
module "vpc" {
  source = "./modules/vpc"
  
  depends_on = [module.quota_validation]
}
```

## Requirements

- AWS CLI v2 configured with appropriate permissions
- `jq` for JSON parsing
- Bash shell

### Required IAM Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "servicequotas:GetServiceQuota",
        "servicequotas:ListServiceQuotas",
        "servicequotas:RequestServiceQuotaIncrease",
        "servicequotas:GetRequestedServiceQuotaChange"
      ],
      "Resource": "*"
    }
  ]
}
```
