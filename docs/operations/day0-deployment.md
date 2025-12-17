# Day 0: Infrastructure Deployment

This guide provides step-by-step instructions for deploying the Coder platform infrastructure on AWS EKS. Day 0 covers the initial deployment from environment preparation through verification of the running platform.

**Target Audience:** DevSecOps Engineers L1-5, SysAdmins L3-L6

**Estimated Time:** 30-45 minutes

## Table of Contents

1. [Phase 1: Prepare Deployment Environment](#phase-1-prepare-deployment-environment)
2. [Phase 2: Configure Variables](#phase-2-configure-variables)
3. [Phase 3: Deploy Infrastructure](#phase-3-deploy-infrastructure)
4. [Phase 4: Configure Kubernetes Access](#phase-4-configure-kubernetes-access)
5. [Phase 5: Verify Coder Deployment](#phase-5-verify-coder-deployment)

## Prerequisites

Before beginning deployment, ensure you have completed:
- All prerequisites from [Prerequisites and Quota Requirements](../getting-started/prerequisites.md)
- Review of [Architecture Overview](../getting-started/overview.md)

## Phase 1: Prepare Deployment Environment

### Step 1.1: Clone Repository

```bash
# Clone the IaC repository
git clone https://github.com/your-org/coder-infrastructure.git
cd coder-infrastructure/terraform
```

### Step 1.2: Run Pre-flight Checks

```bash
# Run quota validation
./modules/quota-validation/scripts/preflight-check.sh

# Expected output: All quotas sufficient
# If quotas insufficient, request increases before proceeding
```

### Step 1.3: Configure Backend

```bash
# First-time setup: Create S3 bucket for state
aws s3 mb s3://your-org-coder-terraform-state --region us-east-1

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name coder-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# Update backend-config/prod.hcl with your bucket name
```

### Step 1.4: Initialize Terraform

```bash
# Initialize with backend configuration
terraform init -backend-config=backend-config/prod.hcl

# Verify initialization
terraform providers
```

## Phase 2: Configure Variables

### Step 2.1: Create Variables File

```bash
# Copy example configuration
cp environments/prod.tfvars.example environments/prod.tfvars

# Edit with your values
vim environments/prod.tfvars
```

### Step 2.2: Required Variables

```hcl
# environments/prod.tfvars

# Naming
environment = "prod"
project     = "coder"

# Networking
base_domain         = "example.com"
vpc_cidr            = "10.0.0.0/16"
availability_zones  = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Certificates
acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abc123"

# OIDC Authentication
oidc_issuer_url        = "https://login.microsoftonline.com/tenant-id/v2.0"
oidc_client_id         = "your-client-id"
oidc_client_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:coder-oidc-secret"

# Coder License
coder_license_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:coder-license"

# Scaling
max_workspaces         = 3000
max_workspaces_per_user = 3

# Git Provider (for external auth)
git_provider           = "github"
git_client_id          = "your-github-oauth-app-id"
git_client_secret_arn  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:github-oauth"
```

### Step 2.3: Store Secrets in Secrets Manager

```bash
# Store OIDC client secret
aws secretsmanager create-secret \
  --name coder-oidc-secret \
  --secret-string "your-oidc-client-secret"

# Store Coder license
aws secretsmanager create-secret \
  --name coder-license \
  --secret-string "your-coder-license-key"

# Store Git OAuth secret
aws secretsmanager create-secret \
  --name github-oauth \
  --secret-string "your-github-oauth-secret"
```

## Phase 3: Deploy Infrastructure

### Step 3.1: Plan Deployment

```bash
# Generate and review plan
terraform plan -var-file=environments/prod.tfvars -out=tfplan

# Review the plan carefully
# Expected resources: ~150-200 resources
```

### Step 3.2: Apply Infrastructure

```bash
# Apply the plan
terraform apply tfplan

# This will take approximately 30-45 minutes
# Major components:
# - VPC and networking: ~5 min
# - EKS cluster: ~15 min
# - Aurora database: ~10 min
# - Coder deployment: ~5 min
```

### Step 3.3: Validate Infrastructure

```bash
# Get outputs
terraform output

# Verify VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=coder-prod-vpc"

# Verify EKS cluster
aws eks describe-cluster --name coder-prod

# Verify Aurora cluster
aws rds describe-db-clusters --db-cluster-identifier coder-prod-aurora
```

## Phase 4: Configure Kubernetes Access

### Step 4.1: Update kubeconfig

```bash
# Update kubeconfig for the new cluster
aws eks update-kubeconfig --region us-east-1 --name coder-prod

# Verify access
kubectl cluster-info
kubectl get nodes
```

### Step 4.2: Verify Node Groups

```bash
# Check all node groups are ready
kubectl get nodes -l node-group=coder-control
kubectl get nodes -l node-group=coder-prov
kubectl get nodes -l node-group=coder-ws

# Verify taints
kubectl describe nodes | grep -A 5 "Taints:"
```

### Step 4.3: Verify Namespaces

```bash
# Check namespaces created
kubectl get namespaces | grep coder

# Expected:
# coder        Active
# coder-prov   Active
# coder-ws     Active
```

## Phase 5: Verify Coder Deployment

### Step 5.1: Check Coder Pods

```bash
# Check coderd pods
kubectl get pods -n coder -l app.kubernetes.io/name=coder

# Expected: 2+ pods in Running state

# Check provisioner pods
kubectl get pods -n coder-prov -l app.kubernetes.io/name=coder-provisioner

# Check logs for errors
kubectl logs -n coder -l app.kubernetes.io/name=coder --tail=100
```

### Step 5.2: Verify Database Connectivity

```bash
# Check coderd can connect to Aurora
kubectl logs -n coder -l app.kubernetes.io/name=coder | grep -i database

# Should see successful connection messages
```

### Step 5.3: Verify Load Balancer

```bash
# Get NLB DNS name
kubectl get svc -n coder coder -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Verify DNS resolution
dig coder.example.com

# Test HTTPS connectivity
curl -I https://coder.example.com/api/v2/buildinfo
```

## Deployment Complete

Congratulations! Your Coder infrastructure is now deployed. The platform is ready for initial configuration.

## Next Steps

1. [Day 1: Initial Configuration](day1-configuration.md) - Configure the platform, create owner account, deploy templates
2. [Day 2: Ongoing Operations](day2-operations.md) - Learn about daily operations and maintenance

## Troubleshooting

If you encounter issues during deployment, see:
- [Troubleshooting Guide](troubleshooting.md)
- Common deployment errors and solutions
- Debug commands and diagnostics

## Related Documentation

- [Prerequisites and Quota Requirements](../getting-started/prerequisites.md)
- [Architecture Overview](../getting-started/overview.md)
- [Day 1: Initial Configuration](day1-configuration.md)
- [Day 2: Ongoing Operations](day2-operations.md)
- [Troubleshooting Guide](troubleshooting.md)

---

*Document Version: 1.0*
*Last Updated: December 2024*
*Maintained by: Platform Engineering Team*
