# Day 2: Ongoing Operations

This guide covers ongoing operations and maintenance procedures for the Coder platform. Day 2 operations include platform restore, scaling, and monthly backup testing.

**Target Audience:** DevSecOps Engineers L1-5, SysAdmins L3-L6

## Table of Contents

1. [Platform Restore Procedures](#platform-restore-procedures)
2. [Scaling Procedures](#scaling-procedures)
3. [Monthly Backup Restore Testing](#monthly-backup-restore-testing)

## Prerequisites

- Platform successfully deployed via [Day 0: Infrastructure Deployment](day0-deployment.md)
- Initial configuration completed via [Day 1: Initial Configuration](day1-configuration.md)
- Access to AWS Console, kubectl, and Terraform

## Platform Restore Procedures

### Scenario: Complete Platform Restore from Backup

**Prerequisites:**
- Access to Aurora snapshots
- Terraform state backup
- Original deployment configuration

#### Step 1: Restore Aurora Database

```bash
# List available snapshots
aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier coder-prod-aurora

# Restore from snapshot
aws rds restore-db-cluster-from-snapshot \
  --db-cluster-identifier coder-prod-aurora-restored \
  --snapshot-identifier <snapshot-id> \
  --engine aurora-postgresql \
  --engine-version 15.4 \
  --vpc-security-group-ids <security-group-id> \
  --db-subnet-group-name coder-prod-db-subnet-group

# Wait for cluster to be available
aws rds wait db-cluster-available \
  --db-cluster-identifier coder-prod-aurora-restored
```

#### Step 2: Update Terraform Configuration

```bash
# Update database endpoint in tfvars
# Or import restored cluster into Terraform state
terraform import module.aurora.aws_rds_cluster.main coder-prod-aurora-restored
```

#### Step 3: Redeploy Coder

```bash
# Apply Terraform to update Coder configuration
terraform apply -var-file=environments/prod.tfvars

# Verify Coder connectivity
kubectl logs -n coder -l app.kubernetes.io/name=coder | grep -i database
```

#### Step 4: Verify Restoration

```bash
# Check users exist
coder users list

# Check templates exist
coder templates list

# Check groups exist
coder groups list
```

### Scenario: Point-in-Time Recovery

```bash
# Restore to specific point in time
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier coder-prod-aurora \
  --db-cluster-identifier coder-prod-aurora-pitr \
  --restore-to-time "2024-01-15T10:30:00Z" \
  --vpc-security-group-ids <security-group-id> \
  --db-subnet-group-name coder-prod-db-subnet-group
```

## Scaling Procedures

### Manual Scaling - Workspace Nodes

#### Increase Capacity

```bash
# Update node group scaling
aws eks update-nodegroup-config \
  --cluster-name coder-prod \
  --nodegroup-name coder-prod-ws \
  --scaling-config minSize=20,maxSize=300,desiredSize=50

# Or update via Terraform
# In environments/prod.tfvars
# ws_node_min = 20
# ws_node_max = 300
terraform apply -var-file=environments/prod.tfvars
```

#### Decrease Capacity

```bash
# Ensure workspaces are stopped before scaling down
coder workspaces list --all | grep Running

# Scale down
aws eks update-nodegroup-config \
  --cluster-name coder-prod \
  --nodegroup-name coder-prod-ws \
  --scaling-config minSize=5,maxSize=200,desiredSize=10
```

### Adjusting Time-Based Scaling

#### Modify Schedule

```hcl
# In environments/prod.tfvars

# Scale up earlier (6:00 AM instead of 6:45 AM)
scaling_schedule_start = "0 6 * * MON-FRI"

# Scale down later (7:00 PM instead of 6:15 PM)
scaling_schedule_stop = "0 19 * * MON-FRI"

# Change timezone
scaling_timezone = "America/Los_Angeles"
```

```bash
terraform apply -var-file=environments/prod.tfvars
```

### Scaling Provisioners

#### Increase Provisioner Capacity

```bash
# For high provisioning load
aws eks update-nodegroup-config \
  --cluster-name coder-prod \
  --nodegroup-name coder-prod-prov \
  --scaling-config minSize=2,maxSize=30,desiredSize=10
```

## Monthly Backup Restore Testing

**Purpose:** Validate disaster recovery procedures monthly per Requirement 8.6.

### Step 1: Create Test Environment

```bash
# Create isolated test namespace
kubectl create namespace coder-dr-test
```

### Step 2: Restore Database to Test Cluster

```bash
# Get latest snapshot
SNAPSHOT_ID=$(aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier coder-prod-aurora \
  --query 'DBClusterSnapshots | sort_by(@, &SnapshotCreateTime) | [-1].DBClusterSnapshotIdentifier' \
  --output text)

# Restore to test cluster
aws rds restore-db-cluster-from-snapshot \
  --db-cluster-identifier coder-dr-test-aurora \
  --snapshot-identifier $SNAPSHOT_ID \
  --engine aurora-postgresql \
  --db-subnet-group-name coder-prod-db-subnet-group \
  --vpc-security-group-ids <test-security-group>
```

### Step 3: Verify Data Integrity

```bash
# Connect to restored database
psql -h coder-dr-test-aurora.cluster-xxx.us-east-1.rds.amazonaws.com \
  -U coder -d coder

# Verify tables exist
\dt

# Check user count
SELECT COUNT(*) FROM users;

# Check template count
SELECT COUNT(*) FROM templates;
```

### Step 4: Document Results

```bash
# Record test results
cat << EOF > dr-test-$(date +%Y%m%d).md
# DR Test Results - $(date +%Y-%m-%d)

## Snapshot Used
- Snapshot ID: $SNAPSHOT_ID
- Snapshot Time: $(aws rds describe-db-cluster-snapshots --db-cluster-snapshot-identifier $SNAPSHOT_ID --query 'DBClusterSnapshots[0].SnapshotCreateTime' --output text)

## Verification Results
- Database restored: ✅
- Tables present: ✅
- User count: XXX
- Template count: XXX
- Data integrity: ✅

## Recovery Time
- Restore initiated: HH:MM
- Restore completed: HH:MM
- Total time: XX minutes

## Tester
- Name: [Your Name]
- Date: $(date +%Y-%m-%d)
EOF
```

### Step 5: Cleanup

```bash
# Delete test resources
aws rds delete-db-cluster \
  --db-cluster-identifier coder-dr-test-aurora \
  --skip-final-snapshot

kubectl delete namespace coder-dr-test
```

## Operational Best Practices

### Daily Operations

1. **Monitor CloudWatch Dashboards**: Check platform health metrics
2. **Review Alerts**: Respond to CloudWatch alarms
3. **Check Workspace Status**: Verify no stuck workspaces
4. **Audit Log Review**: Check for suspicious activity

### Weekly Operations

1. **Review Capacity**: Check node utilization and adjust if needed
2. **Template Updates**: Deploy template changes as needed
3. **User Management**: Review new users and group assignments
4. **Performance Review**: Check API latency and database performance

### Monthly Operations

1. **Backup Testing**: Perform monthly DR test (required)
2. **Security Reviews**: Review IAM roles and security group rules
3. **Cost Analysis**: Review AWS costs and optimize resources
4. **Upgrade Planning**: Check for new Coder versions

### Quarterly Operations

1. **Capacity Planning**: Review growth trends and plan capacity
2. **Security Audits**: Perform comprehensive security review
3. **Template Lifecycle**: Archive unused templates
4. **Documentation Updates**: Update operational documentation

## Related Documentation

- [Day 0: Infrastructure Deployment](day0-deployment.md)
- [Day 1: Initial Configuration](day1-configuration.md)
- [Upgrade Procedures](upgrades.md)
- [Troubleshooting Guide](troubleshooting.md)
- [Architecture Overview](../getting-started/overview.md)

## Next Steps

- **Upgrades**: Review [Upgrade Procedures](upgrades.md) when updates are available
- **Issues**: Consult [Troubleshooting Guide](troubleshooting.md) for common problems
- **Optimization**: Review architecture patterns for improvements

---

*Document Version: 1.0*
*Last Updated: December 2024*
*Maintained by: Platform Engineering Team*
