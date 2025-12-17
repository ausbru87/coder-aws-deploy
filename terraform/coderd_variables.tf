# Coderd Provider Variables
# Variables for Day 1/2 Coder configuration management

variable "enable_coderd_provider" {
  description = "Enable coderd provider resources (set to true after initial Coder deployment)"
  type        = bool
  default     = false
}

variable "coder_admin_token" {
  description = "Coder admin token for coderd provider authentication (use CODER_SESSION_TOKEN env var instead)"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# Group Configuration
# =============================================================================

variable "idp_group_mappings" {
  description = "Mapping of IDP groups to Coder roles"
  type = map(object({
    display_name    = string
    quota_allowance = number
  }))
  default = {
    "coder-platform-admins" = {
      display_name    = "Platform Administrators"
      quota_allowance = 0
    }
    "coder-template-owners" = {
      display_name    = "Template Owners"
      quota_allowance = 0
    }
    "coder-security-audit" = {
      display_name    = "Security Auditors"
      quota_allowance = 0
    }
    "developers" = {
      display_name    = "Developers"
      quota_allowance = 100
    }
  }
}

# =============================================================================
# Provisioner Key Configuration
# =============================================================================

variable "provisioner_key_tags" {
  description = "Tags for provisioner key scoping"
  type        = map(string)
  default = {
    scope = "organization"
  }
}
