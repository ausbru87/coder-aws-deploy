# Complete Template Architecture Example
# This example demonstrates how to use all template architecture modules together.
#
# Requirements Covered:
# - 11c.7: Compose templates as Toolchain + Base + Overrides
# - 11c.8: Instance administrators select toolchain + base pairings
# - 11d.7: Record composition provenance
# - 12b.3: Configure template access permissions
# - 16.3: Use coderd_template for declarative template management

terraform {
  required_version = ">= 1.0"

  required_providers {
    coderd = {
      source  = "coder/coderd"
      version = ">= 0.0.12"
    }
  }
}

# =============================================================================
# VARIABLES
# =============================================================================

variable "enable_deployment" {
  type        = bool
  description = "Enable template deployment to Coder"
  default     = true
}

variable "coder_url" {
  type        = string
  description = "Coder deployment URL"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for pod workspaces"
  default     = "coder-ws"
}

variable "storage_class" {
  type        = string
  description = "Storage class for persistent volumes"
  default     = "gp3-encrypted"
}

variable "aws_region" {
  type        = string
  description = "AWS region for EC2 workspaces"
  default     = "us-east-1"
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "coderd_organization" "default" {
  is_default = true
}

# =============================================================================
# GROUPS (for ACL configuration)
# =============================================================================

resource "coderd_group" "developers" {
  organization_id = data.coderd_organization.default.id
  name            = "developers"
  display_name    = "Developers"
  quota_allowance = 300
}

resource "coderd_group" "platform_admins" {
  organization_id = data.coderd_organization.default.id
  name            = "coder-platform-admins"
  display_name    = "Platform Administrators"
  quota_allowance = 500
}

resource "coderd_group" "template_owners" {
  organization_id = data.coderd_organization.default.id
  name            = "coder-template-owners"
  display_name    = "Template Owners"
  quota_allowance = 500
}

# =============================================================================
# STEP 1: Configure Default Pairings
# =============================================================================

module "pairings" {
  source = "../../pairings"

  # Enable specific pairings
  enabled_pairings = ["pod-swdev", "ec2-windev-gui", "ec2-datasci", "ec2-datasci-gpu"]

  # Version configuration
  toolchain_versions = {
    "swdev-toolchain"   = "1.0.0"
    "windev-toolchain"  = "1.0.0"
    "datasci-toolchain" = "1.0.0"
  }

  base_versions = {
    "base-k8s"         = "1.0.0"
    "base-ec2-linux"   = "1.0.0"
    "base-ec2-windows" = "1.0.0"
    "base-ec2-gpu"     = "1.0.0"
  }

  # Infrastructure context
  namespace     = var.namespace
  storage_class = var.storage_class
  aws_region    = var.aws_region
}

# =============================================================================
# STEP 2: Deploy Templates via coderd Provider
# =============================================================================

module "deployment" {
  source = "../../deployment"

  enable_deployment = var.enable_deployment

  # Organization context
  organization_id = data.coderd_organization.default.id

  # Pairing configurations
  pairing_configs = module.pairings.pairing_configs

  # Group IDs for ACL
  developers_group_id      = coderd_group.developers.id
  platform_admins_group_id = coderd_group.platform_admins.id
  template_owners_group_id = coderd_group.template_owners.id

  # Template configuration
  template_directory_base = "${path.module}/../../../templates"
  template_version        = "1.0.0"
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "pairing_summary" {
  description = "Summary of configured pairings"
  value       = module.pairings.pairing_summary
}

output "deployed_templates" {
  description = "List of deployed template names"
  value       = module.deployment.deployed_templates
}

output "template_ids" {
  description = "Map of template names to IDs"
  value       = module.deployment.template_ids
}

output "deployment_provenance" {
  description = "Provenance records for deployed templates"
  value       = module.deployment.deployment_provenance
}
