# Upgrade Procedures

This guide provides step-by-step procedures for upgrading various components of the Coder platform, including Coder version, EKS cluster, toolchain templates, and infrastructure base modules.

**Target Audience:** DevSecOps Engineers L1-5, SysAdmins L3-L6

## Table of Contents

1. [Upgrading Coder Version](#upgrading-coder-version)
2. [Upgrading EKS Cluster Version](#upgrading-eks-cluster-version)
3. [Upgrading Toolchain Templates](#upgrading-toolchain-templates)
4. [Upgrading Infrastructure Base Modules](#upgrading-infrastructure-base-modules)

## Prerequisites

- Platform running and accessible
- Terraform state access
- Kubectl access to cluster
- Backup of current configuration

## Upgrading Coder Version

### Step 1: Review Release Notes

```bash
# Check current version
coder version

# Review release notes at https://github.com/coder/coder/releases
```

### Step 2: Update Terraform Variables

```hcl
# In environments/prod.tfvars
coder_version = "2.16.0"  # New version
```

### Step 3: Plan and Apply

```bash
# Plan upgrade
terraform plan -var-file=environments/prod.tfvars

# Review changes (should only affect Helm release)

# Apply during maintenance window
terraform apply -var-file=environments/prod.tfvars
```

### Step 4: Verify Upgrade

```bash
# Check new version
coder version

# Verify pods restarted
kubectl get pods -n coder -l app.kubernetes.io/name=coder

# Check logs for errors
kubectl logs -n coder -l app.kubernetes.io/name=coder --tail=100
```

## Upgrading EKS Cluster Version

### Step 1: Review Compatibility

```bash
# Check current version
kubectl version

# Review EKS upgrade documentation
# https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html
```

### Step 2: Update Control Plane

```hcl
# In environments/prod.tfvars
eks_cluster_version = "1.30"  # New version
```

```bash
# Apply control plane upgrade
terraform apply -var-file=environments/prod.tfvars -target=module.eks.aws_eks_cluster.main
```

### Step 3: Update Node Groups

```bash
# Update node groups one at a time
terraform apply -var-file=environments/prod.tfvars -target=module.eks.aws_eks_node_group.control
terraform apply -var-file=environments/prod.tfvars -target=module.eks.aws_eks_node_group.provisioner
terraform apply -var-file=environments/prod.tfvars -target=module.eks.aws_eks_node_group.workspace
```

### Step 4: Update Add-ons

```bash
# Update EKS add-ons
terraform apply -var-file=environments/prod.tfvars
```

## Upgrading Toolchain Templates

### Step 1: Update Toolchain Version

```bash
# In template composition module
cd terraform/modules/coder/template-architecture/composition

# Update toolchain version reference
# toolchain_version = "v1.3.0"
```

### Step 2: Validate Contract

```bash
# Run contract validation
./terraform/modules/coder/template-architecture/ci-cd/scripts/contract-check.sh
```

### Step 3: Deploy Updated Templates

```bash
# Apply template changes
terraform apply -var-file=environments/prod.tfvars -target=module.coder.coderd_template
```

## Upgrading Infrastructure Base Modules

### Step 1: Update Base Module Version

```bash
# Update base module reference in composition
# base_version = "v3.2.0"
```

### Step 2: Test in Non-Production

```bash
# Deploy to staging first
terraform workspace select staging
terraform apply -var-file=environments/staging.tfvars
```

### Step 3: Deploy to Production

```bash
terraform workspace select prod
terraform apply -var-file=environments/prod.tfvars
```

## Upgrade Best Practices

### Pre-Upgrade Checklist

- [ ] Review release notes and breaking changes
- [ ] Backup current configuration and state
- [ ] Take Aurora snapshot before upgrade
- [ ] Schedule maintenance window
- [ ] Notify users of planned downtime
- [ ] Verify rollback procedure

### During Upgrade

- Monitor CloudWatch logs for errors
- Watch pod status during rollout
- Check health endpoints continuously
- Be prepared to rollback if issues occur

### Post-Upgrade Validation

```bash
# Verify platform health
curl -I https://coder.example.com/api/v2/buildinfo

# Check all pods running
kubectl get pods -n coder
kubectl get pods -n coder-prov

# Test workspace creation
coder create test-upgrade --template pod-swdev
coder ssh test-upgrade
coder delete test-upgrade --yes

# Verify database connectivity
kubectl logs -n coder -l app.kubernetes.io/name=coder | grep -i database

# Check for errors in logs
kubectl logs -n coder -l app.kubernetes.io/name=coder --tail=100 | grep -i error
```

## Rollback Procedures

### Rolling Back Coder Version

```bash
# Revert to previous version in tfvars
coder_version = "2.15.0"  # Previous version

# Apply rollback
terraform apply -var-file=environments/prod.tfvars

# Verify rollback
coder version
```

### Rolling Back EKS Cluster Version

```bash
# EKS cluster version cannot be downgraded
# Rollback requires restoring from backup or redeploying
# See Platform Restore Procedures in day2-operations.md
```

### Rolling Back Template Changes

```bash
# Revert template version in Terraform
# toolchain_version = "v1.2.0"  # Previous version

# Apply rollback
terraform apply -var-file=environments/prod.tfvars -target=module.coder.coderd_template
```

## Troubleshooting Upgrades

### Upgrade Fails to Apply

**Diagnosis:**
```bash
# Check Terraform state
terraform show

# Check for resource locks
aws dynamodb get-item \
  --table-name coder-terraform-locks \
  --key '{"LockID":{"S":"coder-prod/terraform.tfstate"}}'
```

**Resolution:**
- Review error messages carefully
- Check AWS service quotas haven't been exceeded
- Verify IAM permissions are still valid
- Consider using targeted applies to isolate issues

### Pods Fail to Start After Upgrade

**Diagnosis:**
```bash
# Check pod status
kubectl get pods -n coder -l app.kubernetes.io/name=coder

# Check pod events
kubectl describe pod <pod-name> -n coder

# Check logs
kubectl logs <pod-name> -n coder
```

**Resolution:**
- Verify image pull succeeds
- Check for configuration errors
- Review database migration logs
- Consider rolling back if critical

### Database Migration Fails

**Diagnosis:**
```bash
# Check migration logs
kubectl logs -n coder -l app.kubernetes.io/name=coder | grep -i migrat

# Check database connectivity
kubectl exec -it deploy/coder -n coder -- env | grep DATABASE
```

**Resolution:**
- Review migration error messages
- Check Aurora cluster status
- Verify security group rules
- Consider restoring from pre-upgrade snapshot

## Related Documentation

- [Day 0: Infrastructure Deployment](day0-deployment.md)
- [Day 1: Initial Configuration](day1-configuration.md)
- [Day 2: Ongoing Operations](day2-operations.md)
- [Troubleshooting Guide](troubleshooting.md)
- [Architecture Overview](../getting-started/overview.md)

## External References

- [Coder Upgrade Guide](https://coder.com/docs/admin/upgrade)
- [EKS Cluster Upgrade](https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html)
- [Aurora Version Upgrades](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Updating.html)

---

*Document Version: 1.0*
*Last Updated: December 2024*
*Maintained by: Platform Engineering Team*
