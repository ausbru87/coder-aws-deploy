# SR-HA Capacity Planning and Performance Targets

This document defines the performance targets and capacity planning guidelines for the Single Region High Availability (SR-HA) deployment pattern.

## Overview

The SR-HA pattern is designed to support **up to 3000 concurrent workspaces** with the following infrastructure:
- 3 availability zones for high availability
- Auto-scaling workspace nodes (10-200 nodes)
- Aurora PostgreSQL Serverless v2 with automatic scaling
- Time-based scaling for cost optimization

## Performance Acceptance Criteria

These are the validated performance targets for the SR-HA pattern. All deployments should meet these criteria before production use.

| Metric | Target | Requirement | Pass Condition |
|--------|--------|-------------|----------------|
| Pod workspace provisioning (P95) | < 2 minutes | 14.6 | 95% of pods ready in < 120s |
| EC2 workspace provisioning (P95) | < 5 minutes | 14.7 | 95% of EC2 instances ready in < 300s |
| GPU workspace provisioning (P95) | < 5 minutes | 14.7a | 95% of GPU instances ready in < 300s |
| API response time (P95) | < 500ms | 14.9 | 95% of requests complete in < 500ms |
| API response time (P99) | < 1 second | 14.10 | 99% of requests complete in < 1000ms |
| Concurrent provisioning operations | 1000 | 14.11 | 1000 workspaces created concurrently |
| Error rate | < 1% | - | Less than 1% of operations fail |

### Fail Conditions

A deployment fails acceptance testing if any of the following occur:
- Any metric exceeds 2x the target value
- Error rate exceeds 5%
- Test cannot complete due to infrastructure issues
- Database connection pool exhaustion
- Node autoscaling failures

## Capacity Planning Guidelines

### Workspace Node Sizing

For the SR-HA pattern with 3000 workspace capacity:

| Workload Type | Node Instance Type | Min Nodes | Max Nodes | Peak Nodes |
|---------------|-------------------|-----------|-----------|------------|
| Container workspaces | m5.2xlarge | 10 | 200 | 50 |
| EC2 workspaces | Workspace-specific | - | - | - |
| GPU workspaces | g4dn.xlarge | 0 | 20 | 5 |

**Rationale:**
- **m5.2xlarge** provides 8 vCPU, 32 GB RAM
- Supports ~15-20 container workspaces per node (2-4 vCPU, 4-8 GB RAM each)
- Peak node count (50) supports ~750-1000 concurrent container workspaces
- Additional capacity scales automatically via Karpenter

### Database Capacity

- **Aurora Serverless v2**: 0.5 ACU (1 GB RAM) to 16 ACU (32 GB RAM)
- Recommended starting capacity: 1 ACU
- Auto-scales based on CPU/memory utilization
- Connection limit scales with ACU count

### Provisioner Scaling

| Concurrent Users | Provisioner Replicas | Provisioning Rate |
|------------------|---------------------|-------------------|
| < 10 | 6 (default) | ~100 workspaces/hour |
| 10-15 | 8 | ~133 workspaces/hour |
| 15-20 | 10 | ~167 workspaces/hour |
| 20-30 | 12-15 | ~200-250 workspaces/hour |

### Network Capacity

- **NAT Gateway**: 1 per AZ (3 total) - 5 Gbps burst, 45 Gbps sustained
- **NLB**: Automatically scales, supports 100K concurrent connections
- **VPC Endpoints**: Reduces NAT Gateway egress costs

## Testing Procedures

To validate your SR-HA deployment meets these targets, see:
- [Scaling and Performance Testing Guide](../../operations/scaling.md) - Complete testing procedures
- [Day 2 Operations](../../operations/day2-operations.md) - Ongoing capacity monitoring

## Related Documentation

- [SR-HA Deployment Guide](./deployment.md)
- [SR-HA Time-Based Scaling](./time-based-scaling.md)
- [Scaling and Performance Testing](../../operations/scaling.md)
- [Troubleshooting Guide](../../operations/troubleshooting.md)
