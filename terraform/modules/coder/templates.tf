# Template Management via coderd Provider
# Requirements: 16.3, 12b.3
#
# This file manages Coder templates declaratively using the coderd Terraform provider.
# Templates are deployed and versioned through Terraform for consistent, auditable management.
#
# Template Lifecycle:
# 1. Template source code is stored in Git (terraform/modules/coder/templates/)
# 2. Terraform manages template registration and ACLs via coderd provider
# 3. Template versions are managed through Terraform state
# 4. Access permissions are controlled via coderd_template_acl resources

# =============================================================================
# Template Data Sources
# =============================================================================

# Get the template directory contents for each template
# These are used to create template versions

locals {
  # Template configurations
  templates = {
    "pod-swdev" = {
      display_name = "Pod Software Development"
      description  = "Kubernetes pod-based workspace for software development with GUI and headless options"
      icon         = "/icon/code.svg"
      directory    = "${path.module}/templates/pod-swdev"
      tags         = ["pod", "development", "linux"]
      # Auto-stop configuration (Requirements 5.9, 13.1, 13.2)
      default_ttl_ms                    = 28800000 # 8 hours
      activity_bump_ms                  = 3600000  # 1 hour
      autostop_requirement_days_of_week = ["monday", "tuesday", "wednesday", "thursday", "friday"]
      autostop_requirement_weeks        = 1
      allow_user_autostart              = true
      allow_user_autostop               = true
      # Failure TTL for failed builds
      failure_ttl_ms = 86400000 # 24 hours
      # Time before dormant workspaces are deleted
      time_til_dormant_ms            = 604800000  # 7 days
      time_til_dormant_autodelete_ms = 2592000000 # 30 days
    }
    "ec2-windev-gui" = {
      display_name                      = "EC2 Windows Development"
      description                       = "EC2-based Windows Server 2022 workspace with NICE DCV or WebRDP remote desktop"
      icon                              = "/icon/windows.svg"
      directory                         = "${path.module}/templates/ec2-windev-gui"
      tags                              = ["ec2", "windows", "gui", "development"]
      default_ttl_ms                    = 28800000
      activity_bump_ms                  = 3600000
      autostop_requirement_days_of_week = ["monday", "tuesday", "wednesday", "thursday", "friday"]
      autostop_requirement_weeks        = 1
      allow_user_autostart              = true
      allow_user_autostop               = true
      failure_ttl_ms                    = 86400000
      time_til_dormant_ms               = 604800000
      time_til_dormant_autodelete_ms    = 2592000000
    }
    "ec2-datasci" = {
      display_name                      = "EC2 Data Science"
      description                       = "EC2-based data science workspace with GPU support, Jupyter Lab, and ML tooling"
      icon                              = "/icon/jupyter.svg"
      directory                         = "${path.module}/templates/ec2-datasci"
      tags                              = ["ec2", "gpu", "data-science", "ml"]
      default_ttl_ms                    = 28800000
      activity_bump_ms                  = 3600000
      autostop_requirement_days_of_week = ["monday", "tuesday", "wednesday", "thursday", "friday"]
      autostop_requirement_weeks        = 1
      allow_user_autostart              = true
      allow_user_autostop               = true
      failure_ttl_ms                    = 86400000
      time_til_dormant_ms               = 604800000
      time_til_dormant_autodelete_ms    = 2592000000
    }
  }
}

# =============================================================================
# Template Resources
# Requirement 16.3: Use coderd_template resource for declarative template management
# =============================================================================

resource "coderd_template" "templates" {
  for_each = var.enable_coderd_provider && var.enable_template_management ? local.templates : {}

  organization_id = data.coderd_organization.default[0].id
  name            = each.key
  display_name    = each.value.display_name
  description     = each.value.description
  icon            = each.value.icon

  # Version management
  versions = [
    {
      directory = each.value.directory
      active    = true
      name      = var.template_version
      tf_vars = [
        {
          name  = "namespace"
          value = kubernetes_namespace_v1.coder_ws.metadata[0].name
        },
        {
          name  = "storage_class"
          value = var.workspace_storage_class
        }
      ]
    }
  ]

  # Auto-stop configuration (Requirements 5.9, 13.1, 13.2)
  default_ttl_ms   = each.value.default_ttl_ms
  activity_bump_ms = each.value.activity_bump_ms

  # Note: autostop_requirement block may not be supported in all coderd provider versions
  # Configure via Coder admin UI if not available in provider

  allow_user_auto_start = each.value.allow_user_autostart
  allow_user_auto_stop  = each.value.allow_user_autostop

  # Workspace lifecycle
  failure_ttl_ms                 = each.value.failure_ttl_ms
  time_til_dormant_ms            = each.value.time_til_dormant_ms
  time_til_dormant_autodelete_ms = each.value.time_til_dormant_autodelete_ms

  # Deprecation settings
  deprecation_message = var.template_deprecation_messages[each.key]

  # ACL is managed via acl block below
  acl = {
    groups = each.key == "pod-swdev" ? [
      {
        id   = coderd_group.developers[0].id
        role = "use"
      },
      {
        id   = coderd_group.platform_admins[0].id
        role = "use"
      },
      {
        id   = coderd_group.template_owners[0].id
        role = "admin"
      }
      ] : each.key == "ec2-windev-gui" ? [
      {
        id   = coderd_group.developers[0].id
        role = "use"
      },
      {
        id   = coderd_group.template_owners[0].id
        role = "admin"
      }
      ] : [
      # ec2-datasci - restricted access (Requirement 14.17)
      {
        id   = coderd_group.template_owners[0].id
        role = "admin"
      }
    ]
    users = []
  }
}

# =============================================================================
# Template Access Control Notes
# Requirement 12b.3: Configure template access permissions
# =============================================================================
#
# Template ACLs are configured inline in the coderd_template resource above.
# Access control summary:
#
# pod-swdev:
#   - developers: use
#   - platform_admins: use
#   - template_owners: admin
#
# ec2-windev-gui:
#   - developers: use
#   - template_owners: admin
#
# ec2-datasci (Requirement 14.17 - restricted access to large resources):
#   - template_owners: admin
#   - Data science group access should be added when the group is created
#

# =============================================================================
# Template Variables
# =============================================================================

variable "enable_template_management" {
  description = <<-EOT
    Enable template management via coderd provider (Requirement 16.3).
    When enabled, templates are deployed and managed declaratively through Terraform.
    Requires enable_coderd_provider to be true.
  EOT
  type        = bool
  default     = false
}

variable "template_version" {
  description = <<-EOT
    Version string for template deployments.
    Used to track template versions in Coder.
    Format: semantic versioning (e.g., "1.0.0")
  EOT
  type        = string
  default     = "1.0.0"
}

variable "workspace_storage_class" {
  description = <<-EOT
    Kubernetes storage class for workspace persistent volumes.
    Should be an encrypted storage class (e.g., gp3-encrypted).
  EOT
  type        = string
  default     = "gp3-encrypted"
}

variable "template_deprecation_messages" {
  description = <<-EOT
    Deprecation messages for templates (Requirement 12b.6).
    Set a message to mark a template as deprecated.
    Empty string means the template is not deprecated.
  EOT
  type        = map(string)
  default = {
    "pod-swdev"      = ""
    "ec2-windev-gui" = ""
    "ec2-datasci"    = ""
  }
}

# =============================================================================
# Template Outputs
# =============================================================================

output "template_ids" {
  description = "Map of template names to their IDs"
  value = var.enable_coderd_provider && var.enable_template_management ? {
    for name, template in coderd_template.templates : name => template.id
  } : {}
}

output "template_versions" {
  description = "Map of template names to their current versions"
  value = var.enable_coderd_provider && var.enable_template_management ? {
    for name, template in coderd_template.templates : name => var.template_version
  } : {}
}
