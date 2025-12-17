# Identity Provider (IDP) Configuration Guide

This document provides detailed configuration requirements and examples for integrating an OIDC-capable identity provider with the Coder platform.

## Table of Contents

1. [Overview](#overview)
2. [Authentication Requirements](#authentication-requirements)
3. [IDP Configuration Examples](#idp-configuration-examples)
4. [Coder OIDC Configuration](#coder-oidc-configuration)
5. [Verification Procedures](#verification-procedures)

---

## Overview

The Coder platform uses OIDC (OpenID Connect) for authentication, supporting any OIDC-capable identity provider. This guide covers the security requirements that must be configured at the IDP level.

**Supported Identity Providers:**
- Microsoft Entra ID (Azure AD)
- Okta
- Google Workspace
- Auth0
- Keycloak
- Any OIDC-compliant provider

**Requirement:** 12.1 - Support any OIDC-capable identity provider

---

## Authentication Requirements

**Requirement:** 12e.1

The selected IDP must support and enforce the following capabilities:

### 1. Multi-Factor Authentication (MFA)

| Requirement | Specification |
|-------------|---------------|
| Enforcement | Required for all users |
| Level | Enforced at IDP before Coder access |
| Methods | TOTP, Push notifications, Hardware keys (FIDO2) |

**Implementation Notes:**
- MFA must be enforced via IDP conditional access policies
- Coder does not provide its own MFA - it relies entirely on the IDP
- Users should complete MFA challenge before receiving OIDC tokens

### 2. Session Expiration

| Requirement | Specification |
|-------------|---------------|
| Inactivity Timeout | 8 hours |
| Re-authentication | Required after session expiration |
| Token Lifetime | Should match session duration |

**Coder Configuration:**
```yaml
CODER_SESSION_DURATION: "8h"
```

### 3. Account Lockout

| Requirement | Specification |
|-------------|---------------|
| Threshold | 5 consecutive failed attempts |
| Duration | 30 minutes |
| Alerts | Security team notification |

### 4. Concurrent Session Detection

| Requirement | Specification |
|-------------|---------------|
| Detection | Sessions from different locations |
| Response | Security alerts to user and security team |

### 5. Authentication Logging

| Event | Required |
|-------|----------|
| Failed authentication attempts | ✅ |
| Successful logins | ✅ |
| Account lockout events | ✅ |
| MFA challenges | ✅ |

---

## IDP Configuration Examples

### Microsoft Entra ID (Azure AD)

#### 1. App Registration

```bash
# Create app registration via Azure CLI
az ad app create \
  --display-name "Coder Platform" \
  --sign-in-audience "AzureADMyOrg" \
  --web-redirect-uris "https://coder.example.com/api/v2/users/oidc/callback"
```

#### 2. Configure Token Claims

Add the following optional claims to the ID token:
- `email`
- `groups`
- `preferred_username`

**Azure Portal Path:** App registrations → Coder Platform → Token configuration → Add optional claim

#### 3. Conditional Access Policy for MFA

```json
{
  "displayName": "Coder - Require MFA",
  "state": "enabled",
  "conditions": {
    "applications": {
      "includeApplications": ["<coder-app-id>"]
    },
    "users": {
      "includeUsers": ["All"]
    }
  },
  "grantControls": {
    "operator": "OR",
    "builtInControls": ["mfa"]
  }
}
```

#### 4. Account Lockout Settings

**Azure Portal Path:** Entra ID → Security → Authentication methods → Password protection

```json
{
  "lockoutThreshold": 5,
  "lockoutDurationInSeconds": 1800
}
```

#### 5. Group Claims Configuration

Enable group claims in the token:

**Azure Portal Path:** App registrations → Coder Platform → Token configuration → Add groups claim

Select:
- Security groups
- Groups assigned to the application

#### 6. Required API Permissions

| Permission | Type | Purpose |
|------------|------|---------|
| openid | Delegated | OIDC authentication |
| profile | Delegated | User profile information |
| email | Delegated | User email address |
| User.Read | Delegated | Read user profile |

---

### Okta

#### 1. Create OIDC Application

```bash
# Okta CLI
okta apps create web \
  --app-name "Coder Platform" \
  --redirect-uri "https://coder.example.com/api/v2/users/oidc/callback"
```

#### 2. Configure Group Claims

Add groups claim to ID token:

**Okta Admin Console:** Applications → Coder Platform → Sign On → OpenID Connect ID Token

```
Groups claim type: Filter
Groups claim filter: Matches regex: ^coder-.*|^developers$
```

#### 3. MFA Policy

**Okta Admin Console:** Security → Multifactor → Factor Enrollment

Create policy:
- Name: "Coder MFA Required"
- Assign to: All users accessing Coder
- Factors: TOTP, Okta Verify, WebAuthn

#### 4. Session Policy

**Okta Admin Console:** Security → Authentication → Sign-on policies

```json
{
  "name": "Coder Session Policy",
  "maxSessionIdleMinutes": 480,
  "maxSessionLifetimeMinutes": 480,
  "usePersistentCookie": false
}
```

#### 5. Account Lockout

**Okta Admin Console:** Security → General → Security Notification Emails

Configure:
- Lockout threshold: 5 attempts
- Lockout duration: 30 minutes
- Send lockout notification: Yes

---

### Google Workspace

#### 1. Create OAuth Client

**Google Cloud Console:** APIs & Services → Credentials → Create Credentials → OAuth client ID

```
Application type: Web application
Name: Coder Platform
Authorized redirect URIs: https://coder.example.com/api/v2/users/oidc/callback
```

#### 2. Configure Consent Screen

**Google Cloud Console:** APIs & Services → OAuth consent screen

Required scopes:
- `openid`
- `email`
- `profile`

#### 3. Enable 2-Step Verification

**Google Admin Console:** Security → 2-Step Verification

```
Enforcement: On for everyone
New user enrollment period: 1 week
Methods: Any (Security key recommended)
```

#### 4. Session Controls

**Google Admin Console:** Security → Google session control

```
Session length: 8 hours
Re-authentication: Required
```

---

## Coder OIDC Configuration

### Terraform Variables

```hcl
# OIDC Configuration
variable "oidc_issuer_url" {
  description = "OIDC issuer URL"
  type        = string
  # Examples:
  # Azure AD: https://login.microsoftonline.com/{tenant-id}/v2.0
  # Okta: https://{domain}.okta.com
  # Google: https://accounts.google.com
}

variable "oidc_client_id" {
  description = "OIDC client ID from IDP"
  type        = string
}

variable "oidc_client_secret_arn" {
  description = "ARN of Secrets Manager secret containing OIDC client secret"
  type        = string
}

variable "oidc_group_field" {
  description = "Token claim containing group membership"
  type        = string
  default     = "groups"
  # Azure AD: groups
  # Okta: groups
  # Google: Use Google Groups API
}

variable "oidc_group_regex_filter" {
  description = "Regex to filter which groups to sync"
  type        = string
  default     = "^coder-.*|^developers$"
}
```

### Helm Values

```yaml
coder:
  env:
    # OIDC Authentication
    - name: CODER_OIDC_ISSUER_URL
      value: "${oidc_issuer_url}"
    - name: CODER_OIDC_CLIENT_ID
      value: "${oidc_client_id}"
    - name: CODER_OIDC_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: coder-oidc-credentials
          key: CODER_OIDC_CLIENT_SECRET
    
    # Required scopes
    - name: CODER_OIDC_SCOPES
      value: "openid,profile,email,groups"
    
    # Group sync configuration
    - name: CODER_OIDC_GROUP_FIELD
      value: "${oidc_group_field}"
    - name: CODER_OIDC_GROUP_AUTO_CREATE
      value: "true"
    - name: CODER_OIDC_GROUP_REGEX_FILTER
      value: "${oidc_group_regex_filter}"
    
    # Role mapping
    - name: CODER_OIDC_GROUP_MAPPING
      value: '${oidc_group_mapping}'
    
    # Allow automatic user provisioning
    - name: CODER_OIDC_ALLOW_SIGNUPS
      value: "true"
    
    # Session management (8 hours)
    - name: CODER_SESSION_DURATION
      value: "8h"
    
    # Disable password auth (OIDC only)
    - name: CODER_DISABLE_PASSWORD_AUTH
      value: "true"
```

---

## Verification Procedures

### Pre-Deployment Verification

1. **Verify IDP Configuration:**
   ```bash
   # Test OIDC discovery endpoint
   curl -s "${OIDC_ISSUER_URL}/.well-known/openid-configuration" | jq .
   ```

2. **Verify MFA Policy:**
   - Log in as test user
   - Confirm MFA challenge is presented
   - Document MFA method used

3. **Verify Group Claims:**
   - Decode test user's ID token
   - Confirm groups claim is present
   - Verify expected groups are included

### Post-Deployment Verification

1. **Test Authentication Flow:**
   ```bash
   # Access Coder and verify redirect to IDP
   curl -I https://coder.example.com/login
   # Should redirect to IDP login page
   ```

2. **Verify Group Sync:**
   ```bash
   # List groups in Coder
   coder groups list
   
   # Verify expected groups exist
   coder groups show coder-platform-admins
   coder groups show coder-template-owners
   coder groups show coder-security-audit
   coder groups show developers
   ```

3. **Verify Role Mapping:**
   ```bash
   # Check user roles after login
   coder users show <username> --json | jq '.roles'
   ```

4. **Test Session Expiration:**
   - Log in and note session start time
   - Wait 8+ hours without activity
   - Verify re-authentication is required

5. **Test Account Lockout:**
   - Attempt 5 failed logins
   - Verify account is locked
   - Verify security alert is generated
   - Wait 30 minutes and verify unlock

### Monitoring Verification

1. **Verify Audit Logging:**
   ```bash
   # Check CloudWatch for authentication events
   aws logs filter-log-events \
     --log-group-name "/coder/audit" \
     --filter-pattern "login"
   ```

2. **Verify Alerts:**
   - Trigger test lockout
   - Confirm security team receives alert

---

## Troubleshooting

### Common Issues

| Issue | Cause | Resolution |
|-------|-------|------------|
| Groups not syncing | Missing groups scope | Add `groups` to OIDC scopes |
| MFA not enforced | Conditional access not configured | Configure IDP MFA policy |
| Session not expiring | Token lifetime mismatch | Align IDP and Coder session settings |
| Users can't log in | Incorrect redirect URI | Verify callback URL in IDP |

### Debug Commands

```bash
# Check Coder OIDC configuration
kubectl exec -it deploy/coder -n coder -- env | grep OIDC

# View Coder logs for auth issues
kubectl logs -l app.kubernetes.io/name=coder -n coder | grep -i oidc

# Test OIDC token decode
# (Use jwt.io or similar to decode and inspect tokens)
```

---

## References

- [Coder OIDC Authentication](https://coder.com/docs/admin/users/oidc-auth)
- [Coder IDP Sync](https://coder.com/docs/admin/users/idp-sync)
- [Microsoft Entra ID OIDC](https://learn.microsoft.com/en-us/entra/identity-platform/v2-protocols-oidc)
- [Okta OIDC](https://developer.okta.com/docs/concepts/oauth-openid/)
- [Google OIDC](https://developers.google.com/identity/openid-connect/openid-connect)
