# Cost Estimation Guide

This document provides detailed cost breakdowns for SR deployment patterns to help with budget planning.

## Cost Calculator

**Interactive calculator:** [AWS Pricing Calculator Link]

**Assumptions:**
- us-east-1 region pricing (other regions may vary ±10-20%)
- 730 hours/month (30.42 days)
- On-Demand pricing unless noted
- Does not include AWS support costs

## SR-HA Pattern Cost Breakdown

### Base Configuration
- 100-500 concurrent users
- 500-1,500 workspaces
- Business hours usage (10 hours/day, 5 days/week)

| Service | Spec | Hours/Month | Unit Cost | Monthly Cost |
|---------|------|-------------|-----------|--------------|
| **EKS Control Plane** | 1 cluster | 730 | $0.10/hr | $73 |
| **Control Nodes** | 2× m5.large on-demand | 1,460 | $0.096/hr | $140 |
| **Provisioner Nodes** | 5× c5.2xlarge (peak 10h/day) | 1,095 | $0.34/hr | $372 |
| **Workspace Nodes** | 50× m5.2xlarge spot (peak 10h/day) | 10,950 | $0.10/hr | $1,095 |
| **Workspace Nodes** | 10× m5.2xlarge spot (off-peak) | 5,840 | $0.10/hr | $584 |
| **Aurora Serverless v2** | 2-4 ACU average | 2,920 ACU-hours | $0.16/ACU-hr | $467 |
| **NAT Gateway** | 3× NAT Gateways | 2,190 | $0.045/hr | $99 |
| **NAT Gateway Data** | 500 GB/month | 500 GB | $0.045/GB | $23 |
| **Network Load Balancer** | 1× NLB | 730 | $0.0225/hr | $16 |
| **NLB LCU Hours** | ~50 LCU-hours | 50 | $0.008/LCU-hr | $<1 |
| **EBS Volumes** | 1 TB gp3 (workspaces) | 1,000 GB | $0.08/GB-month | $80 |
| **CloudWatch Logs** | 50 GB ingestion, 90-day retention | 50 GB | $0.50/GB + $0.03/GB-month | $29 |
| **CloudWatch Metrics** | Custom metrics | ~1,000 metrics | $0.30/metric | $300 |
| **Data Transfer Out** | 200 GB/month | 200 GB | $0.09/GB | $18 |
| **Route 53** | 1 hosted zone + queries | 1M queries | $0.50 + $0.40/M | $1 |
| **ACM** | 1 certificate | - | Free | $0 |
| | | | **Total** | **$3,297/month** |

### Cost Optimization Features

**Time-Based Scaling Savings:**
- Without scaling (24/7 at peak): ~$5,800/month
- With scaling (10h peak, 14h off-peak): ~$3,300/month
- **Savings:** ~$2,500/month (43%)

**Spot Instance Savings:**
- Workspace nodes on-demand: ~$3,500/month
- Workspace nodes spot (70% discount): ~$1,100/month
- **Savings:** ~$2,400/month (69%)

**Combined Savings:** ~$4,900/month (55% vs 24/7 on-demand)

### Scaling Cost Impact

| User Count | Workspaces | Aurora ACU | Workspace Nodes | Monthly Cost |
|------------|------------|------------|-----------------|--------------|
| 10-50 | 50-200 | 1-2 | 10-20 | $1,500-2,000 |
| 50-100 | 200-500 | 2-4 | 20-40 | $2,000-3,000 |
| 100-300 | 500-1,500 | 4-8 | 40-80 | $3,000-5,000 |
| 300-500 | 1,500-3,000 | 8-16 | 80-200 | $5,000-10,000 |

## SR-Simple Pattern Cost Breakdown

### Base Configuration
- 5-20 concurrent users
- 10-100 workspaces
- Single AZ deployment

| Service | Spec | Hours/Month | Unit Cost | Monthly Cost |
|---------|------|-------------|-----------|--------------|
| **EKS Control Plane** | 1 cluster | 730 | $0.10/hr | $73 |
| **Control Node** | 1× m5.large on-demand | 730 | $0.096/hr | $70 |
| **Workspace Nodes** | 2× m5.xlarge on-demand | 1,460 | $0.192/hr | $280 |
| **Aurora Serverless v2** | 0.5-1 ACU average | 547 ACU-hours | $0.16/ACU-hr | $88 |
| **NAT Gateway** | 1× NAT Gateway | 730 | $0.045/hr | $33 |
| **NAT Gateway Data** | 100 GB/month | 100 GB | $0.045/GB | $5 |
| **Network Load Balancer** | 1× NLB | 730 | $0.0225/hr | $16 |
| **EBS Volumes** | 100 GB gp3 | 100 GB | $0.08/GB-month | $8 |
| **CloudWatch Logs** | 10 GB ingestion, 7-day retention | 10 GB | $0.50/GB | $5 |
| **Other** | Route 53, metrics, data transfer | - | - | $20 |
| | | | **Total** | **$598/month** |

**Cost comparison:**
- SR-Simple: ~$600/month
- SR-HA: ~$3,300/month
- **Savings:** ~$2,700/month (82% cheaper)

## Cost Comparison Summary

| Pattern | Availability | Users | Monthly Cost | Best For |
|---------|--------------|-------|--------------|----------|
| **SR-HA** | 99.9% (3 AZ) | 100-500 | $2,500-4,000 | Production |
| **SR-HA (24/7)** | 99.9% (3 AZ) | 100-500 | $4,000-6,000 | Global teams |
| **SR-Simple** | 95% (1 AZ) | <20 | $600-800 | Dev/test |

## Cost Optimization Strategies

### 1. Time-Based Scaling (SR-HA)
- **Savings:** 40-55% of EC2 costs
- **Best for:** Business-hours teams (9am-6pm)
- **Not recommended for:** 24/7 global teams

### 2. Spot Instances (SR-HA)
- **Savings:** 60-70% of workspace node costs
- **Best for:** Fault-tolerant workloads
- **Not recommended for:** Regulated industries requiring on-demand only

### 3. Aurora Serverless v2 Scaling
- **Optimize min ACU:** Set to 0.5 ACU during off-hours (if no active users)
- **Optimize max ACU:** Set to expected peak + 20% buffer (not default 16)
- **Savings:** 30-50% vs provisioned Aurora

### 4. VPC Endpoints (High NAT Gateway Usage)
- **Break-even:** If NAT Gateway data transfer >500 GB/month, VPC endpoints are cheaper
- **Savings:** ~$100-300/month for high-traffic deployments

### 5. Reserved Instances / Savings Plans
- **Control nodes:** 100% utilization → 30-40% savings with 1-year reserved
- **On-demand provisioner/workspace nodes:** Don't reserve (variable usage)

### 6. EBS Volume Optimization
- **Use gp3 instead of gp2:** 20% cheaper for same performance
- **Right-size volumes:** Default 50 GB, not 100 GB per workspace
- **Snapshot lifecycle:** Delete old snapshots (EBS snapshot costs)

## Budget Alerting

**Recommended CloudWatch Billing Alarms:**

```hcl
resource "aws_cloudwatch_metric_alarm" "billing_alert" {
  alarm_name          = "coder-monthly-cost-alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "21600"  # 6 hours
  statistic           = "Maximum"
  threshold           = "4000"  # $4,000 for SR-HA
  alarm_description   = "Alert when estimated monthly charges exceed $4,000"
  
  dimensions = {
    Currency = "USD"
  }
}
```

**Budget thresholds:**
- SR-Simple: Alert at $800 (133% of expected $600)
- SR-HA: Alert at $4,000 (121% of expected $3,300)
- SR-HA (24/7): Alert at $7,000 (117% of expected $6,000)

## Total Cost of Ownership (TCO)

**Beyond AWS costs, consider:**
- Coder licenses: ~$20-50/user/month (contact Coder sales)
- Operational overhead: 0.5-1 FTE for platform management
- Training and onboarding: One-time cost

**Example TCO for 100-user SR-HA deployment:**
- AWS infrastructure: $3,300/month
- Coder licenses: $3,000/month (100 users × $30)
- Platform operations: $8,000/month (0.5 FTE)
- **Total:** ~$14,300/month or $143/user/month

## Related Documentation

- [SR-HA Overview](../deployment-patterns/sr-ha/overview.md)
- [SR-Simple Overview](../deployment-patterns/sr-simple/overview.md)
- [AWS Services Used](./aws-services.md)
- [Choosing a Pattern](../getting-started/choosing-a-pattern.md)
- [Feature Flags](../configuration/feature-flags.md)
