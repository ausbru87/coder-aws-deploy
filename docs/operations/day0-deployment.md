# Day 0: Infrastructure Deployment

This guide provides step-by-step instructions for deploying the Coder platform infrastructure on AWS EKS. Day 0 covers the initial deployment from environment preparation through verification of the running platform.

**Target Audience:** DevSecOps Engineers L1-5, SysAdmins L3-L6

**Estimated Time:** 60-90 minutes (including OIDC setup)

## Table of Contents

1. [Before You Begin](#before-you-begin)
2. [Phase 1: Prepare Authentication and Secrets](#phase-1-prepare-authentication-and-secrets)
3. [Phase 2: Prepare Deployment Environment](#phase-2-prepare-deployment-environment)
4. [Phase 3: Configure Variables](#phase-3-configure-variables)
5. [Phase 4: Deploy Infrastructure](#phase-4-deploy-infrastructure)
6. [Phase 5: Configure Kubernetes Access](#phase-5-configure-kubernetes-access)
7. [Phase 6: Verify Coder Deployment](#phase-6-verify-coder-deployment)

## Prerequisites

Before beginning deployment, ensure you have completed:
- All prerequisites from [Prerequisites and Quota Requirements](../getting-started/prerequisites.md)
- Review of [Architecture Overview](../getting-started/overview.md)

## Before You Begin

### ⚠️ CRITICAL: OIDC and Secrets Must Be Created First

**Do NOT skip to Phase 2.** The following must be completed before running Terraform:

1. **OIDC Application** - Must exist in your identity provider (Azure AD, Okta, Google, etc.)
2. **AWS Secrets Manager Secrets** - Terraform will fail if these don't exist
3. **Domain Configuration** - Must decide on your Coder URL before OIDC setup

### Understanding the Coder URL

Your Coder deployment URL is determined by two variables:
- `base_domain` (e.g., "example.com")
- `coder_subdomain` (e.g., "coder")

**Resulting URL:** `https://coder.example.com`

**OIDC Redirect URI:** `https://coder.example.com/api/v2/users/oidc/callback`

You need to know this URL **before** setting up OIDC in Phase 1.

## Phase 1: Prepare Authentication and Secrets

**Time Estimate:** 30-40 minutes

### Step 1.1: Set Up OIDC Application

Configure your identity provider with the Coder OIDC application. **The redirect URI must match your planned Coder URL.**

#### Azure AD / Entra ID

```bash
# Decide on your Coder URL first
# Example: base_domain="example.com", coder_subdomain="coder"
# This gives you: https://coder.example.com

# Create app registration with correct redirect URI
az ad app create \
  --display-name "Coder Platform" \
  --sign-in-audience "AzureADMyOrg" \
  --web-redirect-uris "https://coder.example.com/api/v2/users/oidc/callback"

# Note the Application (client) ID
# Create a client secret and note it
```

**Configure token claims:**
- Email
- Groups (for RBAC)
- Preferred username

**Set up Conditional Access Policy for MFA** (required)

See [Authentication Configuration Guide](../configuration/authentication.md#microsoft-entra-id-azure-ad) for complete Azure AD setup.

#### Okta

```bash
# Create OIDC application
okta apps create web \
  --app-name "Coder Platform" \
  --redirect-uri "https://coder.example.com/api/v2/users/oidc/callback"

# Configure group claims
# Set up MFA policy
```

See [Authentication Configuration Guide](../configuration/authentication.md#okta) for complete Okta setup.

**What you need from this step:**
- ✅ OIDC issuer URL
- ✅ OIDC client ID
- ✅ OIDC client secret

### Step 1.2: Create AWS Secrets Manager Secrets

**CRITICAL:** Terraform expects these secrets to exist before running `terraform plan`.

```bash
# 1. Store OIDC client secret
aws secretsmanager create-secret \
  --name coder-oidc-secret \
  --description "Coder OIDC client secret" \
  --secret-string "your-oidc-client-secret-from-step-1.1" \
  --region us-east-1

# Copy the ARN - you'll need it for oidc_client_secret_arn variable

# 2. Store Coder license (contact https://coder.com/contact for license)
aws secretsmanager create-secret \
  --name coder-license \
  --description "Coder Premium license key" \
  --secret-string "your-coder-license-key" \
  --region us-east-1

# 3. (Optional) Store Git OAuth secret for external auth
aws secretsmanager create-secret \
  --name github-oauth-secret \
  --description "GitHub OAuth app secret for Coder" \
  --secret-string "your-github-oauth-secret" \
  --region us-east-1
```

**Verify secrets exist:**
```bash
aws secretsmanager list-secrets --region us-east-1 | grep coder
```

### Step 1.3: Verify Route 53 Hosted Zone

**⚠️ REQUIRED:** A Route 53 hosted zone for your domain MUST exist before deployment.

```bash
# Verify your domain's hosted zone exists
aws route53 list-hosted-zones-by-name --dns-name example.com

# Expected output: Should show your hosted zone with HostedZoneId and Name
# If not found, create one:
# aws route53 create-hosted-zone --name example.com --caller-reference $(date +%s)

# Note the hosted zone ID (optional - Terraform can auto-lookup)
```

### Step 1.4: Request or Verify ACM Certificate (Optional)

If you want Terraform to create the certificate, skip this step.

```bash
# Request certificate with wildcard
aws acm request-certificate \
  --domain-name coder.example.com \
  --subject-alternative-names "*.coder.example.com" \
  --validation-method DNS \
  --region us-east-1

# Validate via DNS (add CNAME records to Route 53)
# Certificate ARN will be used in variables
```

### Step 1.5: Create Terraform Backend

**⚠️ REQUIRED:** S3 bucket and DynamoDB table must exist before running `terraform init`.

```bash
# 1. Create S3 bucket for Terraform state (must be globally unique)
aws s3 mb s3://your-org-coder-terraform-state --region us-east-1

# 2. Enable versioning (required for state recovery)
aws s3api put-bucket-versioning \
  --bucket your-org-coder-terraform-state \
  --versioning-configuration Status=Enabled

# 3. Enable encryption
aws s3api put-bucket-encryption \
  --bucket your-org-coder-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# 4. Block public access
aws s3api put-public-access-block \
  --bucket your-org-coder-terraform-state \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# 5. Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name coder-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# 6. Verify resources were created
aws s3 ls | grep coder-terraform-state
aws dynamodb list-tables | grep coder-terraform-locks
```

**Note the bucket name** - you'll need it for the next phase.

---

## Phase 2: Prepare Deployment Environment

**Time Estimate:** 10 minutes

### Step 2.1: Clone Repository

```bash
# Clone the IaC repository
git clone https://github.com/your-org/coder-infrastructure.git
cd coder-infrastructure/terraform
```

### Step 2.2: Run Pre-flight Checks

```bash
# Run quota validation
./modules/quota-validation/scripts/preflight-check.sh

# Expected output: All quotas sufficient
# If quotas insufficient, request increases before proceeding
```

### Step 2.3: Configure Backend File

**Prerequisite:** S3 bucket and DynamoDB table created in Phase 1, Step 1.5.

```bash
# Navigate to terraform directory
cd terraform

# Create backend config from template
cp backend-config/prod.hcl.example backend-config/prod.hcl

# Update with your S3 bucket name
vim backend-config/prod.hcl
```

**Update these values in `backend-config/prod.hcl`:**
```hcl
bucket         = "your-org-coder-terraform-state"  # From Step 1.5
key            = "coder/prod/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "coder-terraform-locks"           # From Step 1.5
```

### Step 2.4: Initialize Terraform

```bash
# Initialize with backend configuration
terraform init -backend-config=backend-config/prod.hcl

# Expected output: "Terraform has been successfully initialized!"

# Verify initialization
terraform providers
```

**Common initialization errors:**
- ❌ `bucket does not exist` → Complete Phase 1, Step 1.5 (create S3 bucket)
- ❌ `table does not exist` → Complete Phase 1, Step 1.5 (create DynamoDB table)
- ❌ `backend-config/prod.hcl: no such file or directory` → Complete Step 2.3 (create backend config file)
- ❌ `access denied` → Verify AWS credentials have S3 and DynamoDB permissions

---

## Phase 3: Configure Variables

**Time Estimate:** 5 minutes

### Step 3.1: Create Variables File

```bash
# Copy SR-HA pattern file
cp patterns/sr-ha.tfvars environments/prod.tfvars

# Edit with your values
vim environments/prod.tfvars
```

### Step 3.2: Required Variables

**Update these values from Phase 1:**

```hcl
# environments/prod.tfvars

# From Step 1.1 (OIDC setup)
oidc_issuer_url        = "https://login.microsoftonline.com/YOUR_TENANT_ID/v2.0"  # From Azure AD
oidc_client_id         = "your-client-id-from-step-1.1"

# From Step 1.2 (Secrets Manager - use the ARNs you noted)
oidc_client_secret_arn = "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:coder-oidc-secret-XXXXX"

# Your deployment configuration (must match Step 1.1)
owner           = "platform-team"
base_domain     = "example.com"          # Must match OIDC redirect URI
coder_subdomain = "coder"                # Must match OIDC redirect URI
aws_region      = "us-east-1"

# From Step 1.4 (optional - if you created cert manually)
existing_acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abc123"
# Or leave empty to have Terraform create it:
create_acm_certificate = true
existing_acm_certificate_arn = ""
```

**All other values** can remain as SR-HA pattern defaults.

### Step 3.3: Validate Configuration

```bash
# Check for syntax errors
terraform validate

# This should succeed even before applying
```

---

## Phase 4: Deploy Infrastructure

**Time Estimate:** 35-40 minutes

### Step 4.1: Plan Deployment

```bash
# Generate and review plan
terraform plan -var-file=environments/prod.tfvars -out=tfplan

# Review the plan carefully
# Expected resources: ~150-200 resources
```

**Common errors at this stage:**
- ❌ `Secret not found: coder-oidc-secret` → Go back to Phase 1, Step 1.2
- ❌ `Hosted zone not found for example.com` → Go back to Phase 1, Step 1.3
- ❌ `Certificate ARN invalid` → Verify ACM certificate exists or set `create_acm_certificate = true`

### Step 4.2: Apply Infrastructure

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

### Step 4.3: Validate Infrastructure

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

---

## Phase 5: Configure Kubernetes Access

**Time Estimate:** 5 minutes

### Step 5.1: Update kubeconfig

```bash
# Update kubeconfig for the new cluster
aws eks update-kubeconfig --region us-east-1 --name coder-prod

# Verify access
kubectl cluster-info
kubectl get nodes
```

### Step 5.2: Verify Node Groups

```bash
# Check all node groups are ready
kubectl get nodes -l node-group=coder-control
kubectl get nodes -l node-group=coder-prov
kubectl get nodes -l node-group=coder-ws

# Verify taints
kubectl describe nodes | grep -A 5 "Taints:"
```

### Step 5.3: Verify Namespaces

```bash
# Check namespaces created
kubectl get namespaces | grep coder

# Expected:
# coder        Active
```

---

## Phase 6: Verify Coder Deployment

**Time Estimate:** 5 minutes

### Step 6.1: Check Coder Pods

```bash
# Check coderd pods (should see 2 replicas for HA)
kubectl get pods -n coder -l app.kubernetes.io/name=coder

# Expected: 2 pods in Running state

# Check logs for errors
kubectl logs -n coder -l app.kubernetes.io/name=coder --tail=100
```

**Common errors at this stage:**
- ❌ `ImagePullBackOff` → Check ECR/registry permissions
- ❌ `CrashLoopBackOff` with `database connection failed` → Verify Aurora endpoint and security groups
- ❌ `CrashLoopBackOff` with `OIDC error` → Verify OIDC configuration from Phase 1

### Step 6.2: Verify Database Connectivity

```bash
# Check coderd can connect to Aurora
kubectl logs -n coder -l app.kubernetes.io/name=coder | grep -i database

# Should see successful connection messages like:
# "database migration complete" or "connected to database"
```

### Step 6.3: Verify Load Balancer and DNS

```bash
# Get NLB DNS name
kubectl get svc -n coder coder -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Verify DNS resolution
dig coder.example.com
# Should return an A/ALIAS record pointing to the NLB

# Test HTTPS connectivity
curl -I https://coder.example.com/api/v2/buildinfo
# Should return 200 OK
```

### Step 6.4: Test OIDC Login

```bash
# Get the Coder URL
terraform output coder_url
# Navigate to this URL in your browser
```

**Login test:**
1. Click "Sign in with OIDC"
2. Should redirect to your IDP (from Phase 1, Step 1.1)
3. Authenticate with your credentials
4. Should redirect back to: `https://coder.example.com/api/v2/users/oidc/callback`
5. First user becomes owner automatically

**Common login errors:**
- ❌ `redirect_uri_mismatch` → Verify redirect URI in IDP matches exactly: `https://<coder_subdomain>.<base_domain>/api/v2/users/oidc/callback`
- ❌ `invalid_client` → Verify OIDC client ID and secret are correct
- ❌ `unauthorized_client` → Verify OIDC app is enabled in your IDP

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
