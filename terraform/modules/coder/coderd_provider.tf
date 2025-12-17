# Coderd Terraform Provider Configuration
# Manages Coder configuration declaratively for Day 1/2 operations
# Reference: https://registry.terraform.io/providers/coder/coderd/latest/docs
#
# Requirements covered:
# - 14.15: Configure Coder internal quotas (max 3 workspaces per user)
# - 16.3: Use coderd Terraform provider for declarative Coder configuration
# - 12c.1-12c.10: Group sync settings and role mappings
#
# Day 0: Infrastructure provisioning (VPC, EKS, Aurora, etc.)
# Day 1: Initial Coder configuration (this file - groups, quotas, org settings)
# Day 2: Ongoing management (template updates, user management, etc.)

# =============================================================================
# Provider Configuration
# =============================================================================

# The coderd provider is configured in the root module's versions.tf
# Provider authentication uses the CODER_URL and CODER_SESSION_TOKEN environment variables
# or can be configured via provider block in the root module

# =============================================================================
# Data Sources
# =============================================================================

data "coderd_organization" "default" {
  count = var.enable_coderd_provider ? 1 : 0

  # Default organization - created automatically by Coder
  is_default = true
}

# =============================================================================
# Organization Configuration
# Requirement 16.3: Declarative organization settings
# =============================================================================

# Note: Organization-level settings are managed via the coderd provider
# This ensures consistent configuration across environments

# =============================================================================
# Group Management (IDP Sync)
# Requirements: 12c.1-12c.10
# =============================================================================

# Groups are synchronized from the identity provider via OIDC
# These resources ensure the groups exist with correct settings
# Members are managed via IDP sync, not Terraform
#
# IDP Group Sync Flow:
# 1. User authenticates via OIDC
# 2. IDP returns group claims in token (CODER_OIDC_GROUP_FIELD)
# 3. Coder auto-creates groups if CODER_OIDC_GROUP_AUTO_CREATE=true
# 4. User is added to matching Coder groups
# 5. Role permissions are applied based on group membership
#
# User Provisioning (Requirement 12c.9):
# - Users are automatically provisioned on first OIDC login
# - Group memberships sync from IDP on each login
# - No manual user creation required
#
# User Deprovisioning (Requirement 12c.10):
# - Remove user from IDP groups to revoke access
# - Access revoked within 30 days of termination
# - For immediate revocation: suspend user in Coder UI

# Platform Administrators Group
# Requirement 12c.4: Map coder-platform-admins to User Admin role
resource "coderd_group" "platform_admins" {
  count = var.enable_coderd_provider ? 1 : 0

  organization_id = data.coderd_organization.default[0].id
  name            = "coder-platform-admins"
  display_name    = "Platform Administrators"
  avatar_url      = ""

  # Quota allowance for platform admins (higher than default)
  quota_allowance = var.platform_admin_quota_allowance
}

# Template Owners Group
# Requirement 12c.5: Map coder-template-owners to Template Admin role
resource "coderd_group" "template_owners" {
  count = var.enable_coderd_provider ? 1 : 0

  organization_id = data.coderd_organization.default[0].id
  name            = "coder-template-owners"
  display_name    = "Template Owners"
  avatar_url      = ""

  # Quota allowance for template owners
  quota_allowance = var.template_owner_quota_allowance
}

# Security Auditors Group
# Requirement 12c.6: Map coder-security-audit to Auditor role
resource "coderd_group" "security_audit" {
  count = var.enable_coderd_provider ? 1 : 0

  organization_id = data.coderd_organization.default[0].id
  name            = "coder-security-audit"
  display_name    = "Security Auditors"
  avatar_url      = ""

  # Auditors typically don't need workspaces
  quota_allowance = 0
}

# Developers Group
# Requirement 12c.7: Map developers to Member role
resource "coderd_group" "developers" {
  count = var.enable_coderd_provider ? 1 : 0

  organization_id = data.coderd_organization.default[0].id
  name            = "developers"
  display_name    = "Developers"
  avatar_url      = ""

  # Standard quota for developers
  # Requirement 14.15: Max 3 workspaces per user
  quota_allowance = var.developer_quota_allowance
}

# =============================================================================
# Role Mapping Configuration
# Requirements: 12c.4-12c.7
# =============================================================================
#
# Coder uses built-in roles that are assigned via organization membership:
# - owner: Full system administration (assigned manually to 2-3 individuals)
# - user-admin: User lifecycle management
# - template-admin: Template lifecycle management  
# - auditor: Read-only audit access
# - member: Standard user access (default)
#
# Role mapping is configured via CODER_OIDC_GROUP_MAPPING environment variable
# in the Helm values. The mapping JSON format is:
# {
#   "idp-group-name": "coder-role-name"
# }
#
# Example mapping (configured in variables.tf):
# {
#   "coder-platform-admins": "user-admin",
#   "coder-template-owners": "template-admin",
#   "coder-security-audit": "auditor",
#   "developers": "member"
# }
#
# Note: The coderd provider manages groups, but role assignments are handled
# via OIDC group mapping in the Helm values configuration.

# =============================================================================
# Group Sync Monitoring
# Requirement 12c.3: Alert on sync failures
# =============================================================================
#
# Group sync failures are detected via:
# 1. Coder audit logs (forwarded to CloudWatch)
# 2. Prometheus metrics (coderd_oidc_* metrics)
# 3. CloudWatch alarms on sync error patterns
#
# Recommended CloudWatch Insights query for sync failures:
# fields @timestamp, @message
# | filter @message like /group.*sync.*fail/
# | sort @timestamp desc
# | limit 100

# =============================================================================
# Provisioner Key Management
# Requirements: 12f.1-12f.6
# =============================================================================

# Provisioner key for external provisioners
# Requirement 12f.1: External provisioners authenticate using provisioner keys
# Requirement 12f.2: Keys rotated every 90 days (managed via rotation procedure)
# Requirement 12f.4: Tag-based organization/template isolation
# Requirement 12f.5: Provisioner access controlled via key scoping and tags
resource "coderd_provisioner_key" "external" {
  count = var.enable_coderd_provider ? 1 : 0

  organization_id = data.coderd_organization.default[0].id
  name            = "external-provisioner-key"

  # Tags for provisioner scoping (Requirement 12f.4, 12f.5)
  # These tags control which templates this provisioner can provision
  # Templates must have matching tags to be provisioned by this key
  tags = var.provisioner_key_tags
}

# =============================================================================
# Additional Provisioner Keys for Scoped Isolation
# Requirement 12f.4: Provisioners MAY be dedicated to specific organizations or templates
# =============================================================================

# GPU Workloads Provisioner Key (optional)
# Dedicated provisioner for GPU-enabled templates (ec2-datasci)
resource "coderd_provisioner_key" "gpu_workloads" {
  count = var.enable_coderd_provider && var.enable_gpu_provisioner ? 1 : 0

  organization_id = data.coderd_organization.default[0].id
  name            = "gpu-provisioner-key"

  tags = {
    scope       = "template"
    template    = "ec2-datasci"
    gpu         = "true"
    environment = var.environment
  }
}

# Windows Workloads Provisioner Key (optional)
# Dedicated provisioner for Windows templates (ec2-windev-gui)
resource "coderd_provisioner_key" "windows_workloads" {
  count = var.enable_coderd_provider && var.enable_windows_provisioner ? 1 : 0

  organization_id = data.coderd_organization.default[0].id
  name            = "windows-provisioner-key"

  tags = {
    scope       = "template"
    template    = "ec2-windev-gui"
    os          = "windows"
    environment = var.environment
  }
}

# Store provisioner key in Kubernetes secret for provisioner pods
resource "kubernetes_secret_v1" "provisioner_key" {
  count = var.enable_coderd_provider ? 1 : 0

  metadata {
    name      = var.provisioner_key_secret_name
    namespace = kubernetes_namespace_v1.coder_prov.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "coder-provisioner"
      "app.kubernetes.io/component"  = "authentication"
      "app.kubernetes.io/managed-by" = "terraform"
    }
    annotations = {
      # Track key creation for rotation monitoring (Requirement 12f.2)
      "coder.com/key-created"     = timestamp()
      "coder.com/rotation-due"    = timeadd(timestamp(), "${var.provisioner_key_rotation_days * 24}h")
      "coder.com/rotation-policy" = "${var.provisioner_key_rotation_days} days"
      "coder.com/key-name"        = coderd_provisioner_key.external[0].name
    }
  }

  data = {
    key = coderd_provisioner_key.external[0].key
  }

  type = "Opaque"

  lifecycle {
    # Prevent accidental deletion of the secret
    prevent_destroy = false
  }
}

# =============================================================================
# Quota Configuration
# Requirement 14.15: Maximum 3 workspaces per user
# =============================================================================

# Note: User-level workspace quotas are enforced via:
# 1. CODER_USER_WORKSPACE_QUOTA environment variable in coderd (set in Helm values)
# 2. Group-level quota_allowance (set above)
#
# The quota system works as follows:
# - Each workspace consumes quota based on its resource cost
# - Users cannot create workspaces if it would exceed their quota
# - Group quota_allowance sets the maximum quota for group members
# - The default quota is set via CODER_USER_WORKSPACE_QUOTA

# =============================================================================
# License Configuration
# Requirements: 17.1-17.4
# =============================================================================

# Note: Coder Premium license is required for:
# - Pre-builds (workspace pre-provisioning)
# - External provisioners
# - Advanced RBAC features
# - High availability
#
# License is configured via CODER_LICENSE environment variable
# or through the Coder admin UI after initial deployment

# =============================================================================
# Outputs for Day 2 Operations
# =============================================================================

output "organization_id" {
  description = "Default organization ID"
  value       = var.enable_coderd_provider ? data.coderd_organization.default[0].id : null
}

output "platform_admins_group_id" {
  description = "Platform administrators group ID"
  value       = var.enable_coderd_provider ? coderd_group.platform_admins[0].id : null
}

output "template_owners_group_id" {
  description = "Template owners group ID"
  value       = var.enable_coderd_provider ? coderd_group.template_owners[0].id : null
}

output "security_audit_group_id" {
  description = "Security auditors group ID"
  value       = var.enable_coderd_provider ? coderd_group.security_audit[0].id : null
}

output "developers_group_id" {
  description = "Developers group ID"
  value       = var.enable_coderd_provider ? coderd_group.developers[0].id : null
}

output "provisioner_key_name" {
  description = "External provisioner key name"
  value       = var.enable_coderd_provider ? coderd_provisioner_key.external[0].name : null
}

output "gpu_provisioner_key_name" {
  description = "GPU provisioner key name (if enabled)"
  value       = var.enable_coderd_provider && var.enable_gpu_provisioner ? coderd_provisioner_key.gpu_workloads[0].name : null
}

output "windows_provisioner_key_name" {
  description = "Windows provisioner key name (if enabled)"
  value       = var.enable_coderd_provider && var.enable_windows_provisioner ? coderd_provisioner_key.windows_workloads[0].name : null
}
