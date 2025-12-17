# Troubleshooting Guide

This guide provides solutions for common error scenarios, template composition issues, and useful debug commands for the Coder platform.

**Target Audience:** DevSecOps Engineers L1-5, SysAdmins L3-L6

## Table of Contents

1. [Common Error Scenarios](#common-error-scenarios)
2. [Template Composition Troubleshooting](#template-composition-troubleshooting)
3. [Useful Debug Commands](#useful-debug-commands)

## Common Error Scenarios

### Pods Stuck in Pending State

**Symptoms:**
- Workspace pods remain in `Pending` state
- `kubectl get pods -n coder-ws` shows pods not scheduling

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n coder-ws

# Common causes:
# - Insufficient node capacity
# - Node taints not tolerated
# - Resource requests exceed available
```

**Resolution:**

*Insufficient Nodes:*
```bash
# Check node group scaling
aws eks describe-nodegroup \
  --cluster-name coder-prod \
  --nodegroup-name coder-prod-ws

# Scale up if needed
aws eks update-nodegroup-config \
  --cluster-name coder-prod \
  --nodegroup-name coder-prod-ws \
  --scaling-config desiredSize=20
```

*Taint Issues:*
```bash
# Verify pod tolerations match node taints
kubectl get nodes -l node-group=coder-ws -o jsonpath='{.items[*].spec.taints}'

# Check workspace template includes correct tolerations
```

### Database Connection Errors

**Symptoms:**
- Coder pods crash with database errors
- `kubectl logs` shows connection refused

**Diagnosis:**
```bash
# Check coderd logs
kubectl logs -n coder -l app.kubernetes.io/name=coder | grep -i database

# Verify Aurora cluster status
aws rds describe-db-clusters --db-cluster-identifier coder-prod-aurora

# Check security group rules
aws ec2 describe-security-groups --group-ids <rds-sg-id>
```

**Resolution:**

*Security Group Issue:*
```bash
# Verify node security group can reach RDS on port 5432
aws ec2 authorize-security-group-ingress \
  --group-id <rds-sg-id> \
  --protocol tcp \
  --port 5432 \
  --source-group <node-sg-id>
```

*Credentials Issue:*
```bash
# Verify secret exists
kubectl get secret -n coder coder-db-credentials

# Check secret contents (base64 encoded)
kubectl get secret -n coder coder-db-credentials -o jsonpath='{.data.password}' | base64 -d
```

### OIDC Authentication Failures

**Symptoms:**
- Users cannot log in
- Redirect loop or error page

**Diagnosis:**
```bash
# Check OIDC configuration
kubectl exec -it deploy/coder -n coder -- env | grep OIDC

# Check coderd logs for auth errors
kubectl logs -n coder -l app.kubernetes.io/name=coder | grep -i oidc

# Test OIDC discovery endpoint
curl -s "${OIDC_ISSUER_URL}/.well-known/openid-configuration" | jq .
```

**Resolution:**

*Incorrect Redirect URI:*
```bash
# Verify callback URL in IDP matches Coder URL
# Expected: https://coder.example.com/api/v2/users/oidc/callback
```

*Missing Scopes:*
```bash
# Ensure OIDC scopes include: openid, profile, email, groups
# Check Helm values for CODER_OIDC_SCOPES
```

### Workspace Provisioning Timeouts

**Symptoms:**
- Workspaces fail to start
- Provisioner logs show timeout errors

**Diagnosis:**
```bash
# Check provisioner logs
kubectl logs -n coder-prov -l app.kubernetes.io/name=coder-provisioner

# Check provisioner key validity
# Keys expire after 90 days

# Check Terraform provider errors in logs
```

**Resolution:**

*Provisioner Key Expired:*
```bash
# Rotate provisioner key
# See provisioner-key-management.md for procedure
```

*AWS API Throttling:*
```bash
# Check for rate limit errors in logs
# Reduce concurrent provisioning or request limit increase
```

### NLB Health Check Failures

**Symptoms:**
- Coder URL returns 502/503 errors
- NLB target group shows unhealthy targets

**Diagnosis:**
```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# Check coderd health endpoint
kubectl exec -it deploy/coder -n coder -- curl localhost:3000/healthz
```

**Resolution:**

*Health Check Path:*
```bash
# Verify health check configuration
# Path should be /healthz
# Port should match coderd service port
```

*Pod Not Ready:*
```bash
# Check pod readiness
kubectl get pods -n coder -l app.kubernetes.io/name=coder

# Check readiness probe
kubectl describe pod <pod-name> -n coder | grep -A 10 "Readiness:"
```

## Template Composition Troubleshooting

### Contract Validation Failures

**Symptoms:**
- Template deployment fails with contract errors
- Capability mismatch errors

**Diagnosis:**
```bash
# Run contract validation
./terraform/modules/coder/template-architecture/ci-cd/scripts/contract-check.sh

# Check toolchain capabilities vs base capabilities
cat terraform/modules/coder/template-architecture/toolchains/swdev-toolchain/toolchain.yaml
cat terraform/modules/coder/template-architecture/contract/capabilities.yaml
```

**Resolution:**

*Missing Capability:*
```bash
# Ensure infrastructure base implements required capability
# Update base module to support the capability
# Or remove capability requirement from toolchain
```

*Version Mismatch:*
```bash
# Check contract version compatibility
# Toolchain and base must use compatible contract versions
```

### Template Not Appearing in Coder

**Symptoms:**
- Template deployed via Terraform but not visible in Coder UI

**Diagnosis:**
```bash
# Check coderd_template resource
terraform state show module.coder.coderd_template.pod_swdev

# Check Coder API
curl -H "Coder-Session-Token: $TOKEN" \
  https://coder.example.com/api/v2/templates
```

**Resolution:**

*ACL Issue:*
```bash
# Verify template ACL grants access to users
terraform state show module.coder.coderd_template_acl.pod_swdev

# Update ACL to include appropriate groups
```

*Organization Mismatch:*
```bash
# Ensure template is in correct organization
# Check organization_id in coderd_template resource
```

## Useful Debug Commands

### Coder Logs

```bash
# All coderd logs
kubectl logs -n coder -l app.kubernetes.io/name=coder -f

# Provisioner logs
kubectl logs -n coder-prov -l app.kubernetes.io/name=coder-provisioner -f

# Specific pod logs
kubectl logs -n coder <pod-name> --previous  # Previous container logs
```

### Kubernetes Debugging

```bash
# Pod details
kubectl describe pod <pod-name> -n <namespace>

# Events
kubectl get events -n coder --sort-by='.lastTimestamp'

# Resource usage
kubectl top pods -n coder
kubectl top nodes
```

### AWS Debugging

```bash
# EKS cluster issues
aws eks describe-cluster --name coder-prod

# Node group issues
aws eks describe-nodegroup --cluster-name coder-prod --nodegroup-name coder-prod-ws

# Aurora issues
aws rds describe-db-clusters --db-cluster-identifier coder-prod-aurora
aws rds describe-events --source-identifier coder-prod-aurora --source-type db-cluster
```

### Network Debugging

```bash
# Test connectivity from pod
kubectl exec -it deploy/coder -n coder -- curl -v https://coder.example.com/healthz

# DNS resolution
kubectl exec -it deploy/coder -n coder -- nslookup coder-prod-aurora.cluster-xxx.us-east-1.rds.amazonaws.com

# Check VPC endpoints
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=<vpc-id>"
```

### Coder CLI Debugging

```bash
# Enable verbose logging
export CODER_VERBOSE=true

# Check workspace status
coder list

# Get workspace details
coder show <workspace-name>

# Check workspace logs
coder logs <workspace-name>

# SSH to workspace with debug
coder ssh <workspace-name> --log-dir /tmp/coder-debug
```

### Database Debugging

```bash
# Connect to Aurora from pod
kubectl exec -it deploy/coder -n coder -- psql -h <aurora-endpoint> -U coder -d coder

# Check active connections
SELECT count(*) FROM pg_stat_activity;

# Check for long-running queries
SELECT pid, now() - pg_stat_activity.query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY duration DESC;

# Check database size
SELECT pg_size_pretty(pg_database_size('coder'));
```

### Terraform Debugging

```bash
# Enable debug logging
export TF_LOG=DEBUG
export TF_LOG_PATH=/tmp/terraform.log

# Check state
terraform show

# Refresh state
terraform refresh -var-file=environments/prod.tfvars

# Target specific resource
terraform plan -var-file=environments/prod.tfvars -target=module.coder
```

## Common Log Patterns

### Success Patterns

```
# Successful startup
"msg": "started provisioner daemon"
"msg": "successfully connected to database"
"msg": "HTTP server listening"

# Successful workspace creation
"msg": "workspace build completed"
"status": "succeeded"
```

### Error Patterns

```
# Database connection errors
"error": "connection refused"
"error": "database timeout"

# Provisioning errors
"error": "terraform plan failed"
"error": "AWS API rate limit"

# Authentication errors
"error": "OIDC callback failed"
"error": "token expired"
```

## Escalation Path

### Level 1: Self-Service
- Review this troubleshooting guide
- Check CloudWatch logs and dashboards
- Review pod events and logs

### Level 2: Team Support
- Share logs and error messages with team
- Review recent changes or deployments
- Check for known issues in team documentation

### Level 3: Vendor Support
- Open ticket with Coder Premium Support
- Provide detailed logs and reproduction steps
- Include environment configuration (sanitized)

## Scale Testing Troubleshooting

This section covers common issues encountered during scale testing and performance validation.

### Common Issues

1. **Workspace Creation Timeouts**
   - Check node autoscaling status
   - Verify AWS quotas (EC2, EBS)
   - Review provisioner logs: `kubectl logs -n coder-prov -l app=coder-provisioner`

2. **High API Latency**
   - Check coderd pod resources
   - Review database connection pool
   - Check NLB target health

3. **Network Test Failures**
   - Verify security group rules
   - Check NAT Gateway capacity
   - Review VPC endpoint status

### Log Collection for Scale Tests

```bash
# Collect coderd logs during test
kubectl logs -n coder -l app.kubernetes.io/name=coder --since=1h > coderd-logs.txt

# Collect provisioner logs
kubectl logs -n coder-prov -l app=coder-provisioner --since=1h > provisioner-logs.txt

# Collect events
kubectl get events -n coder --sort-by='.lastTimestamp' > coder-events.txt
```

For comprehensive scale testing procedures, see [Scaling and Performance Testing Guide](./scaling.md).

## Related Documentation

- [Day 0: Infrastructure Deployment](day0-deployment.md)
- [Day 1: Initial Configuration](day1-configuration.md)
- [Day 2: Ongoing Operations](day2-operations.md)
- [Upgrade Procedures](upgrades.md)
- [Architecture Overview](../getting-started/overview.md)

## External Resources

- [Coder Troubleshooting](https://coder.com/docs/admin/troubleshooting)
- [EKS Troubleshooting](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
- [Aurora Troubleshooting](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/CHAP_Troubleshooting.html)

---

*Document Version: 1.0*
*Last Updated: December 2024*
*Maintained by: Platform Engineering Team*
