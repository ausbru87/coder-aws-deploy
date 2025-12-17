# Frequently Asked Questions (FAQ)

## General Questions

### What is Coder?

Coder is a cloud development environment (CDE) platform that enables software teams to provision consistent, reproducible development environments in the cloud. Developers access fully-featured workspaces via browser or local IDE (VS Code, JetBrains).

### What is this repository?

This repository provides production-ready Terraform infrastructure for deploying Coder on AWS. It includes multiple deployment patterns (SR-HA, SR-Simple) optimized for different use cases and team sizes.

### How is this different from Coder's official documentation?

Coder's official docs cover general Coder deployment. This repository provides AWS-specific, battle-tested infrastructure patterns with:
- Complete Terraform modules
- Feature flag architecture for pattern composition
- Cost optimization (time-based scaling, spot instances)
- Enterprise features (future patterns)

### Do I need a Coder license?

Yes. Coder offers:
- **Free tier:** Up to 5 users
- **Enterprise license:** Contact Coder sales for pricing

This infrastructure works with all Coder license tiers.

## Deployment Pattern Selection

### Which pattern should I choose?

See [Choosing a Pattern](../getting-started/choosing-a-pattern.md) for a detailed decision guide.

**Quick guide:**
- **Development/testing:** SR-Simple (<20 users, <$1,000/month)
- **Production:** SR-HA (100-500 users, $2,500-4,000/month)

### Can I combine multiple patterns?

Yes! Feature flags allow composition:
```hcl
deployment_features = {
  high_availability      = true   # SR-HA base
}
```

### Can I migrate between patterns?

Yes, but with caveats:
- **SR-Simple → SR-HA:** Requires brief downtime for AZ migration (~15-30 min)

See upgrade documentation for migration procedures.

## Cost & Capacity

### How much does SR-HA cost?

**Estimated monthly cost:** $2,500-4,000 (varies by usage)

**Cost drivers:**
- EC2 instances (40-50% of cost)
- Aurora Serverless v2 (15-20%)
- NAT Gateway + data transfer (10-15%)
- EKS control plane + other services (20-25%)

See [Cost Estimation](./cost-estimation.md) for detailed breakdowns.

### How many users can SR-HA support?

**Capacity:**
- **Tested:** 100-500 concurrent users
- **Theoretical max:** 3,000 workspaces (with capacity planning)

**Bottlenecks:**
- Workspace node capacity (max 200 nodes × 15 workspaces/node)
- Aurora ACU capacity (max 16 ACU ~= 500 concurrent connections)
- Provisioner throughput (~50 concurrent provisions)

### Does time-based scaling work for global teams?

No. Time-based scaling assumes business-hours usage (e.g., 9am-6pm Eastern). For global teams:
- OR disable time-based scaling and use static capacity

### Can I use Reserved Instances or Savings Plans?

**Recommended:**
- ✅ Reserve control plane nodes (100% utilization)
- ❌ Don't reserve provisioner/workspace nodes (variable usage with time-based scaling)

**Savings:**
- 1-year reserved: ~30% discount
- 3-year reserved: ~50% discount

## Technical Questions

### Why EKS instead of ECS?

- **Coder native support:** First-class Kubernetes provider
- **Flexibility:** Support for both Kubernetes pods and EC2 workspaces
- **Ecosystem:** Rich tooling (Helm, Kustomize, operators)

See [ADR-007](./architecture-decisions.md#adr-007-kubernetes-over-ecs-for-workspace-orchestration).

### Why Aurora Serverless v2?

- **Cost savings:** ~60% cheaper for variable workloads (scales down during off-hours)
- **Automatic scaling:** No manual capacity planning
- **Quick scaling:** Scales in seconds vs minutes for provisioned Aurora

See [ADR-002](./architecture-decisions.md#adr-002-aurora-serverless-v2-over-provisioned-aurora).

### Can I use an existing VPC?

Yes, but requires modifications:
1. Update `modules/vpc/` to accept existing VPC ID
2. Ensure subnets meet requirements (5 subnet tiers)
3. Configure security groups for EKS, Aurora, load balancer

This is not currently supported out-of-the-box but is on the roadmap.

### Can I use an existing Aurora cluster?

Yes, but:
1. Must be PostgreSQL 13+ (preferably 16.4)
2. Must be accessible from EKS nodes
3. Update `modules/aurora/` to accept existing cluster endpoint

Alternatively, use the `db_snapshot_identifier` variable to restore from an existing snapshot.

### Can I deploy multiple Coder instances in one AWS account?

Yes! Use different:
- `project_name` variable (e.g., "coder-dev", "coder-prod")
- VPC CIDR blocks (avoid overlap)
- S3 backend keys (different Terraform state files)

```hcl
# backend.hcl for prod
bucket = "my-terraform-state"
key    = "coder-prod/terraform.tfstate"

# backend.hcl for dev
bucket = "my-terraform-state"
key    = "coder-dev/terraform.tfstate"
```

### How do I update Coder to a new version?

See [Upgrade Procedures](../operations/upgrades.md#coder-version-upgrade).

**Summary:**
1. Update Helm chart version in `modules/coder/main.tf`
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to update
4. Verify deployment: `kubectl get pods -n coder`

**Downtime:** <2 minutes (rolling update)

### Can I use AWS Fargate for workspace nodes?

No. Coder workspaces require:
- Persistent volumes (EBS)
- Privileged containers (for Docker-in-Docker)
- Custom networking (for workspace isolation)

Fargate doesn't support these requirements. Use EKS with EC2 worker nodes.

## Security & Compliance

### Is this deployment secure?

**Standard security features (all patterns):**
- Encryption at rest (EBS, Aurora, S3)
- Encryption in transit (TLS 1.2+)
- Private subnets for workspaces
- Security groups with least privilege
- IAM roles with least privilege (IRSA)

### Does this meet HIPAA/PCI DSS/FedRAMP requirements?

**FedRAMP Moderate:**
- Requires additional AWS services (AWS GovCloud, etc.)
- Contact Coder sales for FedRAMP-specific guidance

### How are credentials managed?

**Coder credentials:**
- Stored in Kubernetes secrets (encrypted with KMS)
- Alternatively: AWS Secrets Manager with External Secrets Operator

**AWS credentials:**
- IRSA (IAM Roles for Service Accounts) for pods
- No long-lived IAM access keys

**User credentials:**
- OIDC/SAML authentication (no passwords in Coder)
- GitHub, Google, Okta, Azure AD supported

### Can workspaces access the internet?

**By default:**
- ✅ Outbound internet access via NAT Gateway (for package downloads, git clone, etc.)
- ❌ No inbound internet access (workspaces are in private subnets)

**Custom restrictions:**
- Use Kubernetes NetworkPolicies to restrict workspace egress
- Use security groups to limit outbound traffic

## Troubleshooting

### Workspace provisioning is slow (>2 minutes)

**Common causes:**
1. **Insufficient provisioner capacity:** Scale up provisioner nodes
   ```bash
   kubectl scale deployment coder-provisioner-default -n coder --replicas=8
   ```

2. **Spot instance unavailability:** Check spot fulfillment
   ```bash
   aws ec2 describe-spot-instance-requests --filters Name=state,Values=open
   ```

3. **Image pull delays:** Use larger workspace nodes or image caching

See [Troubleshooting Guide](../operations/troubleshooting.md#workspace-provisioning-slow).

### Database connection errors

**Common causes:**
1. **Aurora scaling:** Check if ACU is at max capacity (16 ACU)
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/RDS \
     --metric-name ServerlessDatabaseCapacity \
     --dimensions Name=DBClusterIdentifier,Value=<cluster-id>
   ```

2. **Connection pool exhaustion:** Restart coderd pods
   ```bash
   kubectl rollout restart deployment/coder-server -n coder
   ```

3. **Security group misconfiguration:** Verify EKS nodes can reach Aurora
   ```bash
   kubectl run -it --rm debug --image=busybox --restart=Never -- \
     nc -zv <aurora-endpoint> 5432
   ```

### Terraform apply fails with "QuotaExceededException"

**Cause:** AWS service quota limits exceeded

**Solution:**
1. Identify the quota limit:
   ```bash
   aws service-quotas list-service-quotas --service-code ec2 | grep -A5 "Running On-Demand"
   ```

2. Request quota increase:
   ```bash
   aws service-quotas request-service-quota-increase \
     --service-code ec2 \
     --quota-code L-1216C47A \
     --desired-value 100
   ```

3. Wait for approval (typically 24-48 hours)

See [Prerequisites](../getting-started/prerequisites.md#aws-service-quotas).

### How do I get support?

1. **Documentation:** Check this documentation first
2. **GitHub Issues:** Report bugs or request features at [GitHub repository]
3. **Coder Community:** Join Coder Discord for community support
4. **Enterprise Support:** Contact Coder sales for paid support plans

## Roadmap

### When will SR-Simple be available?

**Target:** v2.0 (Q2 2025)

Currently in planning. SR-HA (v1.0) is production-ready.


**Target:** v2.0 (Q3 2025)

Requires:
- AWS Config rule implementation
- GuardDuty + Security Hub integration
- VPC endpoint automation

### Can I contribute?

Yes! Contributions welcome:
- Bug fixes
- Documentation improvements
- New features (coordinate via GitHub issues first)
- Pattern examples

See CONTRIBUTING.md (if it exists) for guidelines.

## Related Documentation

- [Getting Started](../getting-started/quickstart.md)
- [Choosing a Pattern](../getting-started/choosing-a-pattern.md)
- [Troubleshooting Guide](../operations/troubleshooting.md)
- [Cost Estimation](./cost-estimation.md)
- [Architecture Decisions](./architecture-decisions.md)
