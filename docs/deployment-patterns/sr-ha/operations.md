# SR-HA Day 2 Operations

**Pattern:** SR-HA | **Audience:** Platform operators and SREs

## Overview

This guide covers ongoing operational tasks specific to the SR-HA deployment pattern. For general Day 2 operations applicable to all patterns, see [Day 2 Operations](../../operations/day2-operations.md).

## Daily Operations

### Morning Pre-Scale Checklist (06:30 ET)

Run 15 minutes before scheduled scale-up to catch issues early:

```bash
# 1. Check control plane health
kubectl get nodes -l node-group=control
kubectl get pods -n coder -l app=coder-server

# 2. Verify database connectivity
kubectl exec -n coder deploy/coder-server -- coder server --postgres-url=$CODER_PG_CONNECTION_URL

# 3. Check CloudWatch alarms
aws cloudwatch describe-alarms --state-value ALARM

# 4. Verify NAT Gateway health (all 3 AZs)
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[*].[NatGatewayId,SubnetId,State]'

# 5. Check Auto Scaling Group desired capacity
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw provisioner_asg_name) $(terraform output -raw workspace_asg_name) \
  --query 'AutoScalingGroups[*].[AutoScalingGroupName,DesiredCapacity,MinSize,MaxSize]'
```

**Expected results:**
- All control nodes: Ready
- Coder pods: Running (2/2 replicas)
- No ALARM state alarms
- 3 NAT Gateways: available
- ASG desired capacity: 0 provisioner, 10 workspace (before scale-up)

### Post-Scale Verification (07:00 ET)

Verify successful scale-up 15 minutes after scheduled event:

```bash
# 1. Confirm node counts match desired capacity
kubectl get nodes -l node-group=provisioner | wc -l  # Should be 5
kubectl get nodes -l node-group=workspace | wc -l    # Should be 50

# 2. Check node readiness
kubectl get nodes -l node-group=provisioner,workspace --no-headers | \
  awk '{if ($2 != "Ready") print $0}'  # Should return nothing

# 3. Verify pod scheduling
kubectl get pods -n coder --field-selector=status.phase!=Running

# 4. Check spot instance fulfillment rate
aws ec2 describe-instances \
  --filters "Name=instance-lifecycle,Values=spot" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,SpotInstanceRequestId]' \
  | jq length
```

### Evening Scale-Down Verification (18:30 ET)

Verify successful scale-down 15 minutes after scheduled event:

```bash
# 1. Confirm node counts
kubectl get nodes -l node-group=provisioner | wc -l  # Should be 0
kubectl get nodes -l node-group=workspace | wc -l    # Should be 10

# 2. Check for stuck nodes
kubectl get nodes -l node-group=provisioner,workspace \
  --field-selector=spec.unschedulable=true

# 3. Verify no active workspaces blocking termination
kubectl get pods -n coder-workspaces --field-selector=status.phase=Running | wc -l

# 4. Review scaling activity
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $(terraform output -raw provisioner_asg_name) \
  --max-records 10 \
  --query 'Activities[?StatusCode==`Failed`]'
```

## Weekly Operations

### Monday: Capacity Review

```bash
# Check workspace provisioning times (P95)
aws cloudwatch get-metric-statistics \
  --namespace Coder \
  --metric-name WorkspaceProvisioningTime \
  --dimensions Name=Environment,Value=prod \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT00:00:00Z) \
  --end-time $(date -u +%Y-%m-%dT00:00:00Z) \
  --period 86400 \
  --statistics Average,p95 \
  --unit Seconds

# Review peak workspace count
aws cloudwatch get-metric-statistics \
  --namespace Coder \
  --metric-name ActiveWorkspaceCount \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT00:00:00Z) \
  --end-time $(date -u +%Y-%m-%dT00:00:00Z) \
  --period 3600 \
  --statistics Maximum

# Analyze Aurora ACU usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ServerlessDatabaseCapacity \
  --dimensions Name=DBClusterIdentifier,Value=$(terraform output -raw db_cluster_id) \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT00:00:00Z) \
  --end-time $(date -u +%Y-%m-%dT00:00:00Z) \
  --period 3600 \
  --statistics Average,Maximum
```

**Action items:**
- If P95 provisioning time > 2 min: Increase `prov_node_desired_peak`
- If peak workspaces > 2,800: Review capacity planning
- If Aurora ACU consistently > 14: Consider increasing max ACU

### Wednesday: Cost Analysis

```bash
# Review week-to-date costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -d 'last monday' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Environment \
  --filter file://cost-filter.json

# Cost filter for Coder resources
cat > cost-filter.json << 'FILTER'
{
  "Tags": {
    "Key": "Project",
    "Values": ["coder"]
  }
}
FILTER

# Spot vs On-Demand ratio
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=coder" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceLifecycle]' \
  | jq -s 'add | group_by(.[1]) | map({key: .[0][1], count: length})'
```

### Friday: Backup Verification

```bash
# Check Aurora automated backups
aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier $(terraform output -raw db_cluster_id) \
  --snapshot-type automated \
  --query 'DBClusterSnapshots[0].[SnapshotCreateTime,Status,PercentProgress]'

# Verify snapshot age (should be < 24 hours)
aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier $(terraform output -raw db_cluster_id) \
  --snapshot-type automated \
  --query 'DBClusterSnapshots[0].SnapshotCreateTime' \
  | xargs -I {} date -d {} +%s | \
    awk -v now=$(date +%s) '{print (now - $1) / 3600 " hours ago"}'

# Test snapshot restore (quarterly)
# See "Quarterly: Disaster Recovery Drill" below
```

## Monthly Operations

### First Monday: Patch Management

```bash
# Check for EKS cluster updates
aws eks describe-cluster --name $(terraform output -raw cluster_name) \
  --query 'cluster.version'

# Compare to latest available
aws eks describe-addon-versions --kubernetes-version 1.31 \
  --query 'addons[*].[addonName,addonVersions[0].addonVersion]'

# Check for node AMI updates
aws ssm get-parameter \
  --name /aws/service/eks/optimized-ami/1.31/amazon-linux-2/recommended/image_id \
  --query 'Parameter.Value'

# Check Coder version
kubectl exec -n coder deploy/coder-server -- coder version

# Compare to latest release
curl -s https://api.github.com/repos/coder/coder/releases/latest | jq -r .tag_name
```

**Action items:**
- Schedule EKS upgrade if > 1 minor version behind (see [Upgrades](../../operations/upgrades.md))
- Plan node AMI update if > 2 months old
- Review Coder release notes for security patches

### Mid-Month: Cost Optimization Review

```bash
# Identify underutilized resources
# 1. NAT Gateway usage (consider VPC endpoints if high)
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value=<nat-gw-id> \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT00:00:00Z) \
  --end-time $(date -u +%Y-%m-%dT00:00:00Z) \
  --period 2592000 \
  --statistics Sum

# 2. Workspace node utilization during off-peak hours
kubectl top nodes -l node-group=workspace --no-headers | \
  awk '{cpu+=$2; mem+=$4} END {print "Avg CPU:", cpu/NR, "Avg Mem:", mem/NR}'

# 3. Aurora idle time (consider lower min ACU)
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBClusterIdentifier,Value=$(terraform output -raw db_cluster_id) \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT00:00:00Z) \
  --end-time $(date -u +%Y-%m-%dT00:00:00Z) \
  --period 3600 \
  --statistics Average
```

**Optimization opportunities:**
- NAT Gateway data > 100 GB/month → Enable VPC endpoints
- Workspace node CPU < 20% during peak → Reduce `ws_node_desired_peak`
- Aurora connections < 10 after hours → Consider min ACU 0.5 → 0.25 (if available)

## Quarterly Operations

### Disaster Recovery Drill

**Goal:** Validate RTO (2-4 hours) and RPO (5 minutes) targets

```bash
# Phase 1: Verify Backups (15 min)
# 1. List recent snapshots
aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier $(terraform output -raw db_cluster_id) \
  --snapshot-type automated \
  --max-records 5

# 2. Check backup retention policy
aws rds describe-db-clusters \
  --db-cluster-identifier $(terraform output -raw db_cluster_id) \
  --query 'DBClusters[0].BackupRetentionPeriod'

# Phase 2: Restore to Test Environment (60-90 min)
# 1. Restore Aurora snapshot
aws rds restore-db-cluster-from-snapshot \
  --db-cluster-identifier coder-prod-dr-test \
  --snapshot-identifier <snapshot-id> \
  --engine aurora-postgresql \
  --engine-version 16.4 \
  --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=2

# 2. Deploy EKS cluster (test environment)
cd terraform/environments/dr-test
terraform init
terraform apply -var-file=../../patterns/sr-ha.tfvars -var="db_snapshot_id=<snapshot-id>"

# 3. Verify coderd startup
kubectl logs -n coder deploy/coder-server --tail=100

# Phase 3: Validation (30 min)
# 1. Test user login
curl -X POST https://coder-dr-test.example.com/api/v2/users/login \
  -d '{"email":"test@example.com","password":"<password>"}'

# 2. Verify workspace template availability
coder templates list --url https://coder-dr-test.example.com

# 3. Test workspace creation
coder create my-test-workspace --template=kubernetes-pod

# Phase 4: Cleanup (15 min)
terraform destroy -auto-approve
aws rds delete-db-cluster --db-cluster-identifier coder-prod-dr-test --skip-final-snapshot
```

**Document results:**
- Actual RTO: ___ hours
- Actual RPO: ___ minutes
- Issues encountered: ___
- Remediation actions: ___

### Capacity Planning Review

Update capacity projections based on growth trends:

```bash
# Calculate 90-day growth rate
# 1. User count growth
coder users list --output=json | jq 'length' > /tmp/users-today.txt
# Compare to users-90-days-ago.txt

# 2. Workspace count growth
kubectl get crd workspaces.coder.com -o json | jq '.status.storedVersions | length'

# 3. Database size growth
aws rds describe-db-clusters \
  --db-cluster-identifier $(terraform output -raw db_cluster_id) \
  --query 'DBClusters[0].AllocatedStorage'

# 4. Project resource needs
# If growth rate > 15% per quarter, plan for:
# - Increasing max_workspaces
# - Adjusting node group max sizes
# - Reviewing Aurora max ACU capacity
```

## Incident Response

### High Provisioning Time Alert (P95 > 2 min)

**Severity:** P2 (Business Impact)

**Immediate actions:**

```bash
# 1. Check provisioner pod health
kubectl get pods -n coder -l app=coder-provisioner
kubectl logs -n coder -l app=coder-provisioner --tail=100 | grep -i error

# 2. Check workspace node availability
kubectl get nodes -l node-group=workspace --no-headers | \
  awk '{if ($2 == "Ready") ready++; total++} END {print ready "/" total " ready"}'

# 3. Manually scale up workspace nodes
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $(terraform output -raw workspace_asg_name) \
  --desired-capacity 75  # Increase by 50%

# 4. Monitor provisioning queue
coder provisionerd list --output=json | jq '.[] | {id:.id, status:.status}'
```

**Root cause analysis:**
- Workspace node scaling behind demand → Increase `ws_node_desired_peak`
- Spot instance unavailability → Verify on-demand fallback working
- Provisioner pod resource limits → Check CPU/memory throttling

### Database Connection Exhaustion

**Severity:** P1 (Service Outage)

**Immediate actions:**

```bash
# 1. Check current connection count
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBClusterIdentifier,Value=$(terraform output -raw db_cluster_id) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Maximum

# 2. Identify connection sources
kubectl exec -n coder deploy/coder-server -- \
  psql $CODER_PG_CONNECTION_URL -c \
  "SELECT usename, application_name, count(*) FROM pg_stat_activity GROUP BY usename, application_name;"

# 3. Scale up Aurora ACU (increases max connections)
aws rds modify-db-cluster \
  --db-cluster-identifier $(terraform output -raw db_cluster_id) \
  --serverless-v2-scaling-configuration MinCapacity=1,MaxCapacity=32 \
  --apply-immediately

# 4. Restart coderd pods to reset connection pool
kubectl rollout restart deployment/coder-server -n coder
```

**Prevention:**
- Review connection pool settings in Coder Helm values
- Consider PgBouncer for connection pooling
- Set max ACU based on expected connection count

### Multi-AZ Failure Scenario

**Severity:** P1 (Partial Service Outage)

**Symptoms:**
- Pods in one AZ failing to schedule
- NAT Gateway in one AZ unavailable
- Database replica lag increasing

**Immediate actions:**

```bash
# 1. Identify failed AZ
kubectl get nodes -o wide | awk '{print $7}' | sort | uniq -c

# 2. Cordon nodes in failed AZ
kubectl cordon $(kubectl get nodes -o wide | grep <failed-az> | awk '{print $1}')

# 3. Drain workloads from failed AZ nodes
kubectl drain $(kubectl get nodes -o wide | grep <failed-az> | awk '{print $1}') \
  --ignore-daemonsets --delete-emptydir-data --force

# 4. Verify Aurora failover
aws rds describe-db-clusters \
  --db-cluster-identifier $(terraform output -raw db_cluster_id) \
  --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].AvailabilityZone'

# 5. Check control plane distribution
kubectl get pods -n coder -o wide | grep coder-server | awk '{print $7}' | sort | uniq -c
```

**Recovery:**
- Wait for AWS to resolve AZ issue (check AWS Health Dashboard)
- Once AZ recovers, uncordon nodes: `kubectl uncordon <node>`
- Monitor for 1 hour before considering AZ stable

## Runbook Index

For detailed operational procedures, see:

- [Day 0: Deployment](../../operations/day0-deployment.md)
- [Day 1: Configuration](../../operations/day1-configuration.md)
- [Day 2: Operations](../../operations/day2-operations.md) (general)
- [Scaling Procedures](../../operations/scaling.md)
- [Upgrade Procedures](../../operations/upgrades.md)
- [Troubleshooting Guide](../../operations/troubleshooting.md)

## Related Documentation

- [SR-HA Overview](./overview.md)
- [Time-Based Scaling](./time-based-scaling.md)
- [Capacity Planning](./capacity-planning.md)
