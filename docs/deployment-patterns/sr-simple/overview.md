# SR-Simple Pattern Overview

**Status:** 🚧 Future (Planned for v2.0)

## Pattern Characteristics

The Single Region Simple (SR-Simple) pattern provides a minimal, cost-effective Coder deployment for development, testing, and small team environments.

### Key Features

- **Simplified Architecture:** Single availability zone
- **Cost Optimized:** Minimal resources for <100 users
- **Quick Setup:** Deploy in 30-45 minutes
- **Development-Focused:** Ideal for dev/test workloads
- **No Auto-Scaling:** Static capacity with manual scaling

## Architecture Components

### Compute Layer
- **Control Plane Nodes:** m5.large instance (2 vCPU, 8 GB RAM)
  - Single node (no HA)
  - On-demand only
- **Workspace Nodes:** m5.xlarge instances (4 vCPU, 16 GB RAM)
  - Min: 2 nodes, Max: 10 nodes
  - On-demand only (no spot instances)

### Database Layer
- **Aurora PostgreSQL Serverless v2**
  - Version: 16.4
  - Capacity: 0.5-4 ACU (1-8 GB RAM)
  - Single-AZ deployment
  - 7-day backup retention

### Network Layer
- **VPC:** 10.0.0.0/16 CIDR block
- **Subnets:** 1 per tier (5 total subnets)
- **NAT Gateway:** Single NAT Gateway
- **Load Balancer:** Network Load Balancer (single AZ)

## Feature Flags Configuration

```hcl
deployment_features = {
  high_availability      = false  # Single AZ, 1 replica
  time_based_scaling     = false  # No auto-scaling
  multi_region           = false  # Single region only
  pubsec_compliance      = false  # Standard security
  agent_ready_workspaces = false  # Standard provisioning
}
```

## Deployment Pattern

```hcl
# patterns/sr-simple.tfvars
project_name = "coder"
environment  = "dev"
aws_region   = "us-east-1"

availability_zone_count = 1
coderd_replicas        = 1
enable_spot_instances  = false

max_workspaces = 100
```

## When to Use SR-Simple

**✅ Use SR-Simple for:**
- Development and testing environments
- Proof-of-concept deployments
- Small teams (<20 concurrent users)
- Cost-sensitive non-production workloads
- Learning and experimentation

**❌ Don't use SR-Simple for:**
- Production workloads (use [SR-HA](../sr-ha/overview.md))
- Mission-critical applications
- Teams requiring 99.9% uptime SLA
- Deployments with >100 concurrent users

## Cost Considerations

**Estimated Monthly Cost:** $400-$800 (varies by region and usage)

**Cost breakdown:**
- EKS cluster: ~$75/month
- EC2 instances: ~$200-$400/month
- Aurora Serverless v2: ~$50-$150/month
- Data transfer & NAT Gateway: ~$50-$100/month
- Other services: ~$25-$150/month

**Cost comparison to SR-HA:**
- ~80% cheaper than SR-HA
- Single AZ (vs 3 AZ) reduces NAT Gateway costs
- Smaller node sizes and counts
- Lower Aurora capacity range

## Limitations

**Availability:**
- **No Multi-AZ redundancy:** Single point of failure at AZ level
- **Single NAT Gateway:** AZ outage blocks all egress traffic
- **Single coderd replica:** No automatic failover

**Scalability:**
- **Max 100 workspaces:** Not suitable for large teams
- **Manual scaling:** No time-based auto-scaling
- **Limited Aurora capacity:** Max 4 ACU may bottleneck at scale

**Performance:**
- **Lower provisioning throughput:** Single provisioner node
- **Shared resources:** Workspaces compete for limited node capacity

## Migration Path

When your team outgrows SR-Simple, migrate to SR-HA:

```bash
# 1. Update pattern file
cp patterns/sr-simple.tfvars patterns/sr-ha.tfvars

# 2. Enable HA features
sed -i 's/high_availability      = false/high_availability      = true/' patterns/sr-ha.tfvars
sed -i 's/time_based_scaling     = false/time_based_scaling     = true/' patterns/sr-ha.tfvars

# 3. Update capacity settings
sed -i 's/availability_zone_count = 1/availability_zone_count = 3/' patterns/sr-ha.tfvars
sed -i 's/coderd_replicas        = 1/coderd_replicas        = 2/' patterns/sr-ha.tfvars
sed -i 's/max_workspaces = 100/max_workspaces = 3000/' patterns/sr-ha.tfvars

# 4. Apply changes (may require brief downtime for AZ migration)
terraform apply -var-file=patterns/sr-ha.tfvars
```

**Migration considerations:**
- Database snapshot → restore to multi-AZ cluster
- Workspace downtime during subnet migration (~15-30 min)
- DNS cutover to new load balancer
- User communication recommended

## Related Documentation

- [SR-Simple Deployment Guide](./deployment.md) (future)
- [When to Use SR-Simple](./when-to-use.md) (future)
- [SR-HA Pattern](../sr-ha/overview.md) (production alternative)
- [Choosing a Pattern](../../getting-started/choosing-a-pattern.md)
