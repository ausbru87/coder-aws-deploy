# Observability and Monitoring

This document covers logging, monitoring, and alerting for Coder deployments.

## CloudWatch Logs

### Log Groups

- `/aws/eks/coder-prod/cluster` - EKS control plane logs
- `/aws/containerinsights/coder-prod/application` - Application logs
- `/aws/containerinsights/coder-prod/performance` - Performance metrics
- `/aws/vpc/coder-prod/flow-logs` - VPC flow logs

### Log Retention

- **SR-HA:** 90 days


### Fluent Bit

- Version: 0.47.10
- Collects logs from all pods
- Parses JSON logs
- Ships to CloudWatch Logs

## CloudWatch Metrics

### Coder Application Metrics

- API latency (P50, P95, P99)
- Workspace provisioning time
- Active workspace count
- User session count

### Infrastructure Metrics

- EKS node CPU/memory utilization
- Aurora database capacity (ACU)
- NAT Gateway bytes processed
- NLB target health

## Container Insights

When `enable_container_insights = true`:
- Enhanced EKS monitoring
- Pod-level metrics
- Node-level metrics
- Performance dashboards

## Amazon Managed Prometheus (AMP) Integration

When `enable_amp_integration = true`:
- Prometheus metrics from coderd
- Long-term metric storage
- Grafana integration
- Custom alerting rules

## Alerting

### CloudWatch Alarms

- `coder-api-latency-high`: P95 > 500ms
- `coder-provisioning-slow`: Provisioning > 5 min
- `coder-error-rate-high`: Error rate > 1%
- `eks-node-pressure`: Node CPU/Memory > 80%
- `aurora-cpu-high`: Database CPU > 80%

Configure `alert_sns_topic_arn` to receive notifications.

## CloudTrail

When `enable_cloudtrail = true`:
- API call logging
- Compliance audit trail
- Security event tracking
- S3 bucket for log storage

## Related Documentation

- [Day 1 Configuration](../operations/day1-configuration.md)
- [Day 2 Operations](../operations/day2-operations.md)
- [Troubleshooting](../operations/troubleshooting.md)
