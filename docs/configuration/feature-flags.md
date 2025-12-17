# Feature Flags Reference

This document explains the `deployment_features` feature flag object used to compose deployment patterns.

## Overview

Feature flags allow you to enable/disable specific architectural features by setting boolean values in your pattern file (`*.tfvars`).

## deployment_features Object

```hcl
deployment_features = {
  high_availability  = bool  # 3 AZs, 2+ replicas, HA infrastructure
  time_based_scaling = bool  # Auto-scaling schedules (06:45-18:15 ET)
}
```

## Flag Details

### high_availability

**Enables:** HA infrastructure for production workloads

**When true:**
- 3 availability zones
- coderd_replicas = 2+
- Spot instances enabled for workspace nodes (cost optimization)
- Multi-AZ Aurora deployment
- NAT Gateway in each AZ (3 total)

**When false:**
- 1 availability zone
- coderd_replicas = 1
- On-demand instances only
- Single-AZ Aurora deployment
- Single NAT Gateway

**Example use cases:**
- `true`: Production environments requiring 99.9% uptime
- `false`: Development/test environments, POC deployments

### time_based_scaling

**Enables:** Cost optimization via scheduled auto-scaling

**When true:**
- EKS node groups scale up at 06:45 ET (Monday-Friday)
- EKS node groups scale down at 18:15 ET (Monday-Friday)
- Desired peak node counts for pre-warming
- ~40-55% cost savings during off-hours

**When false:**
- No autoscaling schedules
- Static min/max/desired node counts (24/7 capacity)

**Example use cases:**
- `true`: Teams with business-hours usage (9am-6pm weekdays)
- `false`: 24/7 global teams, unpredictable usage patterns

## Pattern Examples

See [Choosing a Pattern](../getting-started/choosing-a-pattern.md) for pattern selection guidance.

### SR-HA Pattern (v1.0 - Production Ready)

```hcl
# patterns/sr-ha.tfvars
deployment_features = {
  high_availability  = true   # 3 AZs, 2+ replicas
  time_based_scaling = true   # Cost optimization
}

# Pattern-specific configuration
availability_zone_count = 3
coderd_replicas        = 2
enable_spot_instances  = true

scaling_schedule = {
  start_time = "45 6 * * MON-FRI"   # 06:45 ET
  stop_time  = "15 18 * * MON-FRI"  # 18:15 ET
  timezone   = "America/New_York"
}

max_workspaces = 3000
```

### SR-Simple Pattern (v2.0 - Planned)

```hcl
# patterns/sr-simple.tfvars
deployment_features = {
  high_availability  = false  # 1 AZ, 1 replica
  time_based_scaling = false  # No scheduling
}

# Pattern-specific configuration
availability_zone_count = 1
coderd_replicas        = 1
enable_spot_instances  = false

max_workspaces = 100
```

## Flag Combinations

| Pattern | high_availability | time_based_scaling | Use Case | Cost/Month |
|---------|-------------------|-------------------|----------|------------|
| **SR-HA** | true | true | Production, business hours | $2,500-4,000 |
| **SR-HA (24/7)** | true | false | Production, global teams | $4,000-6,000 |
| **SR-Simple** | false | false | Dev/test, POC | $600-800 |

## Implementation Details

### How Flags Control Infrastructure

The feature flags are evaluated in Terraform locals to derive infrastructure configuration:

```hcl
# locals.tf
locals {
  # Derive configuration from feature flags
  availability_zone_count = var.deployment_features.high_availability ? 3 : 1
  coderd_replicas         = var.deployment_features.high_availability ? 2 : 1
  enable_spot_instances   = var.deployment_features.high_availability

  # Time-based scaling
  enable_autoscaling_schedules = var.deployment_features.time_based_scaling

  # NAT Gateway count
  nat_gateway_count = var.deployment_features.high_availability ? 3 : 1
}

# main.tf - Module calls with conditional configuration
module "eks" {
  source = "./modules/eks"

  # Pass feature flags
  enable_autoscaling_schedules = local.enable_autoscaling_schedules
  scaling_schedule_start       = var.scaling_schedule.start_time
  scaling_schedule_stop        = var.scaling_schedule.stop_time

  # Derived values
  coderd_replicas = local.coderd_replicas
  # ...
}
```

### Module-Level Conditionals

Modules use `count` or `for_each` based on feature flags:

```hcl
# modules/eks/node_groups.tf
# Only create autoscaling schedules if time_based_scaling = true
resource "aws_autoscaling_schedule" "provisioner_scale_up" {
  count = var.enable_autoscaling_schedules ? 1 : 0

  scheduled_action_name  = "${var.cluster_name}-provisioner-scale-up"
  desired_capacity       = var.prov_node_desired_peak
  recurrence             = var.scaling_schedule_start
  time_zone              = var.scaling_timezone
  autoscaling_group_name = aws_eks_node_group.provisioner.resources[0].autoscaling_groups[0].name
}
```

## Configuration Guidelines

### Production Deployments

**Recommended configuration:**
```hcl
deployment_features = {
  high_availability  = true   # Always enable HA for production
  time_based_scaling = true   # Enable if business-hours usage
}
```

**Why:**
- HA ensures 99.9% uptime with multi-AZ resilience
- Time-based scaling reduces costs by ~40% for business-hours teams

### Development/Test Environments

**Recommended configuration:**
```hcl
deployment_features = {
  high_availability  = false  # Single AZ sufficient for dev/test
  time_based_scaling = false  # Always-on for development
}
```

**Why:**
- Lower cost (~$600/mo vs $3,000/mo)
- Simpler operations
- Acceptable downtime for non-production

### Custom Configurations

**24/7 Production (Global Teams):**
```hcl
deployment_features = {
  high_availability  = true   # HA required
  time_based_scaling = false  # No off-hours for global teams
}
```

**Cost-Optimized Production (Small Team):**
```hcl
deployment_features = {
  high_availability  = true   # HA for uptime
  time_based_scaling = true   # Aggressive scaling
}

# Further cost optimization
ws_node_desired_peak = 20      # Lower peak capacity
prov_node_desired_peak = 3     # Fewer provisioners
enable_spot_instances = true   # Max spot usage
```

## Validation

The deployment validates feature flag compatibility:

```hcl
# variables.tf
variable "deployment_features" {
  type = object({
    high_availability  = bool
    time_based_scaling = bool
  })

  validation {
    condition     = !(var.deployment_features.time_based_scaling && !var.deployment_features.high_availability)
    error_message = "time_based_scaling requires high_availability=true (need 3 AZs for meaningful scaling)"
  }
}
```

## Related Documentation

- [Choosing a Pattern](../getting-started/choosing-a-pattern.md) - Pattern selection guide
- [Variable Reference](./variables.md) - All Terraform variables
- [SR-HA Overview](../deployment-patterns/sr-ha/overview.md) - SR-HA pattern details
- [SR-Simple Overview](../deployment-patterns/sr-simple/overview.md) - SR-Simple pattern details
- [Cost Estimation](../reference/cost-estimation.md) - Cost impact of flags
- [Architecture Decisions](../reference/architecture-decisions.md) - Why feature flags over overlays
