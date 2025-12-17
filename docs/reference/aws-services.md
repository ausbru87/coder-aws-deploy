# AWS Services Used

This document lists all AWS services used in Coder deployments, organized by category.

## Core Services (All Patterns)

### Compute

- **Amazon EKS (Elastic Kubernetes Service)**
  - Version: 1.31
  - Control plane hosting for coderd and provisioners
  - Managed Kubernetes control plane (multi-AZ)
  - Usage: SR-HA uses 3 node groups (control, provisioner, workspace)

- **Amazon EC2 (Elastic Compute Cloud)**
  - EKS worker nodes
  - Instance types: m5.large (control), c5.2xlarge (provisioner), m5.2xlarge (workspace)
  - SR-HA: Spot instances for workspace nodes, on-demand for control/provisioner

### Database

- **Amazon Aurora PostgreSQL Serverless v2**
  - Version: 16.4
  - Capacity: 0.5-16 ACU (1-32 GB RAM)
  - Coder backend database
  - Multi-AZ for SR-HA, single-AZ for SR-Simple

### Networking

- **Amazon VPC (Virtual Private Cloud)**
  - CIDR: 10.0.0.0/16 (65,536 IPs)
  - 5 subnet tiers: public, control, provisioner, workspace, database
  - SR-HA: 3 subnets per tier × 5 tiers = 15 subnets total

- **NAT Gateway**
  - Provides internet egress for private subnets
  - SR-HA: 1 per AZ (3 total), SR-Simple: 1 total
  - 5 Gbps burst, 45 Gbps sustained capacity

- **Elastic Load Balancing (Network Load Balancer)**
  - TLS termination with ACM certificate
  - Cross-zone load balancing enabled
  - Health checks on `/healthz` endpoint

- **Amazon Route 53**
  - DNS management
  - Health checks for failover (multi-region pattern)
  - Geolocation routing (multi-region pattern)

### Security & Identity

- **AWS IAM (Identity and Access Management)**
  - IRSA (IAM Roles for Service Accounts) for EKS pods
  - Instance profiles for EC2 nodes
  - Service-linked roles for EKS, RDS, AutoScaling

- **AWS Certificate Manager (ACM)**
  - TLS certificates for load balancer
  - Automatic renewal

- **AWS KMS (Key Management Service)**
  - Encryption keys for EBS volumes, Aurora, S3
  - PubSec pattern: Customer-managed keys (CMK) with rotation

### Storage

- **Amazon EBS (Elastic Block Store)**
  - Persistent volumes for workspace data
  - gp3 volumes (default)
  - Encrypted at rest

- **Amazon S3 (Simple Storage Service)**
  - PubSec pattern: Audit log storage
  - Template storage (optional)
  - Backup storage (optional)

### Observability

- **Amazon CloudWatch**
  - Logs: EKS control plane, application logs, VPC flow logs
  - Metrics: Infrastructure metrics, custom application metrics
  - Alarms: API latency, provisioning time, resource utilization

- **AWS CloudTrail**
  - API call logging
  - PubSec pattern: Data events for S3, log file validation

## Additional Services (Specific Patterns)

### SR-HA Pattern

- **AWS Auto Scaling**
  - Scheduled actions for time-based scaling
  - Scale up: 06:45 ET, scale down: 18:15 ET

- **Amazon CloudWatch Container Insights**
  - Enhanced EKS monitoring (when `enable_container_insights = true`)
  - Pod-level and node-level metrics

- **AWS Backup** (Optional)
  - Automated Aurora snapshot management
  - Cross-region backup replication (multi-region pattern)

### Multi-Region Pattern (Future)

- **Aurora Global Database**
  - Cross-region replication (<1 second lag)
  - Automatic failover

- **AWS Transit Gateway** (Optional)
  - Cross-region VPC connectivity
  - Alternative to VPC peering

- **Amazon Route 53 Health Checks**
  - Regional endpoint monitoring
  - Automatic DNS failover

### PubSec Pattern (Future)

- **AWS Config**
  - Continuous compliance monitoring
  - 50+ rules for CIS AWS Foundations Benchmark

- **Amazon GuardDuty**
  - Threat detection
  - Anomalous behavior monitoring

- **AWS Security Hub**
  - Centralized security findings
  - Aggregates findings from GuardDuty, Config, Inspector

- **Amazon Inspector**
  - Vulnerability scanning for EC2 and container images

- **Amazon Macie**
  - Sensitive data discovery and classification

- **VPC Endpoints (AWS PrivateLink)**
  - Required for all AWS API calls (no NAT Gateway)
  - Endpoints: ec2, ecr, s3, logs, sts, kms, rds, etc.

- **AWS Secrets Manager** (Optional)
  - Secrets storage with automatic rotation
  - Alternative to Kubernetes secrets

## Service Quotas

Key service quotas to check before deployment:

| Service | Quota Name | SR-HA Default | SR-HA Required |
|---------|------------|---------------|----------------|
| EC2 | Running On-Demand m5 instances | 20 | 55 |
| EC2 | Running Spot m5 instances | 20 | 200 |
| VPC | VPCs per Region | 5 | 1 |
| VPC | Internet Gateways per Region | 5 | 1 |
| VPC | NAT Gateways per AZ | 5 | 3 |
| EKS | Clusters per Region | 100 | 1 |
| RDS | Aurora Serverless v2 capacity (ACU) | 128 | 16 |
| Route 53 | Hosted zones per account | 500 | 1 |

**Check quotas:**
```bash
# List EC2 quotas
aws service-quotas list-service-quotas \
  --service-code ec2 \
  --query 'Quotas[?contains(QuotaName, `Running On-Demand`)]'

# Request quota increase
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --desired-value 55
```

## Cost Breakdown by Service

**SR-HA Monthly Costs (Estimated):**

| Service | Cost | Percentage |
|---------|------|------------|
| EC2 (EKS nodes) | $1,200-2,000 | 40-50% |
| Aurora Serverless v2 | $400-800 | 15-20% |
| NAT Gateway | $150-300 | 5-10% |
| Data Transfer | $150-200 | 5-8% |
| EKS Control Plane | $150 | 5% |
| Load Balancer | $100 | 3-4% |
| EBS Volumes | $50-100 | 2-3% |
| CloudWatch | $50-100 | 2-3% |
| Other (Route 53, KMS, etc.) | $50 | 2% |
| **Total** | **$2,500-4,000** | **100%** |

## IAM Permissions Required

Minimum IAM permissions for Terraform deployment:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "eks:*",
        "rds:*",
        "elasticloadbalancing:*",
        "route53:*",
        "acm:*",
        "iam:*",
        "kms:*",
        "logs:*",
        "cloudwatch:*",
        "autoscaling:*",
        "s3:*"
      ],
      "Resource": "*"
    }
  ]
}
```

**Note:** This is overly permissive. For production, use least-privilege IAM policies scoped to specific resources.

## Related Documentation

- [Prerequisites](../getting-started/prerequisites.md)
- [Cost Estimation](./cost-estimation.md)
- [Architecture Overview](../getting-started/overview.md)
- [AWS Quota Validation](../modules/quota-validation) (in Terraform modules)
