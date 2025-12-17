# Coder Security Controls

This document details the security controls implemented for the Coder platform deployment, focusing on segregation of duties, privilege escalation prevention, and authentication requirements.

## Table of Contents

1. [Segregation of Duties](#segregation-of-duties)
2. [Privilege Escalation Prevention](#privilege-escalation-prevention)
3. [IDP Authentication Requirements](#idp-authentication-requirements)
4. [Compliance Checklist](#compliance-checklist)

---

## Segregation of Duties

**Requirements:** 12a.7, 12a.8

### Overview

Segregation of duties (SoD) ensures that no single individual has control over multiple critical functions that could lead to fraud, errors, or security breaches. In the Coder platform, this is enforced through role mutual exclusion and permission boundaries.

### Mutual Exclusion Rules

The following role combinations are **prohibited**:

| Role A | Role B | Rationale |
|--------|--------|-----------|
| Template Admin | User Admin | Prevents a single user from controlling both who can access the platform AND what templates they can use |

**Why This Matters:**
- A user with both roles could create a malicious template and grant themselves access
- Separating these roles ensures template changes require approval from someone who cannot also grant access
- This follows the principle of "two-person integrity" for sensitive operations

### IDP Group Configuration

To enforce segregation of duties at the IDP level:

```
# IDP Group Structure (example for Azure AD / Entra ID)

Group: coder-platform-admins
  - Members: User Admin personnel only
  - Exclusion: Members of coder-template-owners

Group: coder-template-owners
  - Members: Template Admin personnel only
  - Exclusion: Members of coder-platform-admins
```

**Azure AD Conditional Access Policy Example:**
```json
{
  "displayName": "Coder SoD - Template Admin Exclusion",
  "conditions": {
    "users": {
      "includeGroups": ["coder-platform-admins"]
    }
  },
  "grantControls": {
    "operator": "AND",
    "builtInControls": ["block"],
    "customAuthenticationFactors": [],
    "termsOfUse": []
  }
}
```

### Quarterly Access Reviews

**Requirement:** 12c.8

Access reviews must be conducted quarterly to ensure:

1. **No SoD Violations:** Verify no users are members of both `coder-platform-admins` and `coder-template-owners`
2. **Role Appropriateness:** Confirm users have the minimum role necessary for their function
3. **Stale Access:** Remove access for users who no longer require it
4. **Owner Role Audit:** Document and verify all Owner role assignments

**Review Checklist:**
- [ ] Export group memberships from IDP
- [ ] Cross-reference `coder-platform-admins` and `coder-template-owners` for overlaps
- [ ] Verify Owner role holders (should be 2-3 individuals max)
- [ ] Review and document any exceptions
- [ ] Update access as needed
- [ ] Document review completion and findings

### Monitoring for SoD Violations

Configure alerts for potential SoD violations:

**CloudWatch Insights Query:**
```sql
fields @timestamp, @message, user.email, user.roles
| filter @message like /role.*assign/
| filter user.roles like /user-admin/ and user.roles like /template-admin/
| sort @timestamp desc
| limit 100
```

**Prometheus Alert Rule:**
```yaml
- alert: CoderSoDViolation
  expr: |
    count(
      coderd_user_roles{role="user-admin"} 
      and on(user_id) 
      coderd_user_roles{role="template-admin"}
    ) > 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Segregation of duties violation detected"
    description: "A user has both User Admin and Template Admin roles"
```

---

## Privilege Escalation Prevention

**Requirement:** 12a.8

### Overview

Privilege escalation prevention ensures users cannot elevate their own permissions beyond what has been explicitly granted by an authorized administrator.

### Control Mechanisms

#### 1. Role Assignment Restrictions

| Role | Can Assign Roles | Restrictions |
|------|------------------|--------------|
| Owner | All roles | Only role that can assign Owner |
| User Admin | Member only | Cannot assign admin roles |
| Template Admin | None | Cannot assign any roles |
| Auditor | None | Read-only access |
| Member | None | No administrative access |

#### 2. Self-Service Limitations

Users **cannot**:
- Add themselves to groups
- Modify their own role assignments
- Approve their own template access requests
- Create or modify their own quota allowances
- Bypass MFA requirements

#### 3. Group Membership Control

Group membership is controlled exclusively through:
- IDP group sync (primary method)
- Owner manual assignment (emergency only)

Users cannot request or approve their own group membership changes.

#### 4. Template Access Control

Template access follows a request-approval workflow:
1. User requests access to a template
2. Template Admin reviews and approves/denies
3. User cannot approve their own requests
4. All access changes are logged

### Audit Trail Requirements

**Requirement:** 12a.9

All privilege-related changes must be logged:

| Event | Logged | Alert | Approval Required |
|-------|--------|-------|-------------------|
| Owner role assignment | ✅ | ✅ | ✅ (Documented) |
| Admin role assignment | ✅ | ✅ | ❌ |
| Member role assignment | ✅ | ❌ | ❌ |
| Group membership change | ✅ | ❌ | ❌ |
| Template access grant | ✅ | ❌ | ❌ |
| Quota modification | ✅ | ❌ | ❌ |

### Implementation in Terraform

The coderd provider enforces these controls through:

```hcl
# Groups are managed declaratively - users cannot self-modify
resource "coderd_group" "platform_admins" {
  organization_id = data.coderd_organization.default[0].id
  name            = "coder-platform-admins"
  display_name    = "Platform Administrators"
  quota_allowance = var.platform_admin_quota_allowance
  # Members managed via IDP sync, not Terraform
}

# Role mapping is configured at deployment time
# Users cannot modify the mapping
variable "oidc_group_mapping" {
  default = jsonencode({
    "coder-platform-admins" = "user-admin"
    "coder-template-owners" = "template-admin"
    "coder-security-audit"  = "auditor"
    "developers"            = "member"
  })
}
```

---

## IDP Authentication Requirements

**Requirement:** 12e.1

The identity provider must support and enforce the following security controls.

### Multi-Factor Authentication (MFA)

| Requirement | Value | Implementation |
|-------------|-------|----------------|
| MFA Enforcement | Required for all users | IDP conditional access policy |
| MFA Level | Before Coder access | IDP authentication flow |
| Supported Methods | TOTP, Push, FIDO2 | IDP configuration |

**IDP Configuration Checklist:**
- [ ] Enable MFA requirement for all users
- [ ] Configure MFA methods (TOTP, push notifications, hardware keys)
- [ ] Create conditional access policy requiring MFA for Coder application
- [ ] Test MFA flow with test users
- [ ] Document MFA enrollment process for users

### Session Management

| Setting | Value | Coder Configuration |
|---------|-------|---------------------|
| Session Expiration | 8 hours inactivity | `CODER_SESSION_DURATION=8h` |
| Re-authentication | Required after expiration | Automatic via OIDC |
| Token Lifetime | 8 hours | Matches session duration |

**Helm Values Configuration:**
```yaml
coder:
  env:
    - name: CODER_SESSION_DURATION
      value: "8h"
    - name: CODER_DISABLE_PASSWORD_AUTH
      value: "true"
```

### Account Lockout

| Setting | Value | Implementation |
|---------|-------|----------------|
| Failed Attempts | 5 consecutive | IDP policy |
| Lockout Duration | 30 minutes | IDP policy |
| Alert Generation | Security team | IDP + SIEM integration |

**IDP Configuration (Azure AD Example):**
```json
{
  "lockoutThreshold": 5,
  "lockoutDurationInSeconds": 1800,
  "lockoutObservationWindow": 1800
}
```

### Concurrent Session Detection

| Setting | Value | Implementation |
|---------|-------|----------------|
| Detection | Enabled | IDP sign-in logs |
| Alert Trigger | Different locations | IDP risk detection |
| Response | Security alert | IDP + SIEM |

**Monitoring Query (Azure AD Sign-in Logs):**
```kusto
SigninLogs
| where TimeGenerated > ago(1h)
| where AppDisplayName == "Coder"
| summarize SessionCount = dcount(CorrelationId), 
            Locations = make_set(Location) by UserPrincipalName
| where SessionCount > 1 and array_length(Locations) > 1
```

### Authentication Logging

All authentication events must be logged:

| Event | Log Destination | Retention |
|-------|-----------------|-----------|
| Successful login | IDP + CloudWatch | 90 days |
| Failed login | IDP + CloudWatch | 90 days |
| Account lockout | IDP + CloudWatch + Alert | 90 days |
| MFA challenge | IDP | 90 days |
| Session expiration | Coder audit log | 90 days |

---

## Compliance Checklist

Use this checklist to verify security controls are properly implemented:

### Segregation of Duties (12a.7)
- [ ] Template Admin and User Admin roles are mutually exclusive
- [ ] IDP groups configured with exclusion rules
- [ ] Quarterly access reviews scheduled
- [ ] Monitoring alerts configured for SoD violations

### Privilege Escalation Prevention (12a.8)
- [ ] Role assignment restrictions documented and enforced
- [ ] Self-service limitations in place
- [ ] Audit logging enabled for all privilege changes
- [ ] Owner role changes require documented approval

### MFA Enforcement (12e.1)
- [ ] MFA required for all users at IDP level
- [ ] MFA enforced before Coder access
- [ ] Supported MFA methods configured
- [ ] MFA enrollment process documented

### Session Management (12e.1)
- [ ] Session expiration set to 8 hours
- [ ] Re-authentication required after expiration
- [ ] Password authentication disabled (OIDC only)

### Account Lockout (12e.1)
- [ ] Lockout after 5 failed attempts
- [ ] 30-minute lockout duration
- [ ] Security team alerts on lockout events

### Concurrent Session Detection (12e.1)
- [ ] Detection enabled in IDP
- [ ] Alerts configured for suspicious sessions
- [ ] Response procedures documented

---

## Service Account Token Security

For detailed service account token management including:
- CI/CD authentication configuration (Requirement 12d.3)
- 90-day token expiration and rotation (Requirement 12d.6)
- Template Admin scope restrictions (Requirement 12d.7)
- Secrets Manager storage (Requirement 12d.8)
- Token compromise response procedures (Requirement 12d.9)

See [Service Account Token Management](service-account-token-management.md).

---

## References

- [Coder Security Best Practices](https://coder.com/docs/tutorials/best-practices/security-best-practices)
- [Coder OIDC Authentication](https://coder.com/docs/admin/users/oidc-auth)
- [Coder Groups and Roles](https://coder.com/docs/admin/users/groups-roles)
- [Service Account Token Management](service-account-token-management.md)
- [NIST SP 800-53 AC-5: Separation of Duties](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)
- [CIS Controls v8 - Control 6: Access Control Management](https://www.cisecurity.org/controls/access-control-management)
