# Example: Coderd Provider Configuration
#
# This example demonstrates how to use the coderd Terraform provider
# for Day 1/2 Coder configuration management.
#
# Requirements Covered: 16.3, 16.4, 16.5
#
# Prerequisites:
# - Coder must be deployed and accessible
# - Admin token with appropriate permissions
# - Set CODER_SESSION_TOKEN environment variable
#
# Usage:
#   export CODER_SESSION_TOKEN="your-admin-token"
#   terraform init
#   terraform plan
#   terraform apply

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    coderd = {
      source  = "coder/coderd"
      version = ">= 0.0.12"
    }
  }
}

# =============================================================================
# Provider Configuration
# =============================================================================

provider "coderd" {
  # URL of your Coder deployment
  url = var.coder_url

  # Authentication via environment variable CODER_SESSION_TOKEN (recommended)
  # Or via token variable (not recommended for production)
  # token = var.coder_admin_token
}

# =============================================================================
# Variables
# =============================================================================

variable "coder_url" {
  description = "URL of the Coder deployment"
  type        = string
  default     = "https://coder.example.com"
}

variable "coder_admin_token" {
  description = "Coder admin token (use CODER_SESSION_TOKEN env var instead)"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# Data Sources
# =============================================================================

# Get the default organization
data "coderd_organization" "default" {
  is_default = true
}

# =============================================================================
# Group Management
# =============================================================================

# Platform Administrators - maps to User Admin role
resource "coderd_group" "platform_admins" {
  organization_id = data.coderd_organization.default.id
  name            = "coder-platform-admins"
  display_name    = "Platform Administrators"
  quota_allowance = 0 # Unlimited
}

# Template Owners - maps to Template Admin role
resource "coderd_group" "template_owners" {
  organization_id = data.coderd_organization.default.id
  name            = "coder-template-owners"
  display_name    = "Template Owners"
  quota_allowance = 0 # Unlimited
}

# Security Auditors - maps to Auditor role
resource "coderd_group" "security_audit" {
  organization_id = data.coderd_organization.default.id
  name            = "coder-security-audit"
  display_name    = "Security Auditors"
  quota_allowance = 0 # Read-only, no quota needed
}

# Developers - maps to Member role
resource "coderd_group" "developers" {
  organization_id = data.coderd_organization.default.id
  name            = "developers"
  display_name    = "Developers"
  quota_allowance = 100 # 100 credits per user
}

# Data Science Team - custom group with higher quota
resource "coderd_group" "data_science" {
  organization_id = data.coderd_organization.default.id
  name            = "data-science"
  display_name    = "Data Science Team"
  quota_allowance = 500 # Higher quota for GPU workspaces
}

# =============================================================================
# Provisioner Key Management
# =============================================================================

# External provisioner key for EKS provisioners
resource "coderd_provisioner_key" "external" {
  organization_id = data.coderd_organization.default.id
  name            = "external-provisioner-key"

  tags = {
    scope       = "organization"
    environment = "production"
  }
}

# =============================================================================
# Template Management
# =============================================================================

# Pod-based software development template
resource "coderd_template" "pod_swdev" {
  organization_id = data.coderd_organization.default.id
  name            = "pod-swdev"
  display_name    = "Pod Software Development"
  description     = "Kubernetes pod-based workspace for software development"
  icon            = "/emojis/1f4bb.png"

  versions = [{
    directory = "${path.module}/templates/pod-swdev"
    active    = true
    name      = "v1.0.0"
    message   = "Initial release with Go, Node.js, Python"
  }]

  # Access control
  acl = {
    groups = [
      {
        id   = coderd_group.developers.id
        role = "use"
      },
      {
        id   = coderd_group.template_owners.id
        role = "admin"
      }
    ]
  }

  # Workspace lifecycle settings
  default_ttl_ms            = 28800000 # 8 hours
  activity_bump_ms          = 3600000  # 1 hour
  autostop_requirement_days = 1
  allow_user_autostart      = true
  allow_user_autostop       = true
}

# Windows development template with GUI
resource "coderd_template" "ec2_windev_gui" {
  organization_id = data.coderd_organization.default.id
  name            = "ec2-windev-gui"
  display_name    = "Windows Development (GUI)"
  description     = "EC2-based Windows workspace with Visual Studio and RDP"
  icon            = "/emojis/1f5a5.png"

  versions = [{
    directory = "${path.module}/templates/ec2-windev-gui"
    active    = true
    name      = "v1.0.0"
    message   = "Initial release with Visual Studio 2022"
  }]

  acl = {
    groups = [
      {
        id   = coderd_group.developers.id
        role = "use"
      },
      {
        id   = coderd_group.template_owners.id
        role = "admin"
      }
    ]
  }

  default_ttl_ms            = 28800000
  activity_bump_ms          = 3600000
  autostop_requirement_days = 1
  allow_user_autostart      = true
  allow_user_autostop       = true
}

# Data science template with GPU support
resource "coderd_template" "ec2_datasci_gpu" {
  organization_id = data.coderd_organization.default.id
  name            = "ec2-datasci-gpu"
  display_name    = "Data Science (GPU)"
  description     = "EC2-based workspace with GPU for ML training"
  icon            = "/emojis/1f9e0.png"

  versions = [{
    directory = "${path.module}/templates/ec2-datasci-gpu"
    active    = true
    name      = "v1.0.0"
    message   = "Initial release with PyTorch, TensorFlow, CUDA"
  }]

  acl = {
    groups = [
      {
        id   = coderd_group.data_science.id
        role = "use"
      },
      {
        id   = coderd_group.template_owners.id
        role = "admin"
      }
    ]
  }

  # Longer TTL for ML training jobs
  default_ttl_ms            = 86400000 # 24 hours
  activity_bump_ms          = 7200000  # 2 hours
  autostop_requirement_days = 1
  allow_user_autostart      = true
  allow_user_autostop       = true
}

# =============================================================================
# Outputs
# =============================================================================

output "organization_id" {
  description = "Default organization ID"
  value       = data.coderd_organization.default.id
}

output "group_ids" {
  description = "Created group IDs"
  value = {
    platform_admins = coderd_group.platform_admins.id
    template_owners = coderd_group.template_owners.id
    security_audit  = coderd_group.security_audit.id
    developers      = coderd_group.developers.id
    data_science    = coderd_group.data_science.id
  }
}

output "provisioner_key_id" {
  description = "External provisioner key ID"
  value       = coderd_provisioner_key.external.id
}

output "template_ids" {
  description = "Created template IDs"
  value = {
    pod_swdev       = coderd_template.pod_swdev.id
    ec2_windev_gui  = coderd_template.ec2_windev_gui.id
    ec2_datasci_gpu = coderd_template.ec2_datasci_gpu.id
  }
}
