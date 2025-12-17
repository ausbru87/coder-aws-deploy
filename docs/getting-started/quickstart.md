# 60-Minute SR-HA Deployment Quickstart

This guide provides a streamlined path to deploying the SR-HA pattern in approximately 60 minutes.

## Prerequisites (10 minutes)

Ensure you have:
1. AWS account with admin access
2. Terraform >= 1.5.0 installed
3. AWS CLI configured
4. kubectl and helm installed
5. Domain name with Route 53 hosted zone
6. OIDC provider configured (Azure AD, Okta, Google)

See [full prerequisites](./prerequisites.md) for details.

## Quick Deployment (45 minutes)

### Step 1: Clone and Configure (5 minutes)

```bash
# Clone repository
git clone <repository-url>
cd aws-arch-SR-v1/terraform

# Copy SR-HA pattern
cp patterns/sr-ha.tfvars my-deployment.tfvars

# Edit with your values
vim my-deployment.tfvars
```

**Critical values to set:**
- `owner` - Your team name
- `base_domain` - Your domain (example.com)
- `oidc_issuer_url` - Your IDP URL
- `oidc_client_id` - OAuth client ID
- `oidc_client_secret_arn` - Secrets Manager ARN

### Step 2: Initialize Terraform (2 minutes)

```bash
# Configure backend (first time only)
vim backend-config/prod.hcl  # Add your S3 bucket

# Initialize
terraform init -backend-config=backend-config/prod.hcl
```

### Step 3: Deploy Infrastructure (30 minutes)

```bash
# Validate configuration
terraform validate

# Plan deployment
terraform plan -var-file=my-deployment.tfvars

# Deploy (takes ~25-30 minutes)
terraform apply -var-file=my-deployment.tfvars
```

**What's being created:**
- VPC with 3 availability zones
- EKS cluster with 3 node groups
- Aurora PostgreSQL Serverless v2
- Network Load Balancer with TLS
- CloudWatch logging and monitoring

### Step 4: Configure Access (5 minutes)

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name coder-prod

# Verify Coder is running
kubectl get pods -n coder

# Get Coder URL (from Terraform outputs)
terraform output coder_url
```

### Step 5: Initial Configuration (3 minutes)

1. Navigate to your Coder URL
2. Create first owner account via OIDC
3. Verify authentication works

## Post-Deployment Checklist

After deployment completes:

- [ ] Coder pods running (2 replicas)
- [ ] Database healthy
- [ ] NLB targets healthy
- [ ] DNS resolving correctly
- [ ] OIDC authentication working
- [ ] Can create test workspace

## Next Steps

1. **Deploy templates:** [Day 1 Configuration](../operations/day1-configuration.md)
2. **Configure RBAC:** [RBAC Guide](../configuration/rbac.md)
3. **Set up monitoring:** [Day 1 Configuration](../operations/day1-configuration.md#monitoring)
4. **Run scale tests:** [Scaling Guide](../operations/scaling.md)

## Troubleshooting

If you encounter issues:
1. Check Terraform output for errors
2. Verify AWS quotas: `cd modules/quota-validation && ./scripts/check-quotas.sh`
3. Review pod logs: `kubectl logs -n coder -l app.kubernetes.io/name=coder`
4. See [Troubleshooting Guide](../operations/troubleshooting.md)

## Full Documentation

For comprehensive deployment procedures, see:
- [Day 0: Infrastructure Deployment](../operations/day0-deployment.md)
- [Day 1: Initial Configuration](../operations/day1-configuration.md)
- [SR-HA Deployment Guide](../deployment-patterns/sr-ha/deployment.md)

---

*Estimated time: 60 minutes (infrastructure provisioning is ~30 minutes)*
