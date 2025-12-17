# SR-HA Pattern Overview

**Status:** ✅ Production-validated (v1.0)

## Pattern Characteristics

The Single Region High Availability (SR-HA) pattern provides production-grade reliability with cost optimization through time-based scaling.

### Key Features

- **High Availability:** 3 availability zones with multi-AZ Aurora deployment
- **Auto-Scaling:** Time-based scaling (06:45-18:15 ET on weekdays)
- **Cost Optimization:** Spot instances for workspace nodes with on-demand fallback
- **Capacity:** Supports up to 3,000 concurrent workspaces
- **Resilience:** 2+ coderd replicas with automatic failover

## Architecture Components

### Compute Layer
- **Control Plane Nodes:** m5.large instances (2 vCPU, 8 GB RAM)
  - Min: 2 nodes, Max: 3 nodes
  - On-demand only for stability
- **Provisioner Nodes:** c5.2xlarge instances (8 vCPU, 16 GB RAM)
  - Min: 0 nodes, Max: 20 nodes
  - Scales to 5 nodes during peak hours
- **Workspace Nodes:** m5.2xlarge instances (8 vCPU, 32 GB RAM)
  - Min: 10 nodes, Max: 200 nodes
  - Scales to 50 nodes during peak hours
  - Uses spot instances with on-demand fallback

### Database Layer
- **Aurora PostgreSQL Serverless v2**
  - Version: 16.4
  - Capacity: 0.5-16 ACU (1-32 GB RAM)
  - Multi-AZ deployment across 3 zones
  - Automated backups with 90-day retention

### Network Layer
- **VPC:** 10.0.0.0/16 CIDR block
- **Subnets:** 3 per tier × 5 tiers = 15 total subnets
- **NAT Gateways:** 1 per AZ (3 total) for high availability
- **Load Balancer:** Network Load Balancer with cross-zone load balancing

## Feature Flags Configuration

```hcl
deployment_features = {
  high_availability      = true   # 3 AZs, 2+ replicas
  time_based_scaling     = true   # Auto-scaling schedules
  multi_region           = false  # Single region deployment
  pubsec_compliance      = false  # Standard security controls
  agent_ready_workspaces = false  # Standard workspace provisioning
}
```

## Deployment Pattern

```hcl
# patterns/sr-ha.tfvars
project_name = "coder"
environment  = "prod"
aws_region   = "us-east-1"

availability_zone_count = 3
coderd_replicas        = 2
enable_spot_instances  = true

scaling_schedule = {
  start_time = "45 6 * * MON-FRI"
  stop_time  = "15 18 * * MON-FRI"
  timezone   = "America/New_York"
}

max_workspaces = 3000
prov_node_desired_peak = 5
ws_node_desired_peak   = 50
```

## When to Use SR-HA

**✅ Use SR-HA for:**
- Production workloads requiring 99.9% uptime
- Teams with 100-3,000 concurrent users
- Cost-conscious deployments with predictable usage patterns
- Organizations with business-hours-focused development teams

**❌ Don't use SR-HA for:**
- Development/testing environments (use [SR-Simple](../sr-simple/overview.md))
- Global teams requiring low-latency access (use [Multi-Region](../multi-region/overview.md))
- Regulated industries requiring enhanced compliance (use [PubSec](../pubsec/overview.md))
- 24/7 workloads without predictable scaling patterns

## Cost Considerations

**Estimated Monthly Cost:** $2,500-$4,000 (varies by region and usage)

**Cost breakdown:**
- EKS cluster: ~$150/month
- EC2 instances (with time-based scaling): ~$1,200-$2,000/month
- Aurora Serverless v2: ~$400-$800/month
- Data transfer & NAT Gateway: ~$300-$500/month
- Other services (CloudWatch, Load Balancers): ~$450/month

**Cost optimization features:**
- Time-based scaling reduces costs by ~40% during off-hours
- Spot instances provide ~70% savings on workspace nodes
- Aurora Serverless v2 scales down to 0.5 ACU during low usage

## Related Documentation

- [SR-HA Deployment Guide](./deployment.md)
- [Time-Based Scaling Configuration](./time-based-scaling.md)
- [SR-HA Day 2 Operations](./operations.md)
- [Capacity Planning](./capacity-planning.md)
- [Feature Flags Reference](../../configuration/feature-flags.md)
