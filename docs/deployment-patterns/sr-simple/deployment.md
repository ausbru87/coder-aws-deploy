# SR-Simple Deployment Guide

**Status:** 🚧 Future (Planned for v2.0)

## Overview

This guide will walk you through deploying the SR-Simple pattern for development and testing environments.

**Deployment Time:** 30-45 minutes

## Prerequisites

See [Prerequisites](../../getting-started/prerequisites.md) for complete requirements.

**Key differences from SR-HA:**
- Single AWS availability zone required (vs 3 for SR-HA)
- Lower AWS quota requirements
- No time-based scaling configuration needed

## Quick Start

```bash
# 1. Clone repository
git clone https://github.com/coder/coder-aws-deployment.git
cd coder-aws-deployment

# 2. Copy pattern file
cp patterns/sr-simple.tfvars my-deployment.tfvars

# 3. Configure variables
vim my-deployment.tfvars
# Update: project_name, environment, aws_region, domain_name

# 4. Initialize Terraform
terraform init -backend-config=backend-config/dev.hcl

# 5. Deploy infrastructure
terraform apply -var-file=my-deployment.tfvars

# 6. Configure kubectl access
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region us-east-1

# 7. Verify deployment
kubectl get pods -n coder
```

## Deployment Phases

### Phase 1: Environment Preparation (5 min)

This phase is identical to SR-HA Phase 1. See [Day 0 Deployment](../../operations/day0-deployment.md#phase-1).

### Phase 2: Variable Configuration (10 min)

**Minimal required variables for SR-Simple:**

```hcl
# my-deployment.tfvars
project_name = "coder"
environment  = "dev"
aws_region   = "us-east-1"

# Feature flags (all false for SR-Simple)
deployment_features = {
  high_availability      = false
  time_based_scaling     = false
  multi_region           = false
  pubsec_compliance      = false
  agent_ready_workspaces = false
}

# Single AZ configuration
availability_zone_count = 1
availability_zones = ["us-east-1a"]

# Minimal capacity
coderd_replicas = 1
max_workspaces  = 100

# DNS configuration
domain_name    = "coder-dev.example.com"
route53_zone_id = "Z1234567890ABC"

# Coder license
coder_license = "your-dev-license-key"
```

### Phase 3: Infrastructure Deployment (15-20 min)

```bash
# Plan deployment
terraform plan -var-file=my-deployment.tfvars -out=tfplan

# Review plan (should show ~50-60 resources)
terraform show tfplan

# Apply
terraform apply tfplan
```

**Expected resources:**
- VPC with 5 subnets (1 per tier)
- Single NAT Gateway
- EKS cluster (1.31)
- 3 node groups (control, workspace - no provisioner by default)
- Aurora Serverless v2 cluster (single-AZ)
- Network Load Balancer
- CloudWatch log groups
- IAM roles and policies

### Phase 4: Kubernetes Access (2 min)

Identical to SR-HA Phase 4. See [Day 0 Deployment](../../operations/day0-deployment.md#phase-4).

### Phase 5: Verification (5 min)

```bash
# 1. Check infrastructure
terraform output

# 2. Verify node readiness
kubectl get nodes
# Expected: 1 control node, 2 workspace nodes

# 3. Check Coder pods
kubectl get pods -n coder
# Expected: 1 coder-server pod, 0 coder-provisioner pods initially

# 4. Test Coder API
curl -k https://$(terraform output -raw coder_url)/healthz
# Expected: {"healthy":true}
```

## Post-Deployment Configuration

See [Day 1 Configuration](../../operations/day1-configuration.md) for:
- First admin user creation
- OIDC authentication setup
- Workspace template deployment
- User onboarding

## Scaling Considerations

**Manual scaling for SR-Simple:**

```bash
# Scale workspace nodes
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name <workspace-asg-name> \
  --desired-capacity 5

# Add provisioner nodes if needed
kubectl scale deployment coder-provisioner-default -n coder --replicas=2
```

**When to migrate to SR-HA:**
- Concurrent users exceed 50
- Workspace count exceeds 80
- Provisioning time P95 > 3 minutes
- Business requires >95% uptime SLA

## Cost Optimization

**Ways to reduce costs further:**

```hcl
# Lower Aurora min capacity
aurora_min_capacity = 0.5  # Can go lower if available in region

# Use smaller workspace nodes
workspace_instance_type = "m5.large"  # 2 vCPU, 8 GB RAM

# Reduce workspace node count
workspace_node_min = 1
workspace_node_desired = 1

# Disable VPC endpoints (use NAT Gateway)
enable_vpc_endpoints = false
```

**Scheduled shutdown for nights/weekends:**

Create a Lambda function to stop/start EKS node groups:

```python
# Future: Add Lambda function example for scheduled stop/start
```

## Troubleshooting

**Common SR-Simple issues:**

1. **Single AZ capacity limits:**
   ```bash
   # Check AZ capacity
   aws ec2 describe-instance-type-offerings \
     --location-type availability-zone \
     --filters Name=instance-type,Values=m5.large \
     --region us-east-1
   ```

2. **NAT Gateway single point of failure:**
   - Monitor NAT Gateway health: `aws ec2 describe-nat-gateways`
   - Have manual failover plan documented

3. **Aurora scaling limits:**
   - Monitor ACU usage: CloudWatch `ServerlessDatabaseCapacity`
   - If frequently hitting 4 ACU max, migrate to SR-HA

## Related Documentation

- [SR-Simple Overview](./overview.md)
- [When to Use SR-Simple](./when-to-use.md)
- [SR-HA Migration Guide](../sr-ha/overview.md#migration-from-sr-simple)
- [Day 1 Configuration](../../operations/day1-configuration.md)
