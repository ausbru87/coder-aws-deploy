# SR-HA Deployment Quickstart

This guide provides a streamlined path to deploying the SR-HA pattern in approximately 95 minutes.

## Prerequisites (5 minutes)

Ensure you have these tools installed:
1. AWS account with admin access
2. Terraform >= 1.14.0 installed
3. AWS CLI configured
4. kubectl and helm installed
5. Domain name with Route 53 hosted zone

See [full prerequisites](./prerequisites.md) for complete requirements.

## ⚠️ CRITICAL: Complete These BEFORE Running Terraform

**If you skip this section, your deployment WILL fail.** These steps must be completed before running `terraform apply`.

### Step 0.1: Set Up OIDC Application (20-30 minutes)

Your Coder deployment URL will be: `https://<coder_subdomain>.<base_domain>`

For example, if you set:
- `base_domain = "example.com"`
- `coder_subdomain = "coder"`

Your Coder URL will be: `https://coder.example.com`

**The OIDC redirect URI will be:** `https://coder.example.com/api/v2/users/oidc/callback`

#### Azure AD / Entra ID

```bash
# Create app registration
az ad app create \
  --display-name "Coder Platform" \
  --sign-in-audience "AzureADMyOrg" \
  --web-redirect-uris "https://coder.example.com/api/v2/users/oidc/callback"

# Note the Application (client) ID - you'll need this for oidc_client_id
# Create a client secret - you'll need this for oidc_client_secret_arn
```

See [Authentication Guide](../configuration/authentication.md#microsoft-entra-id-azure-ad) for detailed Azure AD setup.

#### Okta

```bash
# Create OIDC application
okta apps create web \
  --app-name "Coder Platform" \
  --redirect-uri "https://coder.example.com/api/v2/users/oidc/callback"
```

See [Authentication Guide](../configuration/authentication.md#okta) for detailed Okta setup.

**What you need from this step:**
- ✅ OIDC issuer URL (e.g., `https://login.microsoftonline.com/YOUR_TENANT_ID/v2.0`)
- ✅ OIDC client ID
- ✅ OIDC client secret

### Step 0.2: Create AWS Secrets Manager Secrets (5 minutes)

**IMPORTANT:** Terraform expects these secrets to already exist.

```bash
# 1. Store OIDC client secret
aws secretsmanager create-secret \
  --name coder-oidc-secret \
  --secret-string "your-oidc-client-secret-from-step-0.1" \
  --region us-east-1

# Note the ARN - you'll need this for oidc_client_secret_arn

# 2. Store Coder license (obtain from https://coder.com/contact)
aws secretsmanager create-secret \
  --name coder-license \
  --secret-string "your-coder-license-key" \
  --region us-east-1

# 3. (Optional) Store Git OAuth secret for external auth
aws secretsmanager create-secret \
  --name github-oauth-secret \
  --secret-string "your-github-oauth-secret" \
  --region us-east-1
```

**What you need from this step:**
- ✅ OIDC client secret ARN
- ✅ Coder license secret ARN
- ✅ (Optional) Git OAuth secret ARN

### Step 0.3: Verify Route 53 Hosted Zone (2 minutes)

**⚠️ REQUIRED:** A Route 53 hosted zone for your domain MUST exist before deployment.

```bash
# Verify your domain's hosted zone exists
aws route53 list-hosted-zones-by-name --dns-name example.com

# Expected output: Should show your hosted zone
# If not found, create one:
# aws route53 create-hosted-zone --name example.com --caller-reference $(date +%s)

# Note the hosted zone ID (optional - Terraform can auto-lookup)
```

**What you need from this step:**
- ✅ Route 53 hosted zone exists for your domain
- ✅ (Optional) Hosted zone ID for `route53_zone_id` variable

### Step 0.4: Create Terraform Backend (5 minutes)

**⚠️ REQUIRED:** S3 bucket and DynamoDB table must exist before running `terraform init`.

```bash
# 1. Create S3 bucket for Terraform state (must be globally unique)
aws s3 mb s3://your-org-coder-terraform-state --region us-east-1

# 2. Enable versioning (required for state recovery)
aws s3api put-bucket-versioning \
  --bucket your-org-coder-terraform-state \
  --versioning-configuration Status=Enabled

# 3. Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name coder-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# 4. Create backend config file (from terraform/ directory)
cd terraform
cp backend-config/prod.hcl.example backend-config/prod.hcl
vim backend-config/prod.hcl  # Update bucket name to match your S3 bucket
```

**What you need from this step:**
- ✅ S3 bucket created and versioning enabled
- ✅ DynamoDB table created
- ✅ `backend-config/prod.hcl` file configured with your bucket name

---

## Quick Deployment (50 minutes)

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

**Critical values to set (using values from Step 0):**

```hcl
# From Step 0.1 (OIDC setup)
oidc_issuer_url        = "https://login.microsoftonline.com/YOUR_TENANT_ID/v2.0"  # From Step 0.1
oidc_client_id         = "your-client-id-from-step-0.1"                          # From Step 0.1

# From Step 0.2 (Secrets Manager)
oidc_client_secret_arn = "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:coder-oidc-secret-XXXXX"  # From Step 0.2

# Your configuration
owner        = "platform-team"              # Your team name
base_domain  = "example.com"                # Your domain (must match Step 0.1)
coder_subdomain = "coder"                   # Must match Step 0.1
```

**All other values can remain as defaults for SR-HA pattern.**

### Step 2: Initialize Terraform (2 minutes)

```bash
# Initialize with backend configuration (using config from Step 0.4)
terraform init -backend-config=backend-config/prod.hcl

# Expected output: "Terraform has been successfully initialized!"
```

**If initialization fails:**
- ❌ `bucket does not exist` → Complete Step 0.4 (create S3 bucket)
- ❌ `table does not exist` → Complete Step 0.4 (create DynamoDB table)
- ❌ `backend-config/prod.hcl: no such file` → Complete Step 0.4 (create backend config file)

### Step 3: Deploy Infrastructure (35 minutes)

```bash
# Validate configuration
terraform validate

# Plan deployment (will fail if secrets from Step 0.2 don't exist)
terraform plan -var-file=my-deployment.tfvars

# Review the plan - expect ~150-200 resources
# Deploy (takes ~30-35 minutes)
terraform apply -var-file=my-deployment.tfvars
```

**What's being created:**
- VPC with 3 availability zones
- EKS cluster with 3 node groups
- Aurora PostgreSQL Serverless v2
- Network Load Balancer with TLS
- CloudWatch logging and monitoring
- Route 53 DNS records
- ACM certificate

**Common errors if Step 0 was skipped:**
- ❌ `Error: Secret not found` → Go back to Step 0.2
- ❌ `OIDC authentication failed` → Verify redirect URI in Step 0.1
- ❌ `Domain not found` → Verify Route 53 hosted zone in Step 0.3

### Step 4: Configure Access (3 minutes)

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name coder-prod

# Verify Coder is running
kubectl get pods -n coder

# Get Coder URL (from Terraform outputs)
terraform output coder_url
```

### Step 5: Initial Configuration (2 minutes)

1. Navigate to your Coder URL (from terraform output)
   ```bash
   terraform output coder_url
   # Output: https://coder.example.com
   ```

2. Click "Sign in with OIDC"
3. Authenticate via your IDP (should redirect to URL from Step 0.1)
4. First user becomes the owner automatically

**If login fails:**
- ❌ Redirect URI mismatch → Verify it matches: `https://<coder_subdomain>.<base_domain>/api/v2/users/oidc/callback`
- ❌ OIDC issuer unreachable → Verify `oidc_issuer_url` is correct
- ❌ Invalid client credentials → Verify secret in Secrets Manager matches your IDP

## Post-Deployment Checklist

After deployment completes:

- [ ] Coder pods running (2 replicas for HA)
  ```bash
  kubectl get pods -n coder -l app.kubernetes.io/name=coder
  ```
- [ ] Database healthy
  ```bash
  terraform output aurora_cluster_endpoint
  ```
- [ ] NLB targets healthy
  ```bash
  terraform output nlb_dns_name
  ```
- [ ] DNS resolving correctly
  ```bash
  dig coder.example.com
  ```
- [ ] OIDC authentication working
- [ ] Can create test workspace

## Timing Summary

| Phase | Duration | Can Skip? |
|-------|----------|-----------|
| **Step 0.1**: OIDC Setup | 20-30 min | ❌ No - Required |
| **Step 0.2**: Secrets Creation | 5 min | ❌ No - Required |
| **Step 0.3**: DNS Verification | 2 min | ❌ No - Required |
| **Step 0.4**: Backend Setup | 5 min | ❌ No - Required |
| **Step 1**: Clone & Configure | 5 min | ❌ No |
| **Step 2**: Terraform Init | 2 min | ❌ No |
| **Step 3**: Deploy Infrastructure | 35 min | ❌ No |
| **Step 4**: Configure kubectl | 3 min | ❌ No |
| **Step 5**: Verify Login | 2 min | ❌ No |
| **Total** | **~95 minutes** | |

## Next Steps

1. **Deploy templates:** [Day 1 Configuration](../operations/day1-configuration.md)
2. **Configure RBAC:** [RBAC Guide](../configuration/rbac.md)
3. **Set up monitoring:** [Day 1 Configuration](../operations/day1-configuration.md#monitoring)
4. **Run scale tests:** [Scaling Guide](../operations/scaling.md)

## Troubleshooting

If you encounter issues:

**Terraform errors:**
1. `Secret not found` → Verify Step 0.2 completed (secrets exist in Secrets Manager)
2. `Invalid OIDC configuration` → Verify Step 0.1 completed (OIDC app exists with correct redirect URI)
3. `Quota exceeded` → Run: `./modules/quota-validation/scripts/check-quotas.sh`

**Login errors:**
1. `Redirect URI mismatch` → Verify redirect URI in IDP matches: `https://<coder_subdomain>.<base_domain>/api/v2/users/oidc/callback`
2. `OIDC issuer unreachable` → Verify `oidc_issuer_url` variable is correct
3. Review pod logs: `kubectl logs -n coder -l app.kubernetes.io/name=coder`

**For more help:**
- [Troubleshooting Guide](../operations/troubleshooting.md)
- [Authentication Configuration](../configuration/authentication.md)

## Full Documentation

For comprehensive deployment procedures, see:
- [Day 0: Infrastructure Deployment](../operations/day0-deployment.md)
- [Day 1: Initial Configuration](../operations/day1-configuration.md)
- [SR-HA Deployment Guide](../deployment-patterns/sr-ha/deployment.md)

---

**Total Time: ~95 minutes**
- Pre-Terraform setup (OIDC + Secrets + DNS + Backend): ~40 minutes
- Infrastructure provisioning: ~35 minutes
- Configuration and verification: ~10 minutes
- Remaining: Planning and contingency: ~10 minutes
