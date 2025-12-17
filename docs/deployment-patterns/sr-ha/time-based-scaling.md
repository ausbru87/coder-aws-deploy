# Time-Based Scaling Configuration

**Pattern:** SR-HA | **Feature Flag:** `time_based_scaling = true`

## Overview

Time-based scaling automatically adjusts EKS node group capacity based on scheduled business hours, reducing costs by ~40% during off-peak periods while ensuring resources are available during peak usage.

## Scaling Schedule

### Default Schedule (Eastern Time)

- **Scale Up:** 06:45 ET (Monday-Friday)
  - Provisioner nodes: 0 → 5 desired
  - Workspace nodes: 10 → 50 desired
  
- **Scale Down:** 18:15 ET (Monday-Friday)
  - Provisioner nodes: 5 → 0 desired
  - Workspace nodes: 50 → 10 desired

### Weekend Behavior

- No scheduled scaling events
- Node groups maintain minimum desired capacity
- Manual scaling available if needed

## Configuration

### Pattern File Configuration

```hcl
# patterns/sr-ha.tfvars
deployment_features = {
  time_based_scaling = true
}

scaling_schedule = {
  start_time = "45 6 * * MON-FRI"   # Cron format: minute hour day month weekday
  stop_time  = "15 18 * * MON-FRI"
  timezone   = "America/New_York"
}

prov_node_desired_peak = 5   # Provisioner nodes during peak hours
ws_node_desired_peak   = 50  # Workspace nodes during peak hours
```

### Customizing the Schedule

**Example: Pacific Time Schedule**
```hcl
scaling_schedule = {
  start_time = "45 6 * * MON-FRI"
  stop_time  = "15 18 * * MON-FRI"
  timezone   = "America/Los_Angeles"  # PT zone
}
```

**Example: 24/7 Schedule (Disable Time-Based Scaling)**
```hcl
deployment_features = {
  time_based_scaling = false  # Disable scheduled scaling
}

# Static desired capacity
prov_node_desired = 5
ws_node_desired   = 50
```

**Example: Extended Hours (Early Start, Late End)**
```hcl
scaling_schedule = {
  start_time = "0 5 * * MON-FRI"    # 05:00 ET
  stop_time  = "0 21 * * MON-FRI"   # 21:00 ET
  timezone   = "America/New_York"
}
```

## Implementation Details

### AWS Auto Scaling Schedules

The time-based scaling feature creates AWS Auto Scaling scheduled actions for each node group:

```terraform
# Provisioner scale up (06:45 ET)
resource "aws_autoscaling_schedule" "provisioner_scale_up" {
  count                  = var.enable_autoscaling_schedules ? 1 : 0
  scheduled_action_name  = "${var.cluster_name}-provisioner-scale-up"
  min_size               = var.prov_node_min
  max_size               = var.prov_node_max
  desired_capacity       = var.prov_node_desired_peak
  recurrence             = var.scaling_schedule.start_time
  time_zone              = var.scaling_schedule.timezone
  autoscaling_group_name = aws_eks_node_group.provisioner.resources[0].autoscaling_groups[0].name
}

# Provisioner scale down (18:15 ET)
resource "aws_autoscaling_schedule" "provisioner_scale_down" {
  count                  = var.enable_autoscaling_schedules ? 1 : 0
  scheduled_action_name  = "${var.cluster_name}-provisioner-scale-down"
  min_size               = var.prov_node_min
  max_size               = var.prov_node_max
  desired_capacity       = 0
  recurrence             = var.scaling_schedule.stop_time
  time_zone              = var.scaling_schedule.timezone
  autoscaling_group_name = aws_eks_node_group.provisioner.resources[0].autoscaling_groups[0].name
}
```

### Node Group Capacity Ranges

| Node Group | Min | Max | Off-Peak Desired | Peak Desired |
|------------|-----|-----|------------------|--------------|
| Control    | 2   | 3   | 2                | 2 (static)   |
| Provisioner| 0   | 20  | 0                | 5            |
| Workspace  | 10  | 200 | 10               | 50           |

**Note:** Control plane nodes do NOT scale on a schedule to ensure continuous API availability.

## Pre-Warming Strategy

The 15-minute lead time (06:45 scale up for 07:00 work start) allows nodes to:
1. Launch EC2 instances (~2 min)
2. Join the EKS cluster (~3 min)
3. Pull container images (~5 min)
4. Pass health checks (~2 min)
5. Be ready for workload scheduling (~3 min buffer)

This ensures infrastructure is ready when users arrive at 07:00.

## Monitoring Scaling Events

### CloudWatch Metrics

Monitor scaling activity with these metrics:

```bash
# View desired capacity changes
aws cloudwatch get-metric-statistics \
  --namespace AWS/AutoScaling \
  --metric-name GroupDesiredCapacity \
  --dimensions Name=AutoScalingGroupName,Value=<asg-name> \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average
```

### Kubernetes Events

```bash
# Watch node scaling events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -i "scale"

# Check current node counts
kubectl get nodes --label-columns=node-group
```

### CloudWatch Alarms

Recommended alarms for time-based scaling:

```hcl
# Alert if provisioner nodes fail to scale up
resource "aws_cloudwatch_metric_alarm" "provisioner_scale_up_failed" {
  alarm_name          = "provisioner-scale-up-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "GroupDesiredCapacity"
  namespace           = "AWS/AutoScaling"
  period              = "300"
  statistic           = "Average"
  threshold           = "3"
  alarm_description   = "Provisioner nodes failed to scale up at 06:45"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    AutoScalingGroupName = aws_eks_node_group.provisioner.resources[0].autoscaling_groups[0].name
  }
}
```

## Cost Savings Analysis

### Monthly Cost Comparison

**Without Time-Based Scaling (24/7 at peak capacity):**
- Provisioner nodes: 5 × c5.2xlarge × 730 hours = ~$1,240/month
- Workspace nodes: 50 × m5.2xlarge × 730 hours = ~$14,600/month
- **Total:** ~$15,840/month

**With Time-Based Scaling (peak 10h/day, off-peak 14h/day, weekdays only):**
- Provisioner nodes: (5 × 10h + 0 × 14h) × 5 days × 4 weeks × cost = ~$430/month
- Workspace nodes: (50 × 10h + 10 × 14h) × 5 days × 4 weeks × cost = ~$6,720/month
- **Total:** ~$7,150/month

**Savings:** ~$8,690/month (~55% reduction)

**Note:** Actual savings depend on spot instance availability, usage patterns, and regional pricing.

## Operational Considerations

### Manual Override

To temporarily override scheduled scaling:

```bash
# Scale up provisioners manually (e.g., for off-hours work)
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name <asg-name> \
  --desired-capacity 5

# Scale down early (e.g., for holiday)
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name <asg-name> \
  --desired-capacity 0
```

**Note:** Manual changes are temporary; the next scheduled action will reset to scheduled capacity.

### Disabling Scheduled Scaling

To permanently disable (e.g., during incident response):

```bash
# Suspend scheduled actions
aws autoscaling suspend-processes \
  --auto-scaling-group-name <asg-name> \
  --scaling-processes ScheduledActions
```

To re-enable:

```bash
aws autoscaling resume-processes \
  --auto-scaling-group-name <asg-name> \
  --scaling-processes ScheduledActions
```

### Scaling During Holidays

For holidays when no users will be active:

1. **Option 1:** Manually scale down in the morning:
   ```bash
   aws autoscaling set-desired-capacity --auto-scaling-group-name <asg> --desired-capacity 0
   ```

2. **Option 2:** Temporarily suspend scheduled actions (see above)

3. **Option 3:** Update scaling schedule to exclude specific dates (requires Terraform apply)

## Troubleshooting

### Nodes Don't Scale Up

**Symptoms:** Desired capacity changes but node count doesn't increase

**Common causes:**
1. **AWS quota limits:** Check EC2 instance quotas
   ```bash
   aws service-quotas get-service-quota \
     --service-code ec2 \
     --quota-code L-1216C47A  # Running On-Demand instances
   ```

2. **Insufficient subnet IP addresses:** Check available IPs
   ```bash
   aws ec2 describe-subnets --subnet-ids <subnet-id> \
     --query 'Subnets[0].AvailableIpAddressCount'
   ```

3. **Spot instance unavailability:** Check spot fulfillment
   ```bash
   aws ec2 describe-spot-instance-requests \
     --filters Name=state,Values=open
   ```

### Nodes Don't Scale Down

**Symptoms:** Scheduled scale-down occurs but nodes remain

**Common causes:**
1. **Running workloads:** Nodes with active pods won't terminate
   ```bash
   kubectl get pods --all-namespaces -o wide | grep <node-name>
   ```

2. **PodDisruptionBudget blocking eviction:**
   ```bash
   kubectl get pdb --all-namespaces
   ```

3. **Cluster Autoscaler interference:** Check if Cluster Autoscaler is enabled
   ```bash
   kubectl get deployment cluster-autoscaler -n kube-system
   ```

### Inconsistent Scaling Behavior

**Symptoms:** Some days scale up works, other days it doesn't

**Check scheduled action history:**
```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name <asg-name> \
  --max-records 50
```

Look for `StatusCode: Failed` and `StatusMessage` for error details.

## Related Documentation

- [SR-HA Overview](./overview.md)
- [Capacity Planning](./capacity-planning.md)
- [Day 2 Operations](./operations.md)
- [Compute Configuration](../../configuration/compute.md)
- [Troubleshooting](../../operations/troubleshooting.md)
