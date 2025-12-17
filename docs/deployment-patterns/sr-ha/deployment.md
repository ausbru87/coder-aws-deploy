# SR-HA Pattern Deployment Guide

This guide covers deployment specifics for the Single Region High Availability (SR-HA) pattern. This pattern deploys all Coder components within a single AWS region across 3 Availability Zones for high availability.

**Target Audience:** DevSecOps Engineers L1-5, SysAdmins L3-L6

**Estimated Deployment Time:** 30-45 minutes

## Table of Contents

1. [SR-HA Pattern Overview](#sr-ha-pattern-overview)
2. [Pattern Characteristics](#pattern-characteristics)
3. [Deployment Configuration](#deployment-configuration)
4. [Deployment Procedures](#deployment-procedures)
5. [Pattern-Specific Considerations](#pattern-specific-considerations)

## SR-HA Pattern Overview

The SR-HA pattern provides high availability within a single AWS region by distributing components across three Availability Zones. This pattern is ideal for:

- Organizations with users primarily in one geographic region
- Cost-optimized HA deployments
- Simplified operational complexity vs multi-region
- RTO/RPO requirements that can be met with single-region HA

### Architecture Characteristics

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                       SR-HA: Single Region (us-east-1)                               │
│                                                                                      │
│  ┌────────────────────────────────────────────────────────────────────────────────┐  │
│  │                         Multi-AZ Deployment (3 AZs)                            │  │
│  │                                                                                │  │
│  │    AZ-a (us-east-1a)    AZ-b (us-east-1b)    AZ-c (us-east-1c)               │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐               │  │
│  │  │ coderd (active) │  │ coderd (active) │  │ coderd (spare)  │               │  │
│  │  │ NAT Gateway     │  │ NAT Gateway     │  │ NAT Gateway     │               │  │
│  │  │ Aurora Writer   │  │ Aurora Reader   │  │ Aurora Reader   │               │  │
│  │  │ Provisioners    │  │ Provisioners    │  │ Provisioners    │               │  │
│  │  │ Workspaces      │  │ Workspaces      │  │ Workspaces      │               │  │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘               │  │
│  └────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│  Key Features:                                                                       │
│  - Single region deployment (us-east-1)                                             │
│  - 3 Availability Zones for HA                                                      │
│  - Time-based scaling (06:45-18:15 ET)                                             │
│  - Aurora multi-AZ with automatic failover                                         │
│  - Spot instances for cost optimization                                            │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Pattern Characteristics

### High Availability Features

| Component | HA Configuration | Failover Time |
|-----------|------------------|---------------|
| coderd | 2+ replicas across AZs | < 30 seconds |
| Aurora | Writer + 2 readers, auto-failover | < 2 minutes |
| NAT Gateway | 1 per AZ (3 total) | Automatic |
| Provisioners | Distributed across AZs | < 1 minute |
| Workspaces | Distributed across AZs | N/A (stateful) |

### Capacity and Scaling

| Metric | Configuration | Notes |
|--------|---------------|-------|
| Supported Users | Up to 3000 concurrent users | Based on workspace sizing |
| Max Workspaces | 3000 concurrent | Configurable per deployment |
| Node Scaling | Time-based (06:45-18:15 ET) | Business hours optimization |
| Spot Usage | Enabled for workspace nodes | 50-70% cost savings |
| Region | us-east-1 (configurable) | Single region deployment |

### Recovery Objectives

| Objective | Target | Implementation |
|-----------|--------|----------------|
| RTO | 2 hours maximum | Multi-AZ with auto-failover |
| RPO | 15 minutes maximum | Aurora continuous backup |
| Availability | 99.9% (three nines) | Multi-AZ architecture |
| Planned Maintenance | 90 min window | Rolling updates, zero downtime |

## Deployment Configuration

### Region-Specific Variables

The SR-HA pattern requires specific configuration for the target region and availability zones.

```hcl
# environments/prod.tfvars - SR-HA Configuration

# Region Configuration
aws_region         = "us-east-1"  # Primary region
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Deployment Pattern
deployment_pattern = "sr-ha"

# Network Configuration
vpc_cidr = "10.0.0.0/16"

# Subnet Configuration (3 AZs)
public_subnet_cidrs      = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
control_subnet_cidrs     = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]
provisioner_subnet_cidrs = ["10.0.96.0/20", "10.0.112.0/20", "10.0.128.0/20"]
workspace_subnet_cidrs   = ["10.0.144.0/18"]  # Large single block
database_subnet_cidrs    = ["10.0.208.0/21", "10.0.216.0/21", "10.0.224.0/21"]

# Time-Based Scaling Configuration
enable_time_based_scaling = true
scaling_timezone          = "America/New_York"  # ET
scaling_schedule_start    = "45 6 * * MON-FRI"   # 06:45 ET
scaling_schedule_stop     = "15 18 * * MON-FRI"  # 18:15 ET

# Node Group Sizing
control_node_min    = 2
control_node_max    = 3
control_node_desired = 2

provisioner_node_min     = 0
provisioner_node_max     = 20
provisioner_node_desired_min = 0    # Scaled down outside business hours
provisioner_node_desired_max = 6    # Scaled up during business hours

workspace_node_min     = 10
workspace_node_max     = 200
workspace_node_desired_min = 10   # Minimum capacity
workspace_node_desired_max = 100  # Business hours capacity

# Spot Instance Configuration
workspace_use_spot      = true
workspace_spot_max_price = ""  # Use on-demand as max price
workspace_on_demand_base = 10  # Always maintain 10 on-demand

# Aurora Configuration
aurora_min_capacity = 0.5  # ACU
aurora_max_capacity = 16   # ACU
aurora_instance_class = "db.serverless"
aurora_instances = 3  # 1 writer, 2 readers across AZs
```

### SR-HA Specific Features

The SR-HA pattern includes several optimizations:

1. **Time-Based Scaling**: Automatically scales provisioner and workspace nodes based on business hours
2. **Spot Instances**: Uses spot instances for workspace nodes with on-demand fallback
3. **Aurora Serverless v2**: Scales database capacity based on load
4. **Single Region**: Simplified networking and lower cross-region data transfer costs

## Deployment Procedures

The SR-HA pattern follows the standard deployment workflow with pattern-specific configuration.

### Step 1: Prerequisites

Ensure all prerequisites are met:
- Review [Prerequisites and Quota Requirements](../../getting-started/prerequisites.md)
- Confirm service quotas for target region
- Prepare ACM certificates for target region
- Configure OIDC provider

### Step 2: Configure SR-HA Variables

```bash
# Create SR-HA specific configuration
cp environments/prod.tfvars.example environments/sr-ha-prod.tfvars

# Edit with SR-HA specific values
vim environments/sr-ha-prod.tfvars

# Ensure deployment_pattern is set
deployment_pattern = "sr-ha"
```

### Step 3: Deploy Infrastructure

Follow the complete deployment procedure:

**Phase 1-5: Infrastructure Deployment**

See [Day 0: Infrastructure Deployment](../../operations/day0-deployment.md) for detailed steps:
1. Prepare deployment environment
2. Configure variables (use SR-HA tfvars)
3. Deploy infrastructure
4. Configure Kubernetes access
5. Verify Coder deployment

**Expected deployment time:** 30-45 minutes

### Step 4: Initial Configuration

Follow Day 1 procedures:

See [Day 1: Initial Configuration](../../operations/day1-configuration.md) for detailed steps:
1. Create owner account
2. Configure OIDC authentication
3. Deploy templates
4. Run smoke tests
5. Configure monitoring
6. Set up external integrations

**Expected configuration time:** 60-90 minutes

### Step 5: Verify SR-HA Specific Features

```bash
# Verify multi-AZ distribution
kubectl get nodes -o wide | grep -E 'us-east-1(a|b|c)'

# Verify Aurora cluster configuration
aws rds describe-db-clusters --db-cluster-identifier coder-prod-aurora \
  --query 'DBClusters[0].[MultiAZ,AvailabilityZones]'

# Verify NAT Gateways (one per AZ)
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=<vpc-id>" \
  --query 'NatGateways[*].[SubnetId,State]'

# Check time-based scaling configuration
kubectl get deployment -n coder-prov -o yaml | grep -A 5 "schedule"
```

## Pattern-Specific Considerations

### Time-Based Scaling

The SR-HA pattern uses time-based scaling to optimize costs during non-business hours.

**Business Hours (06:45-18:15 ET):**
- Provisioner nodes: Scale up to handle workspace provisioning load
- Workspace nodes: Scale to business hours capacity

**Non-Business Hours:**
- Provisioner nodes: Scale down to 0 (cost savings)
- Workspace nodes: Scale to minimum capacity
- Running workspaces maintain connectivity

**Adjusting Schedule:**
```bash
# Edit scaling schedule in tfvars
scaling_schedule_start = "0 7 * * MON-FRI"   # 07:00 ET
scaling_schedule_stop  = "0 19 * * MON-FRI"  # 19:00 ET

# Apply changes
terraform apply -var-file=environments/sr-ha-prod.tfvars
```

### Spot Instance Strategy

The SR-HA pattern uses spot instances for workspace nodes to reduce costs.

**Configuration:**
- Base on-demand capacity: 10 nodes (always available)
- Spot instances: Used for scaling beyond base
- Spot interruption handling: Graceful workspace migration

**Monitoring Spot Interruptions:**
```bash
# Check spot instance interruption notices
kubectl get events -n coder-ws --field-selector reason=SpotInterruption

# Check workspace migrations
kubectl logs -n coder-ws -l migration=true
```

### Aurora Serverless v2 Scaling

Aurora Serverless v2 automatically scales based on database load.

**Scaling Configuration:**
- Minimum: 0.5 ACU (cost-effective during low usage)
- Maximum: 16 ACU (handles peak load)
- Scaling: Automatic based on CPU/connections

**Monitoring Aurora Scaling:**
```bash
# Check current Aurora capacity
aws rds describe-db-clusters --db-cluster-identifier coder-prod-aurora \
  --query 'DBClusters[0].ServerlessV2ScalingConfiguration'

# View Aurora metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ServerlessDatabaseCapacity \
  --dimensions Name=DBClusterIdentifier,Value=coder-prod-aurora \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Multi-AZ Failover Testing

Test multi-AZ failover capabilities:

```bash
# Simulate AZ failure by cordoning nodes in one AZ
kubectl cordon $(kubectl get nodes -l topology.kubernetes.io/zone=us-east-1a -o name)

# Verify pods reschedule to other AZs
kubectl get pods -n coder -o wide

# Test Aurora failover
aws rds failover-db-cluster --db-cluster-identifier coder-prod-aurora

# Monitor failover completion
aws rds describe-db-clusters --db-cluster-identifier coder-prod-aurora \
  --query 'DBClusters[0].Status'

# Restore nodes after testing
kubectl uncordon $(kubectl get nodes -l topology.kubernetes.io/zone=us-east-1a -o name)
```

## Cost Optimization

The SR-HA pattern includes several cost optimization features:

### Cost Breakdown

| Component | Cost Driver | Optimization |
|-----------|-------------|--------------|
| EKS Nodes | Compute hours | Time-based scaling, spot instances |
| Aurora | Capacity hours | Serverless v2 auto-scaling |
| NAT Gateway | Data transfer | 3 gateways (HA requirement) |
| EBS Volumes | Storage GB | Right-sized workspace volumes |
| Load Balancer | NLB hours | Single NLB (multi-AZ) |

### Optimization Strategies

1. **Aggressive Scaling**: Scale down during non-business hours
2. **Spot Instances**: 50-70% savings on workspace nodes
3. **Aurora Serverless**: Pay only for capacity used
4. **Right-Sizing**: Start with conservative capacity, scale up as needed

## Operational Considerations

### Backup and Recovery

See [Day 2: Ongoing Operations](../../operations/day2-operations.md) for:
- Platform restore procedures
- Monthly backup testing
- Point-in-time recovery

### Maintenance and Upgrades

See [Upgrade Procedures](../../operations/upgrades.md) for:
- Coder version upgrades
- EKS cluster upgrades
- Template upgrades

### Monitoring and Alerting

CloudWatch dashboards and alarms are pre-configured:
- EKS node health and capacity
- Aurora performance metrics
- Coder API latency and error rates
- NAT Gateway metrics

## Related Documentation

### Getting Started
- [Architecture Overview](../../getting-started/overview.md)
- [Prerequisites and Quota Requirements](../../getting-started/prerequisites.md)

### Operations Guides
- [Day 0: Infrastructure Deployment](../../operations/day0-deployment.md)
- [Day 1: Initial Configuration](../../operations/day1-configuration.md)
- [Day 2: Ongoing Operations](../../operations/day2-operations.md)
- [Upgrade Procedures](../../operations/upgrades.md)
- [Troubleshooting Guide](../../operations/troubleshooting.md)

### External Resources
- [AWS Multi-AZ Deployments](https://docs.aws.amazon.com/whitepapers/latest/real-time-communication-on-aws/high-availability-and-scalability-on-aws.html)
- [EKS Best Practices - HA](https://aws.github.io/aws-eks-best-practices/reliability/docs/application/)
- [Aurora Serverless v2](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html)

---

*Document Version: 1.0*
*Last Updated: December 2024*
*Maintained by: Platform Engineering Team*
