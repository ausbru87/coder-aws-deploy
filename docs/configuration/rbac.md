# Coder RBAC Configuration Guide

This document defines the role-based access control (RBAC) configuration for the Coder platform deployment. It covers role definitions, permissions, group mappings, and security controls.

## Table of Contents

1. [Role Definitions](#role-definitions)
2. [Permission Matrix](#permission-matrix)
3. [IDP Group Mappings](#idp-group-mappings)
4. [Segregation of Duties](#segregation-of-duties)
5. [IDP Authentication Requirements](#idp-authentication-requirements)
6. [Implementation Details](#implementation-details)

---

## Role Definitions

The Coder platform implements five distinct roles with least-privilege permissions as required by Requirements 12a.1-12a.5.

### Owner Role

**Requirement:** 12a.1

| Attribute | Value |
|-----------|-------|
| **Maximum Holders** | 2-3 individuals |
| **Purpose** | Full system administration and emergency access |
| **Assignment** | Manual assignment with documented approval |

**Permissions:**
- Full administrative access to all Coder features
- Organization management (create, modify, delete)
- License management
- System-wide settings configuration
- User and group management
- Template management (all templates)
- Audit log access
- Provisioner management
- Emergency access for incident response

**Restrictions:**
- Cannot access user workspace contents or data (Requirement 12a.10)
- All role assignments must be logged
- Changes to Owner role require documented approval (Requirement 12a.9)

**Use Cases:**
- Initial platform setup and configuration
- Emergency incident response
- License renewal and management
- Organization-level policy changes

---

### User Admin Role

**Requirement:** 12a.2

| Attribute | Value |
|-----------|-------|
| **IDP Group** | `coder-platform-admins` |
| **Purpose** | User lifecycle management |
| **Assignment** | Via IDP group sync |

**Permissions:**
- Create and delete users
- Manage group membership
- Assign Member role to users
- View user activity and status
- Suspend and reactivate user accounts
- View audit logs related to user management

**Restrictions:**
- Cannot create or modify templates
- Cannot assign Template Admin or Owner roles
- Cannot access user workspace contents
- Cannot modify system-wide settings
- Mutually exclusive with Template Admin role (Requirement 12a.7)

**Use Cases:**
- Onboarding new developers
- Offboarding terminated employees
- Managing team membership changes
- User access reviews

---

### Template Admin Role

**Requirement:** 12a.3

| Attribute | Value |
|-----------|-------|
| **IDP Group** | `coder-template-owners` |
| **Purpose** | Template lifecycle management |
| **Assignment** | Via IDP group sync |

**Permissions:**
- Create, modify, and delete templates
- Assign template access to groups
- Manage template versions
- View template usage metrics
- Configure template parameters
- Deprecate and archive templates

**Restrictions:**
- Cannot create or modify users
- Cannot manage group membership
- Cannot assign roles to users
- Cannot access user workspace contents
- Mutually exclusive with User Admin role (Requirement 12a.7)

**Use Cases:**
- Creating new workspace templates
- Updating template configurations
- Managing template access permissions
- Template deprecation and archival

---

### Auditor Role

**Requirement:** 12a.4

| Attribute | Value |
|-----------|-------|
| **IDP Group** | `coder-security-audit` |
| **Purpose** | Security monitoring and compliance |
| **Assignment** | Via IDP group sync |

**Permissions:**
- Read-only access to audit logs
- View system metrics and dashboards
- View user activity reports
- View template usage statistics
- View security events and alerts
- Export audit data for compliance

**Restrictions:**
- Cannot modify any system settings
- Cannot create or manage users
- Cannot create or manage templates
- Cannot create workspaces
- Read-only access only

**Use Cases:**
- Security compliance audits
- Incident investigation
- Access review reporting
- Compliance documentation

---

### Developer/Member Role

**Requirement:** 12a.5

| Attribute | Value |
|-----------|-------|
| **IDP Group** | `developers` |
| **Purpose** | Standard developer access |
| **Assignment** | Via IDP group sync (default role) |

**Permissions:**
- Create workspaces from assigned templates
- Manage own workspaces (start, stop, delete)
- Access own workspace contents
- Configure personal workspace settings
- View assigned templates
- Use external authentication (Git provider)

**Restrictions:**
- Cannot access other users' workspaces
- Cannot create or modify templates
- Cannot manage users or groups
- Cannot view audit logs
- Limited to assigned templates only
- Maximum 3 workspaces per user (Requirement 14.15)

**Use Cases:**
- Daily development work
- Creating development environments
- Managing personal workspaces

---

## Permission Matrix

| Permission | Owner | User Admin | Template Admin | Auditor | Member |
|------------|:-----:|:----------:|:--------------:|:-------:|:------:|
| **Organization Management** |
| Create/Delete Organizations | ✅ | ❌ | ❌ | ❌ | ❌ |
| Modify Organization Settings | ✅ | ❌ | ❌ | ❌ | ❌ |
| **User Management** |
| Create Users | ✅ | ✅ | ❌ | ❌ | ❌ |
| Delete Users | ✅ | ✅ | ❌ | ❌ | ❌ |
| Suspend/Reactivate Users | ✅ | ✅ | ❌ | ❌ | ❌ |
| Manage Group Membership | ✅ | ✅ | ❌ | ❌ | ❌ |
| Assign Member Role | ✅ | ✅ | ❌ | ❌ | ❌ |
| Assign Admin Roles | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Template Management** |
| Create Templates | ✅ | ❌ | ✅ | ❌ | ❌ |
| Modify Templates | ✅ | ❌ | ✅ | ❌ | ❌ |
| Delete Templates | ✅ | ❌ | ✅ | ❌ | ❌ |
| Assign Template Access | ✅ | ❌ | ✅ | ❌ | ❌ |
| View All Templates | ✅ | ❌ | ✅ | ✅ | ❌ |
| **Workspace Management** |
| Create Own Workspaces | ✅ | ✅ | ✅ | ❌ | ✅ |
| Manage Own Workspaces | ✅ | ✅ | ✅ | ❌ | ✅ |
| Access Other Users' Workspaces | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Audit & Monitoring** |
| View Audit Logs | ✅ | ❌ | ❌ | ✅ | ❌ |
| View System Metrics | ✅ | ❌ | ❌ | ✅ | ❌ |
| Export Audit Data | ✅ | ❌ | ❌ | ✅ | ❌ |
| **System Administration** |
| Manage Provisioners | ✅ | ❌ | ❌ | ❌ | ❌ |
| Manage Licenses | ✅ | ❌ | ❌ | ❌ | ❌ |
| System Settings | ✅ | ❌ | ❌ | ❌ | ❌ |

---

## IDP Group Mappings

The following IDP groups are synchronized to Coder roles via OIDC group sync (Requirements 12c.1-12c.10).


### Group Mapping Table

| IDP Group | Coder Role | Quota Allowance | Requirements |
|-----------|------------|-----------------|--------------|
| `coder-platform-admins` | User Admin | 10 workspaces | 12c.4 |
| `coder-template-owners` | Template Admin | 5 workspaces | 12c.5 |
| `coder-security-audit` | Auditor | 0 workspaces | 12c.6 |
| `developers` | Member | 3 workspaces | 12c.7 |

### Group Sync Configuration

Group synchronization is configured via the following OIDC settings in the Coder Helm values:

```yaml
# OIDC Group Sync Configuration
CODER_OIDC_GROUP_FIELD: "groups"
CODER_OIDC_GROUP_REGEX_FILTER: "^coder-.*|^developers$"
CODER_OIDC_GROUP_AUTO_CREATE: "true"
```

### Automatic User Provisioning

**Requirement:** 12c.9

Users are automatically provisioned when they authenticate via the IDP:

1. User authenticates with IDP (OIDC flow)
2. Coder receives user claims including group membership
3. User account is created if it doesn't exist
4. Group memberships are synchronized from IDP claims
5. Role permissions are applied based on group membership

### User Deprovisioning

**Requirement:** 12c.10

User access must be revoked within 30 days of termination:

1. **IDP-Initiated:** When user is removed from IDP groups, Coder group membership is updated on next sync
2. **Manual Process:** For immediate revocation:
   - Remove user from all IDP groups
   - Suspend user account in Coder (User Admin action)
   - Delete user workspaces if required

**Deprovisioning Checklist:**
- [ ] Remove user from all IDP Coder groups
- [ ] Verify group sync has propagated (check Coder UI)
- [ ] Suspend user account in Coder
- [ ] Delete or transfer user workspaces
- [ ] Document deprovisioning in access log

---

## Segregation of Duties

**Requirements:** 12a.7, 12a.8

### Mutual Exclusion Rules

The following role combinations are prohibited to enforce segregation of duties:

| Role A | Role B | Reason |
|--------|--------|--------|
| Template Admin | User Admin | Prevents single user from controlling both user access and template deployment |

### Implementation

Segregation of duties is enforced through:

1. **IDP Group Configuration:** Users should not be members of both `coder-platform-admins` and `coder-template-owners` groups
2. **Quarterly Access Reviews:** Review group memberships to ensure no violations (Requirement 12c.8)
3. **Monitoring:** Alert on users with conflicting role assignments

### Privilege Escalation Prevention

**Requirement:** 12a.8

Users cannot elevate their own permissions:

1. **Role Assignment Restrictions:**
   - Only Owners can assign Owner role
   - User Admins can only assign Member role
   - Template Admins cannot assign any roles

2. **Self-Service Limitations:**
   - Users cannot add themselves to groups
   - Users cannot modify their own role assignments
   - Users cannot approve their own template access requests

3. **Audit Trail:**
   - All role changes are logged
   - Owner role changes require documented approval
   - Alerts generated for suspicious privilege changes

---

## IDP Authentication Requirements

**Requirement:** 12e.1

The selected identity provider must support the following authentication and security capabilities.

### Multi-Factor Authentication (MFA)

| Requirement | Configuration |
|-------------|---------------|
| MFA Enforcement | Required for all users |
| MFA Level | Enforced at IDP level before Coder access |
| Supported Methods | TOTP, Push notifications, Hardware keys (FIDO2) |

**Implementation:**
- Configure MFA requirement in IDP conditional access policies
- Coder relies on IDP for MFA enforcement
- No additional MFA configuration in Coder

### Session Management

| Setting | Value | Requirement |
|---------|-------|-------------|
| Session Expiration | 8 hours of inactivity | 12e.1 |
| Re-authentication | Required after session expiration | 12e.1 |
| Session Token Lifetime | Configurable via `CODER_SESSION_DURATION` | 12e.1 |

**Coder Configuration:**
```yaml
CODER_SESSION_DURATION: "8h"
```

### Account Lockout

| Setting | Value | Requirement |
|---------|-------|-------------|
| Failed Attempts Threshold | 5 consecutive failures | 12e.1 |
| Lockout Duration | 30 minutes | 12e.1 |
| Alert Generation | Security team notification | 12e.1 |

**Note:** Account lockout is enforced at the IDP level. Configure the following in your IDP:
- Maximum failed login attempts: 5
- Lockout duration: 30 minutes
- Alert on lockout events to security team

### Concurrent Session Detection

| Setting | Value | Requirement |
|---------|-------|-------------|
| Detection | Enabled | 12e.1 |
| Alert Trigger | Sessions from different locations | 12e.1 |
| Response | Security alert to user and security team | 12e.1 |

**Implementation:**
- Configure IDP to detect concurrent sessions from different IP addresses/locations
- Generate security alerts for suspicious concurrent access
- Consider implementing session termination for high-risk scenarios

### Authentication Logging

| Event | Logged | Alert |
|-------|--------|-------|
| Successful login | ✅ | ❌ |
| Failed login attempt | ✅ | After 3 failures |
| Account lockout | ✅ | ✅ (Security team) |
| Password reset | ✅ | ✅ (User notification) |
| MFA enrollment/change | ✅ | ✅ (User notification) |

---

## Implementation Details

### Terraform Resources

The RBAC configuration is implemented via the coderd Terraform provider in `terraform/modules/coder/coderd_provider.tf`:

```hcl
# Platform Administrators Group
resource "coderd_group" "platform_admins" {
  organization_id = data.coderd_organization.default[0].id
  name            = "coder-platform-admins"
  display_name    = "Platform Administrators"
  quota_allowance = 10
}

# Template Owners Group
resource "coderd_group" "template_owners" {
  organization_id = data.coderd_organization.default[0].id
  name            = "coder-template-owners"
  display_name    = "Template Owners"
  quota_allowance = 5
}

# Security Auditors Group
resource "coderd_group" "security_audit" {
  organization_id = data.coderd_organization.default[0].id
  name            = "coder-security-audit"
  display_name    = "Security Auditors"
  quota_allowance = 0
}

# Developers Group
resource "coderd_group" "developers" {
  organization_id = data.coderd_organization.default[0].id
  name            = "developers"
  display_name    = "Developers"
  quota_allowance = 3
}
```

### Helm Values Configuration

OIDC and session settings are configured in `coder-values.yaml`:

```yaml
coder:
  env:
    # OIDC Authentication
    - name: CODER_OIDC_ISSUER_URL
      value: "${oidc_issuer_url}"
    - name: CODER_OIDC_CLIENT_ID
      value: "${oidc_client_id}"
    
    # Group Sync
    - name: CODER_OIDC_GROUP_FIELD
      value: "${oidc_group_field}"
    - name: CODER_OIDC_GROUP_REGEX_FILTER
      value: "${oidc_group_regex_filter}"
    - name: CODER_OIDC_GROUP_AUTO_CREATE
      value: "true"
    
    # Session Management
    - name: CODER_SESSION_DURATION
      value: "${session_duration}"
    
    # Workspace Quotas
    - name: CODER_USER_WORKSPACE_QUOTA
      value: "${max_workspaces_per_user}"
```

### Verification Commands

After deployment, verify RBAC configuration:

```bash
# List all groups
coder groups list

# Verify group membership
coder groups show coder-platform-admins
coder groups show coder-template-owners
coder groups show coder-security-audit
coder groups show developers

# Check user roles
coder users list --columns=username,status,roles

# Verify quota settings
coder users show <username> --json | jq '.quota'
```

---

## Workspace Access Controls

**Requirements:** 12d.1, 12d.2

### Single Owner Per Workspace

**Requirement:** 12d.1

Each workspace has a single owner who is the creator. Ownership cannot be transferred.

| Attribute | Value |
|-----------|-------|
| Owner Assignment | Automatic (creator) |
| Owner Transfer | Not supported |
| Multiple Owners | Not allowed |

### Workspace Owner Permissions

**Requirement:** 12d.2

Workspace owners have full control over their workspaces:

| Permission | Owner | Other Users | Admins |
|------------|:-----:|:-----------:|:------:|
| Start workspace | ✅ | ❌ | ❌ |
| Stop workspace | ✅ | ❌ | ✅* |
| Delete workspace | ✅ | ❌ | ✅* |
| Access workspace shell | ✅ | ❌ | ❌ |
| View workspace logs | ✅ | ❌ | ❌ |
| Modify workspace settings | ✅ | ❌ | ❌ |
| View workspace data | ✅ | ❌ | ❌ |

*Admins can stop/delete workspaces for operational reasons but cannot access workspace contents (Requirement 12a.10).

### Workspace Isolation

Workspaces are isolated from each other through:

1. **API Level**: All API requests validate workspace ownership
2. **Agent Level**: Workspace agents only accept connections from the owner
3. **Network Level**: NetworkPolicies isolate workspaces from each other (Requirement 3.1c)

### Admin Access Restrictions

**Requirement:** 12a.10

Coder Owners and Admins:
- ✅ Can view workspace metadata (name, status, template)
- ✅ Can stop or delete workspaces for operational reasons
- ❌ Cannot access workspace shell or terminal
- ❌ Cannot view workspace file contents
- ❌ Cannot view workspace logs containing user data
- ❌ Cannot impersonate workspace owners

This ensures administrative functions can be performed without compromising user privacy or data security.

For detailed service account token management and CI/CD access controls, see [Service Account Token Management](service-account-token-management.md).

---

## References

- [Coder RBAC Documentation](https://coder.com/docs/admin/users/groups-roles)
- [Coder OIDC Authentication](https://coder.com/docs/admin/users/oidc-auth)
- [Coder Group Sync](https://coder.com/docs/admin/users/idp-sync)
- [Coder Quotas](https://coder.com/docs/admin/users/quotas)
- [coderd Terraform Provider](https://registry.terraform.io/providers/coder/coderd/latest/docs)
- [Service Account Token Management](service-account-token-management.md)
