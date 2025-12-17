# Day 1: Initial Configuration

This guide covers the initial configuration of the Coder platform after infrastructure deployment. Day 1 includes post-deployment configuration, smoke tests, monitoring setup, and external system integrations.

**Target Audience:** DevSecOps Engineers L1-5, SysAdmins L3-L6

**Estimated Time:** 60-90 minutes

## Table of Contents

1. [Phase 6: Post-Deployment Configuration](#phase-6-post-deployment-configuration)
2. [Phase 7: Smoke Tests](#phase-7-smoke-tests)
3. [Phase 8: Configure Monitoring](#phase-8-configure-monitoring)
4. [External System Integrations](#external-system-integrations)

## Prerequisites

Before beginning Day 1 configuration:
- Complete [Day 0: Infrastructure Deployment](day0-deployment.md)
- Verify all Coder pods are running
- Confirm DNS and TLS certificates are working

## Phase 6: Post-Deployment Configuration

### Step 6.1: Create Initial Owner Account

```bash
# Get Coder URL
CODER_URL=$(terraform output -raw coder_access_url)

# Create first user (will be Owner)
# Navigate to $CODER_URL in browser
# Complete OIDC authentication
# First user automatically becomes Owner
```

### Step 6.2: Verify OIDC Authentication

```bash
# Test OIDC flow
# 1. Navigate to Coder URL
# 2. Click "Sign in with OIDC"
# 3. Complete IDP authentication
# 4. Verify redirect back to Coder

# Check audit logs
kubectl logs -n coder -l app.kubernetes.io/name=coder | grep -i oidc
```

### Step 6.3: Verify Group Sync

```bash
# After users authenticate, verify groups synced
coder groups list

# Expected groups:
# coder-platform-admins
# coder-template-owners
# coder-security-audit
# developers
```

### Step 6.4: Deploy Templates

```bash
# Templates are deployed via coderd provider in Terraform
# Verify templates exist
coder templates list

# Expected templates:
# pod-swdev
# ec2-windev-gui
# ec2-datasci
```

## Phase 7: Smoke Tests

### Step 7.1: Create Test Workspace

```bash
# Create a pod-based workspace
coder create test-workspace --template pod-swdev

# Wait for workspace to start (should be < 2 minutes)
coder ssh test-workspace

# Verify workspace functionality
whoami
pwd
ls -la

# Exit and stop workspace
exit
coder stop test-workspace
```

### Step 7.2: Test EC2 Workspace (Optional)

```bash
# Create EC2-based workspace
coder create test-ec2 --template ec2-datasci

# Wait for workspace (should be < 5 minutes)
coder ssh test-ec2

# Verify functionality
exit
coder stop test-ec2
```

### Step 7.3: Verify External Auth

```bash
# In a workspace, test Git authentication
coder ssh test-workspace
git clone https://github.com/your-org/private-repo.git

# Should authenticate via Coder external auth
```

### Step 7.4: Cleanup Test Workspaces

```bash
coder delete test-workspace --yes
coder delete test-ec2 --yes
```

## Phase 8: Configure Monitoring

### Step 8.1: Verify CloudWatch Logs

```bash
# Check log groups created
aws logs describe-log-groups --log-group-name-prefix /coder

# Expected log groups:
# /coder/audit
# /coder/coderd
# /coder/provisioner
```

### Step 8.2: Verify CloudWatch Dashboards

```bash
# List dashboards
aws cloudwatch list-dashboards

# View Coder dashboard in AWS Console
# CloudWatch → Dashboards → Coder-Platform
```

### Step 8.3: Verify Alerts

```bash
# List CloudWatch alarms
aws cloudwatch describe-alarms --alarm-name-prefix Coder

# Expected alarms:
# Coder-HighCPU
# Coder-HighMemory
# Coder-DatabaseConnections
# Coder-APILatency
```

## External System Integrations

### Git Provider Integration

Coder supports external authentication to allow workspaces to access Git repositories without manual credential management.

#### GitHub Integration

**Step 1: Create GitHub OAuth App**
```
GitHub → Settings → Developer settings → OAuth Apps → New OAuth App

Application name: Coder Platform
Homepage URL: https://coder.example.com
Authorization callback URL: https://coder.example.com/external-auth/github/callback
```

**Step 2: Store Credentials**
```bash
# Store client secret in Secrets Manager
aws secretsmanager create-secret \
  --name coder-github-oauth \
  --secret-string '{"client_id":"xxx","client_secret":"yyy"}'
```

**Step 3: Configure Coder**
```yaml
# In coder-values.yaml
coder:
  env:
    - name: CODER_EXTERNAL_AUTH_0_TYPE
      value: "github"
    - name: CODER_EXTERNAL_AUTH_0_CLIENT_ID
      value: "your-github-client-id"
    - name: CODER_EXTERNAL_AUTH_0_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: coder-github-oauth
          key: client_secret
    - name: CODER_EXTERNAL_AUTH_0_SCOPES
      value: "repo,read:org"
```

**Step 4: Verify Integration**
```bash
# In a workspace
git clone https://github.com/your-org/private-repo.git
# Should authenticate automatically via Coder
```

#### GitLab Integration

**Step 1: Create GitLab Application**
```
GitLab → Admin → Applications → New Application

Name: Coder Platform
Redirect URI: https://coder.example.com/external-auth/gitlab/callback
Scopes: api, read_user, read_repository
```

**Step 2: Configure Coder**
```yaml
coder:
  env:
    - name: CODER_EXTERNAL_AUTH_0_TYPE
      value: "gitlab"
    - name: CODER_EXTERNAL_AUTH_0_CLIENT_ID
      value: "your-gitlab-app-id"
    - name: CODER_EXTERNAL_AUTH_0_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: coder-gitlab-oauth
          key: client_secret
    - name: CODER_EXTERNAL_AUTH_0_VALIDATE_URL
      value: "https://gitlab.example.com/oauth/token/info"
```

#### Bitbucket Integration

**Step 1: Create Bitbucket OAuth Consumer**
```
Bitbucket → Workspace settings → OAuth consumers → Add consumer

Name: Coder Platform
Callback URL: https://coder.example.com/external-auth/bitbucket/callback
Permissions: Account (Read), Repositories (Read, Write)
```

**Step 2: Configure Coder**
```yaml
coder:
  env:
    - name: CODER_EXTERNAL_AUTH_0_TYPE
      value: "bitbucket-cloud"
    - name: CODER_EXTERNAL_AUTH_0_CLIENT_ID
      value: "your-bitbucket-key"
    - name: CODER_EXTERNAL_AUTH_0_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: coder-bitbucket-oauth
          key: client_secret
```

### CI/CD Integration for Template Deployment

Templates are deployed via Terraform using the coderd provider. CI/CD pipelines automate this process.

#### GitHub Actions Workflow

```yaml
# .github/workflows/deploy-templates.yml
name: Deploy Coder Templates

on:
  push:
    branches: [main]
    paths:
      - 'terraform/modules/coder/template-architecture/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Terraform Init
        run: terraform init -backend-config=backend-config/prod.hcl
        working-directory: terraform

      - name: Terraform Plan
        run: terraform plan -var-file=environments/prod.tfvars -target=module.coder
        working-directory: terraform

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve -var-file=environments/prod.tfvars -target=module.coder
        working-directory: terraform
```

#### Service Account Token for CI/CD

```bash
# Create service account token with Template Admin scope
# Token stored in Secrets Manager per requirement 12d.8

# Create token via Coder CLI (as Owner)
coder tokens create \
  --name ci-cd-template-deploy \
  --lifetime 2160h  # 90 days per requirement 12d.6

# Store in Secrets Manager
aws secretsmanager create-secret \
  --name coder-ci-cd-token \
  --secret-string "coder_token_xxx"
```

See [Service Account Token Management](../../terraform/docs/service-account-token-management.md) for detailed procedures.

### Coder External Authentication for Workspace Access

External authentication allows workspaces to access external services (AWS, Azure, GCP) using Coder-managed credentials.

#### AWS Access from Workspaces

**Option 1: IRSA (Recommended for Pod Workspaces)**
```hcl
# In base-k8s module
resource "kubernetes_service_account" "workspace" {
  metadata {
    name      = "coder-workspace-${var.workspace_name}"
    namespace = "coder-ws"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.workspace.arn
    }
  }
}
```

**Option 2: Instance Profile (For EC2 Workspaces)**
```hcl
# In base-ec2-linux module
resource "aws_iam_instance_profile" "workspace" {
  name = "coder-workspace-${var.workspace_name}"
  role = aws_iam_role.workspace.name
}
```

#### External Service Authentication

```yaml
# Configure additional external auth providers
coder:
  env:
    # AWS (for CodeCommit, etc.)
    - name: CODER_EXTERNAL_AUTH_1_TYPE
      value: "aws-codecommit"
    - name: CODER_EXTERNAL_AUTH_1_ID
      value: "aws"

    # Azure DevOps
    - name: CODER_EXTERNAL_AUTH_2_TYPE
      value: "azure-devops"
    - name: CODER_EXTERNAL_AUTH_2_CLIENT_ID
      value: "your-azure-app-id"
```

## Configuration Complete

Your Coder platform is now fully configured and ready for production use. Users can begin creating workspaces and the platform is ready for ongoing operations.

## Next Steps

1. [Day 2: Ongoing Operations](day2-operations.md) - Learn about daily operations, scaling, and maintenance
2. [Troubleshooting Guide](troubleshooting.md) - Reference for common issues
3. [Upgrade Procedures](upgrades.md) - Learn how to upgrade platform components

## Related Documentation

- [Day 0: Infrastructure Deployment](day0-deployment.md)
- [Day 2: Ongoing Operations](day2-operations.md)
- [Upgrade Procedures](upgrades.md)
- [Troubleshooting Guide](troubleshooting.md)
- [Service Account Token Management](../../terraform/docs/service-account-token-management.md)
- [IDP Configuration Guide](../../terraform/docs/idp-configuration-guide.md)
- [RBAC Configuration](../../terraform/docs/rbac-configuration.md)

---

*Document Version: 1.0*
*Last Updated: December 2024*
*Maintained by: Platform Engineering Team*
