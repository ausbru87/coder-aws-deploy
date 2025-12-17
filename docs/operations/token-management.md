# Service Account Token Management

This document defines the service account token management procedures for the Coder platform, covering CI/CD authentication, token lifecycle, storage, and compromise response.

## Table of Contents

1. [Overview](#overview)
2. [Service Account Token Configuration](#service-account-token-configuration)
3. [Token Lifecycle Management](#token-lifecycle-management)
4. [Secrets Manager Storage](#secrets-manager-storage)
5. [Token Compromise Response](#token-compromise-response)
6. [Workspace Access Controls](#workspace-access-controls)
7. [Implementation Details](#implementation-details)
8. [Verification and Monitoring](#verification-and-monitoring)

---

## Overview

Service account tokens provide programmatic access to the Coder API for CI/CD systems and automation workflows. This document establishes the security controls and procedures required by Requirements 12d.1-12d.9.

### Key Requirements

| Requirement | Description | Implementation |
|-------------|-------------|----------------|
| 12d.3 | CI/CD authentication via service account tokens | Token-based API authentication |
| 12d.6 | 90-day token expiration with rotation | Automated expiration and alerts |
| 12d.7 | Template Admin scope only for CI/CD | Least-privilege token permissions |
| 12d.8 | Storage in AWS Secrets Manager | Encrypted secret storage |
| 12d.9 | Immediate revocation on compromise | Documented response procedure |

---

## Service Account Token Configuration

### Token Scope and Permissions

**Requirement:** 12d.7

Service account tokens for CI/CD template deployment SHALL have Template Admin scope only:

| Permission | Allowed | Rationale |
|------------|---------|-----------|
| Create templates | ✅ | Required for CI/CD deployment |
| Modify templates | ✅ | Required for template updates |
| Delete templates | ✅ | Required for template cleanup |
| Assign template access | ✅ | Required for access management |
| View templates | ✅ | Required for deployment verification |
| Create users | ❌ | Not needed for template deployment |
| Modify users | ❌ | Not needed for template deployment |
| Access workspaces | ❌ | Not needed for template deployment |
| System administration | ❌ | Not needed for template deployment |

### Creating Service Account Tokens

Service account tokens are created via the Coder CLI or API:

```bash
# Create a service account user (one-time setup)
coder users create \
  --username "cicd-template-deployer" \
  --email "cicd-template-deployer@example.com" \
  --login-type none

# Assign Template Admin role to the service account
coder users edit-roles \
  --username "cicd-template-deployer" \
  --roles "template-admin"

# Create a token with 90-day expiration (Requirement 12d.6)
coder tokens create \
  --user "cicd-template-deployer" \
  --name "cicd-pipeline-token" \
  --lifetime 2160h  # 90 days in hours
```

### Token Naming Convention

Use consistent naming for service account tokens:

```
Format: <purpose>-<environment>-<date>
Examples:
  - cicd-template-prod-20241216
  - github-actions-staging-20241216
  - jenkins-deploy-prod-20241216
```

---

## Token Lifecycle Management

### Token Expiration Policy

**Requirement:** 12d.6

All service account tokens SHALL expire after 90 days and require rotation:

| Setting | Value | Rationale |
|---------|-------|-----------|
| Maximum Lifetime | 90 days | Limits exposure window |
| Rotation Warning | 14 days before expiration | Allows planned rotation |
| Grace Period | None | Tokens become invalid immediately |

### Rotation Schedule

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Token Rotation Timeline                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Day 0          Day 76              Day 90                                  │
│    │              │                   │                                      │
│    ▼              ▼                   ▼                                      │
│  Token         14-day              Token                                    │
│  Created       Warning             Expires                                  │
│                Alert                                                         │
│                                                                              │
│  Actions:                                                                    │
│  - Store in    - Create new        - Old token                              │
│    Secrets       token               invalid                                │
│    Manager     - Update Secrets    - CI/CD uses                             │
│               - Test new token       new token                              │
│               - Revoke old token                                            │
│                 (after validation)                                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Rotation Procedure

1. **Create New Token** (14 days before expiration)
   ```bash
   # Create new token
   NEW_TOKEN=$(coder tokens create \
     --user "cicd-template-deployer" \
     --name "cicd-pipeline-token-$(date +%Y%m%d)" \
     --lifetime 2160h \
     --output json | jq -r '.key')
   
   # Store in Secrets Manager
   aws secretsmanager update-secret \
     --secret-id "coder/cicd/template-deployer-token" \
     --secret-string "$NEW_TOKEN"
   ```

2. **Validate New Token**
   ```bash
   # Test API access with new token
   curl -H "Coder-Session-Token: $NEW_TOKEN" \
     https://coder.example.com/api/v2/users/me
   ```

3. **Update CI/CD Configuration**
   - CI/CD systems automatically retrieve token from Secrets Manager
   - No manual configuration changes required

4. **Revoke Old Token**
   ```bash
   # List tokens to find old token ID
   coder tokens list --user "cicd-template-deployer"
   
   # Revoke old token
   coder tokens delete --user "cicd-template-deployer" --id <old-token-id>
   ```

### Expiration Monitoring

CloudWatch alarms monitor token expiration:

```yaml
# CloudWatch Alarm for Token Expiration Warning
- AlarmName: CoderServiceAccountTokenExpiring
  MetricName: ServiceAccountTokenDaysUntilExpiration
  Namespace: Coder/Security
  Threshold: 14
  ComparisonOperator: LessThanOrEqualToThreshold
  EvaluationPeriods: 1
  AlarmActions:
    - !Ref SecurityTeamSNSTopic
```

---

## Secrets Manager Storage

**Requirement:** 12d.8

All service account tokens SHALL be stored in AWS Secrets Manager.

### Secret Structure

```json
{
  "secret_name": "coder/cicd/template-deployer-token",
  "description": "Coder service account token for CI/CD template deployment",
  "tags": {
    "Purpose": "cicd-template-deployment",
    "Environment": "production",
    "TokenUser": "cicd-template-deployer",
    "ExpirationDate": "2025-03-16",
    "ManagedBy": "terraform"
  }
}
```

### Access Control

IAM policies restrict access to service account tokens:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCICDTokenAccess",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:coder/cicd/*",
      "Condition": {
        "StringEquals": {
          "aws:PrincipalTag/Purpose": "cicd-template-deployment"
        }
      }
    }
  ]
}
```

### Secret Rotation

Secrets Manager automatic rotation is NOT used for Coder tokens because:
1. Token creation requires Coder CLI/API interaction
2. Rotation must be coordinated with Coder token lifecycle
3. Manual rotation with monitoring provides better control

Instead, use CloudWatch Events to trigger rotation reminders:

```yaml
# EventBridge Rule for Rotation Reminder
- Name: CoderTokenRotationReminder
  ScheduleExpression: "rate(76 days)"  # 90 - 14 days
  Targets:
    - Id: NotifySecurityTeam
      Arn: !Ref SecurityTeamSNSTopic
```

---

## Token Compromise Response

**Requirement:** 12d.9

When a service account token is suspected or confirmed compromised, immediate revocation and rotation SHALL be triggered.

### Compromise Indicators

| Indicator | Severity | Response |
|-----------|----------|----------|
| Unauthorized API calls | Critical | Immediate revocation |
| Token exposed in logs/code | Critical | Immediate revocation |
| Unusual access patterns | High | Investigation + rotation |
| Failed authentication spike | Medium | Investigation |

### Immediate Response Procedure

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Token Compromise Response Workflow                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  1. DETECT                                                                   │
│     │                                                                        │
│     ▼                                                                        │
│  2. REVOKE IMMEDIATELY                                                       │
│     │  coder tokens delete --user <user> --id <token-id>                    │
│     │                                                                        │
│     ▼                                                                        │
│  3. AUDIT                                                                    │
│     │  - Review Coder audit logs                                            │
│     │  - Check CloudTrail for Secrets Manager access                        │
│     │  - Identify scope of compromise                                       │
│     │                                                                        │
│     ▼                                                                        │
│  4. REMEDIATE                                                                │
│     │  - Create new token                                                   │
│     │  - Update Secrets Manager                                             │
│     │  - Rotate any affected credentials                                    │
│     │                                                                        │
│     ▼                                                                        │
│  5. DOCUMENT                                                                 │
│     │  - Incident report                                                    │
│     │  - Root cause analysis                                                │
│     │  - Preventive measures                                                │
│     │                                                                        │
│     ▼                                                                        │
│  6. NOTIFY                                                                   │
│        - Security team                                                       │
│        - Affected stakeholders                                               │
│        - Management (if required)                                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Emergency Revocation Commands

```bash
#!/bin/bash
# Emergency Token Revocation Script
# Usage: ./revoke-token.sh <username> <token-id>

USERNAME=$1
TOKEN_ID=$2

# Revoke the compromised token
echo "Revoking token $TOKEN_ID for user $USERNAME..."
coder tokens delete --user "$USERNAME" --id "$TOKEN_ID"

# Verify revocation
echo "Verifying token revocation..."
coder tokens list --user "$USERNAME"

# Log the action
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) - Token $TOKEN_ID revoked for user $USERNAME" >> /var/log/coder-security-actions.log

# Alert security team
aws sns publish \
  --topic-arn "arn:aws:sns:us-east-1:ACCOUNT_ID:security-alerts" \
  --message "ALERT: Coder service account token revoked. User: $USERNAME, Token: $TOKEN_ID"
```

### Post-Incident Checklist

- [ ] Token immediately revoked
- [ ] Audit logs reviewed for unauthorized access
- [ ] Scope of compromise determined
- [ ] New token created and stored securely
- [ ] CI/CD systems updated with new token
- [ ] Incident documented
- [ ] Root cause identified
- [ ] Preventive measures implemented
- [ ] Stakeholders notified

---

## Workspace Access Controls

**Requirements:** 12d.1, 12d.2

### Single Owner Per Workspace

**Requirement:** 12d.1

Each workspace SHALL have a single owner who is the creator:

| Attribute | Value |
|-----------|-------|
| Owner Assignment | Automatic (creator) |
| Owner Transfer | Not supported |
| Multiple Owners | Not allowed |

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Workspace Ownership Model                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  User A creates workspace "dev-env-1"                                       │
│     │                                                                        │
│     ▼                                                                        │
│  ┌─────────────────────────────────────────┐                                │
│  │         Workspace: dev-env-1            │                                │
│  │                                         │                                │
│  │  Owner: User A (creator)                │                                │
│  │  Created: 2024-12-16                    │                                │
│  │  Template: pod-swdev                    │                                │
│  │                                         │                                │
│  │  Access:                                │                                │
│  │  - User A: Full control ✅              │                                │
│  │  - User B: No access ❌                 │                                │
│  │  - Admin: No access to data ❌          │                                │
│  │                                         │                                │
│  └─────────────────────────────────────────┘                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Workspace Owner Permissions

**Requirement:** 12d.2

Workspace owners SHALL have full control over their workspaces:

| Permission | Owner | Other Users | Admins |
|------------|:-----:|:-----------:|:------:|
| Start workspace | ✅ | ❌ | ❌ |
| Stop workspace | ✅ | ❌ | ✅* |
| Delete workspace | ✅ | ❌ | ✅* |
| Access workspace shell | ✅ | ❌ | ❌ |
| View workspace logs | ✅ | ❌ | ❌ |
| Modify workspace settings | ✅ | ❌ | ❌ |
| View workspace data | ✅ | ❌ | ❌ |

*Admins can stop/delete workspaces for operational reasons but cannot access workspace contents.

### Workspace Access Enforcement

Coder enforces workspace access controls at multiple levels:

1. **API Level**: All API requests validate workspace ownership
2. **Agent Level**: Workspace agents only accept connections from the owner
3. **Network Level**: NetworkPolicies isolate workspaces from each other

```yaml
# Example NetworkPolicy for workspace isolation
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: workspace-isolation
  namespace: coder-ws
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: coder-workspace
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Only allow traffic from coderd
    - from:
        - namespaceSelector:
            matchLabels:
              app.kubernetes.io/name: coder
          podSelector:
            matchLabels:
              app.kubernetes.io/name: coder
  egress:
    # Allow egress to coderd and external resources
    - to:
        - namespaceSelector:
            matchLabels:
              app.kubernetes.io/name: coder
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 10.0.0.0/8  # Block access to other workspaces
```

---

## Implementation Details

### Terraform Resources

The following Terraform resources manage service account token infrastructure:

```hcl
# =============================================================================
# Service Account Token Secrets Manager Configuration
# Requirements: 12d.8
# =============================================================================

# Secret for CI/CD service account token
resource "aws_secretsmanager_secret" "cicd_token" {
  name        = "coder/cicd/template-deployer-token"
  description = "Coder service account token for CI/CD template deployment"

  tags = {
    Purpose     = "cicd-template-deployment"
    Environment = var.environment
    TokenUser   = "cicd-template-deployer"
    ManagedBy   = "terraform"
  }
}

# Initial placeholder value (actual token created manually)
resource "aws_secretsmanager_secret_version" "cicd_token" {
  secret_id     = aws_secretsmanager_secret.cicd_token.id
  secret_string = "PLACEHOLDER_REPLACE_WITH_ACTUAL_TOKEN"

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# IAM policy for CI/CD token access
resource "aws_iam_policy" "cicd_token_access" {
  name        = "coder-cicd-token-access"
  description = "Allow CI/CD systems to access Coder service account token"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCICDTokenAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.cicd_token.arn
      }
    ]
  })
}
```

### CI/CD Integration Examples

#### GitHub Actions

```yaml
name: Deploy Coder Template

on:
  push:
    paths:
      - 'templates/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-actions-coder-deploy
          aws-region: us-east-1

      - name: Get Coder token from Secrets Manager
        id: get-token
        run: |
          TOKEN=$(aws secretsmanager get-secret-value \
            --secret-id coder/cicd/template-deployer-token \
            --query SecretString --output text)
          echo "::add-mask::$TOKEN"
          echo "CODER_SESSION_TOKEN=$TOKEN" >> $GITHUB_ENV

      - name: Deploy template
        run: |
          coder templates push my-template \
            --directory ./templates/my-template \
            --yes
```

#### Jenkins Pipeline

```groovy
pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
    }
    
    stages {
        stage('Get Coder Token') {
            steps {
                withAWS(credentials: 'jenkins-aws-credentials', region: env.AWS_REGION) {
                    script {
                        def token = sh(
                            script: '''
                                aws secretsmanager get-secret-value \
                                    --secret-id coder/cicd/template-deployer-token \
                                    --query SecretString --output text
                            ''',
                            returnStdout: true
                        ).trim()
                        env.CODER_SESSION_TOKEN = token
                    }
                }
            }
        }
        
        stage('Deploy Template') {
            steps {
                sh '''
                    coder templates push my-template \
                        --directory ./templates/my-template \
                        --yes
                '''
            }
        }
    }
}
```

---

## Verification and Monitoring

### Token Audit Queries

**CloudWatch Logs Insights - Token Usage:**
```sql
fields @timestamp, @message, user.email, action
| filter @message like /token/
| filter action in ["token.create", "token.delete", "api.call"]
| sort @timestamp desc
| limit 100
```

**CloudWatch Logs Insights - Service Account Activity:**
```sql
fields @timestamp, @message, user.email, resource, action
| filter user.email = "cicd-template-deployer@example.com"
| sort @timestamp desc
| limit 100
```

### Verification Commands

```bash
# List all service account tokens
coder tokens list --user "cicd-template-deployer"

# Verify token permissions (should only show template-admin)
coder users show "cicd-template-deployer" --json | jq '.roles'

# Test token access (should succeed for template operations)
CODER_SESSION_TOKEN=$TOKEN coder templates list

# Test token access (should fail for user operations)
CODER_SESSION_TOKEN=$TOKEN coder users list  # Expected: Permission denied
```

### Monitoring Alerts

| Alert | Condition | Severity | Response |
|-------|-----------|----------|----------|
| Token Expiring | Days until expiration ≤ 14 | Warning | Rotate token |
| Token Expired | Token invalid | Critical | Immediate rotation |
| Unauthorized Access | API call with invalid token | High | Investigate |
| Unusual Activity | Abnormal API call patterns | Medium | Review logs |

---

## References

- [Coder API Tokens Documentation](https://coder.com/docs/admin/users/tokens)
- [Coder CLI Reference](https://coder.com/docs/reference/cli)
- [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)
- [NIST SP 800-63B: Digital Identity Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)
