# Template Contract Validation Module
# This module validates that toolchain template capability requirements
# are satisfied by the selected infrastructure base module.
#
# Requirements Covered:
# - 11c.10: Validate toolchain template capability requirements are satisfied by infrastructure base
# - 11g.3: Policy-validate overrides to prevent arbitrary passthrough

terraform {
  required_version = ">= 1.0"
}

# ============================================================================
# INPUT VARIABLES
# ============================================================================

variable "toolchain_capabilities" {
  type = object({
    required = list(string)
    optional = optional(list(string), [])
  })
  description = "Capabilities declared by the toolchain template"

  validation {
    condition = alltrue([
      for cap in var.toolchain_capabilities.required : contains(
        ["persistent-home", "network-egress", "identity-mode", "gpu-support",
        "artifact-cache", "secrets-injection", "gui-vnc", "gui-rdp"],
        cap
      )
    ])
    error_message = "Invalid capability in required list. Valid capabilities: persistent-home, network-egress, identity-mode, gpu-support, artifact-cache, secrets-injection, gui-vnc, gui-rdp."
  }
}

variable "base_platform" {
  type        = string
  description = "The infrastructure base platform type"

  validation {
    condition     = contains(["kubernetes", "ec2-linux", "ec2-windows", "ec2-gpu"], var.base_platform)
    error_message = "Base platform must be one of: kubernetes, ec2-linux, ec2-windows, ec2-gpu."
  }
}

variable "base_supported_capabilities" {
  type        = list(string)
  description = "Capabilities supported by the infrastructure base module"
  default     = []
}

variable "requested_overrides" {
  type = object({
    compute_profile       = optional(map(any), {})
    environment_variables = optional(map(string), {})
    labels                = optional(map(string), {})
    annotations           = optional(map(string), {})
    network_policy        = optional(string, null)
    identity_binding      = optional(string, null)
    privileged            = optional(bool, null)
    mount_permissions     = optional(list(string), null)
  })
  description = "Overrides requested during template composition"
  default     = {}
}

variable "override_policy" {
  type = object({
    allow_compute_override    = optional(bool, true)
    allow_env_override        = optional(bool, true)
    allow_label_override      = optional(bool, true)
    allow_annotation_override = optional(bool, true)
    allow_network_override    = optional(bool, false)
    allow_identity_override   = optional(bool, false)
    allow_privileged          = optional(bool, false)
    allow_mount_override      = optional(bool, false)
    blocked_env_prefixes      = optional(list(string), ["AWS_", "CODER_AGENT_"])
    blocked_labels            = optional(list(string), ["kubernetes.io/", "eks.amazonaws.com/"])
  })
  description = "Policy controlling which overrides are permitted"
  default     = {}
}

# ============================================================================
# PLATFORM CAPABILITY DEFINITIONS
# ============================================================================

locals {
  # Define which capabilities each platform supports
  platform_capabilities = {
    kubernetes = [
      "persistent-home",
      "network-egress",
      "identity-mode",
      "artifact-cache",
      "secrets-injection",
      "gui-vnc"
    ]
    ec2-linux = [
      "persistent-home",
      "network-egress",
      "identity-mode",
      "artifact-cache",
      "secrets-injection",
      "gui-vnc"
    ]
    ec2-windows = [
      "persistent-home",
      "network-egress",
      "identity-mode",
      "secrets-injection",
      "gui-rdp"
    ]
    ec2-gpu = [
      "persistent-home",
      "network-egress",
      "identity-mode",
      "artifact-cache",
      "secrets-injection",
      "gui-vnc",
      "gpu-support"
    ]
  }

  # Use provided capabilities or fall back to platform defaults
  effective_base_capabilities = length(var.base_supported_capabilities) > 0 ? var.base_supported_capabilities : local.platform_capabilities[var.base_platform]

  # Check which required capabilities are missing
  missing_capabilities = [
    for cap in var.toolchain_capabilities.required :
    cap if !contains(local.effective_base_capabilities, cap)
  ]

  # Check which optional capabilities are available
  available_optional = [
    for cap in var.toolchain_capabilities.optional :
    cap if contains(local.effective_base_capabilities, cap)
  ]

  # Validation results
  all_required_satisfied = length(local.missing_capabilities) == 0
}

# ============================================================================
# OVERRIDE POLICY VALIDATION
# ============================================================================

locals {
  # Validate compute profile overrides
  compute_override_valid = var.override_policy.allow_compute_override || length(var.requested_overrides.compute_profile) == 0

  # Validate environment variable overrides
  env_override_violations = var.override_policy.allow_env_override ? [
    for key, value in var.requested_overrides.environment_variables :
    key if anytrue([
      for prefix in var.override_policy.blocked_env_prefixes :
      startswith(key, prefix)
    ])
  ] : keys(var.requested_overrides.environment_variables)

  env_override_valid = length(local.env_override_violations) == 0

  # Validate label overrides
  label_override_violations = var.override_policy.allow_label_override ? [
    for key, value in var.requested_overrides.labels :
    key if anytrue([
      for prefix in var.override_policy.blocked_labels :
      startswith(key, prefix)
    ])
  ] : keys(var.requested_overrides.labels)

  label_override_valid = length(local.label_override_violations) == 0

  # Validate annotation overrides
  annotation_override_valid = var.override_policy.allow_annotation_override || length(var.requested_overrides.annotations) == 0

  # Validate network policy override
  network_override_valid = var.override_policy.allow_network_override || var.requested_overrides.network_policy == null

  # Validate identity binding override
  identity_override_valid = var.override_policy.allow_identity_override || var.requested_overrides.identity_binding == null

  # Validate privileged override
  privileged_override_valid = var.override_policy.allow_privileged || var.requested_overrides.privileged != true

  # Validate mount permissions override
  mount_override_valid = var.override_policy.allow_mount_override || var.requested_overrides.mount_permissions == null

  # Aggregate all override validations
  all_overrides_valid = alltrue([
    local.compute_override_valid,
    local.env_override_valid,
    local.label_override_valid,
    local.annotation_override_valid,
    local.network_override_valid,
    local.identity_override_valid,
    local.privileged_override_valid,
    local.mount_override_valid
  ])

  # Collect all override violations
  override_violations = concat(
    local.compute_override_valid ? [] : ["Compute profile override not permitted"],
    [for v in local.env_override_violations : "Environment variable '${v}' override blocked by policy"],
    [for v in local.label_override_violations : "Label '${v}' override blocked by policy"],
    local.annotation_override_valid ? [] : ["Annotation override not permitted"],
    local.network_override_valid ? [] : ["Network policy override not permitted - security control"],
    local.identity_override_valid ? [] : ["Identity binding override not permitted - security control"],
    local.privileged_override_valid ? [] : ["Privileged execution not permitted - security control"],
    local.mount_override_valid ? [] : ["Mount permissions override not permitted - security control"]
  )
}

# ============================================================================
# VALIDATION CHECKS (using preconditions)
# ============================================================================

# This null_resource serves as a validation checkpoint
resource "null_resource" "contract_validation" {
  # Trigger re-validation when inputs change
  triggers = {
    toolchain_required = join(",", var.toolchain_capabilities.required)
    base_platform      = var.base_platform
    validation_hash    = sha256(jsonencode(var.requested_overrides))
  }

  lifecycle {
    precondition {
      condition     = local.all_required_satisfied
      error_message = "Contract validation failed: Infrastructure base '${var.base_platform}' does not support required capabilities: ${join(", ", local.missing_capabilities)}"
    }

    precondition {
      condition     = local.all_overrides_valid
      error_message = "Override policy validation failed: ${join("; ", local.override_violations)}"
    }
  }
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "validation_passed" {
  description = "Whether all contract validations passed"
  value       = local.all_required_satisfied && local.all_overrides_valid
}

output "missing_capabilities" {
  description = "List of required capabilities not supported by the infrastructure base"
  value       = local.missing_capabilities
}

output "available_optional_capabilities" {
  description = "List of optional capabilities that are available"
  value       = local.available_optional
}

output "override_violations" {
  description = "List of override policy violations"
  value       = local.override_violations
}

output "effective_capabilities" {
  description = "The effective capabilities after validation"
  value = {
    required  = var.toolchain_capabilities.required
    optional  = local.available_optional
    platform  = var.base_platform
    supported = local.effective_base_capabilities
  }
}

output "validation_summary" {
  description = "Summary of validation results"
  value = {
    contract_satisfied   = local.all_required_satisfied
    overrides_valid      = local.all_overrides_valid
    missing_capabilities = local.missing_capabilities
    override_violations  = local.override_violations
    platform             = var.base_platform
  }
}

