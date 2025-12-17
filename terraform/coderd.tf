# Coderd Provider Configuration for Day 1/2 Operations
# This file configures the coderd Terraform provider for declarative Coder management
# Reference: https://registry.terraform.io/providers/coder/coderd/latest/docs

# =============================================================================
# Provider Configuration
# =============================================================================

# The coderd provider requires Coder to be deployed first
# Use depends_on or run in a separate apply after initial deployment

provider "coderd" {
  # URL of the Coder deployment
  url = module.coder.access_url

  # Authentication token - use a service account token with appropriate permissions
  # Store in environment variable: CODER_SESSION_TOKEN
  # Or use token variable (not recommended for production)
  # token = var.coder_admin_token
}

# =============================================================================
# Organization Configuration
# =============================================================================

data "coderd_organization" "default" {
  is_default = true

  depends_on = [module.coder]
}

# =============================================================================
# Group Configuration (IDP Sync Support)
# =============================================================================

# Platform Administrators - maps to User Admin role
# IDP group: coder-platform-admins
resource "coderd_group" "platform_admins" {
  organization_id = data.coderd_organization.default.id
  name            = "coder-platform-admins"
  display_name    = "Platform Administrators"

  # Avatar URL (optional)
  avatar_url = ""

  # Quota allowance (optional, in credits)
  quota_allowance = 0
}

# Template Owners - maps to Template Admin role
# IDP group: coder-template-owners
resource "coderd_group" "template_owners" {
  organization_id = data.coderd_organization.default.id
  name            = "coder-template-owners"
  display_name    = "Template Owners"
  quota_allowance = 0
}

# Security Auditors - maps to Auditor role
# IDP group: coder-security-audit
resource "coderd_group" "security_audit" {
  organization_id = data.coderd_organization.default.id
  name            = "coder-security-audit"
  display_name    = "Security Auditors"
  quota_allowance = 0
}

# Developers - maps to Member role
# IDP group: developers
resource "coderd_group" "developers" {
  organization_id = data.coderd_organization.default.id
  name            = "developers"
  display_name    = "Developers"
  quota_allowance = 100 # Default quota for developers
}

# =============================================================================
# Template Management
# =============================================================================

# Templates are managed via CI/CD pipeline pushing to Coder
# The coderd_template resource can be used for declarative template management

# Example template resource (uncomment when templates are ready):
# resource "coderd_template" "pod_swdev" {
#   organization_id = data.coderd_organization.default.id
#   name            = "pod-swdev"
#   display_name    = "Pod Software Development"
#   description     = "Pod-based software development workspace"
#   icon            = "/emojis/1f4bb.png"
#   
#   # Template versions are managed via directory or archive
#   versions = [{
#     directory = "${path.module}/templates/pod-swdev"
#     active    = true
#     name      = "v1.0.0"
#   }]
#   
#   # Access control
#   acl = {
#     groups = [
#       {
#         id   = coderd_group.developers.id
#         role = "use"
#       },
#       {
#         id   = coderd_group.template_owners.id
#         role = "admin"
#       }
#     ]
#   }
# }

# =============================================================================
# Provisioner Key Management
# =============================================================================

# Provisioner keys for external provisioner authentication
resource "coderd_provisioner_key" "external" {
  organization_id = data.coderd_organization.default.id
  name            = "external-provisioner-key"

  # Tags for provisioner scoping
  tags = {
    scope = "organization"
  }
}

# Store provisioner key in Kubernetes secret
resource "kubernetes_secret_v1" "provisioner_key" {
  metadata {
    name      = "coder-provisioner-key"
    namespace = module.coder.provisioner_namespace
  }

  data = {
    key = coderd_provisioner_key.external.key
  }

  depends_on = [coderd_provisioner_key.external]
}

# =============================================================================
# Outputs
# =============================================================================

output "coderd_organization_id" {
  description = "Default organization ID"
  value       = data.coderd_organization.default.id
}

output "coderd_groups" {
  description = "Created group IDs"
  value = {
    platform_admins = coderd_group.platform_admins.id
    template_owners = coderd_group.template_owners.id
    security_audit  = coderd_group.security_audit.id
    developers      = coderd_group.developers.id
  }
}
