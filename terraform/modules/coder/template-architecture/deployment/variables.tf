# Template Deployment Module - Variables
# Requirements: 16.3, 12b.3

# =============================================================================
# DEPLOYMENT CONTROL
# =============================================================================

variable "enable_deployment" {
  type        = bool
  description = "Enable template deployment via coderd provider"
  default     = false
}

# =============================================================================
# ORGANIZATION CONTEXT
# =============================================================================

variable "organization_id" {
  type        = string
  description = "Coder organization ID"
}

# =============================================================================
# PAIRING CONFIGURATIONS
# =============================================================================

variable "pairing_configs" {
  type = map(object({
    toolchain_name           = string
    toolchain_version        = string
    base_name                = string
    base_version             = string
    display_name             = string
    description              = string
    icon                     = string
    tags                     = list(string)
    platform                 = string
    default_compute_profile  = string
    allowed_compute_profiles = list(string)
    capabilities = object({
      persistent_home   = bool
      network_egress    = string
      identity_mode     = string
      gpu_support       = bool
      artifact_cache    = bool
      secrets_injection = string
      gui_vnc           = bool
      gui_rdp           = bool
    })
    autostop_days_of_week          = list(string)
    namespace                      = string
    storage_class                  = string
    aws_region                     = string
    vpc_id                         = string
    subnet_ids                     = list(string)
    security_group_ids             = list(string)
    default_ttl_ms                 = number
    activity_bump_ms               = number
    failure_ttl_ms                 = number
    time_til_dormant_ms            = number
    time_til_dormant_autodelete_ms = number
    tags                           = map(string)
  }))
  description = "Pairing configurations from the pairings module"
}

# =============================================================================
# GROUP IDS FOR ACL
# =============================================================================

variable "developers_group_id" {
  type        = string
  description = "Developers group ID for ACL configuration"
}

variable "platform_admins_group_id" {
  type        = string
  description = "Platform administrators group ID for ACL configuration"
}

variable "template_owners_group_id" {
  type        = string
  description = "Template owners group ID for ACL configuration"
}

# =============================================================================
# TEMPLATE CONFIGURATION
# =============================================================================

variable "template_directory_base" {
  type        = string
  description = "Base path for template directories"
}

variable "template_version" {
  type        = string
  description = "Version string for all templates"
  default     = "1.0.0"

  validation {
    condition     = can(regex("^v?[0-9]+\\.[0-9]+\\.[0-9]+", var.template_version))
    error_message = "Template version must follow semantic versioning."
  }
}

variable "template_deprecation_messages" {
  type        = map(string)
  description = "Deprecation messages for templates (empty string = not deprecated)"
  default     = {}
}

# =============================================================================
# TERRAFORM VARIABLES FOR TEMPLATES
# =============================================================================

variable "template_tf_vars" {
  type = map(list(object({
    name  = string
    value = string
  })))
  description = "Terraform variables to pass to each template"
  default     = {}
}
