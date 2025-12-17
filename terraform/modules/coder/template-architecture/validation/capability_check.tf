# Capability Check Functions
# Helper functions for validating individual capabilities
#
# Requirements Covered:
# - 11c.10: Validate toolchain template capability requirements are satisfied by infrastructure base

# ============================================================================
# CAPABILITY COMPATIBILITY CHECKS
# ============================================================================

locals {
  # Mutual exclusion rules - capabilities that cannot be enabled together
  mutual_exclusions = {
    "gui-vnc" = ["gui-rdp"]
    "gui-rdp" = ["gui-vnc"]
  }

  # Implication rules - if capability A is enabled, capability B must have certain values
  capability_implications = {
    "gpu-support" = {
      requires_network = true # GPU workspaces need network for CUDA downloads
    }
  }

  # Check for mutual exclusion violations
  mutual_exclusion_violations = flatten([
    for cap in var.toolchain_capabilities.required : [
      for excluded in lookup(local.mutual_exclusions, cap, []) :
      "Capability '${cap}' is mutually exclusive with '${excluded}'"
      if contains(var.toolchain_capabilities.required, excluded)
    ]
  ])

  # Check capability implications
  implication_violations = flatten([
    for cap, implications in local.capability_implications : [
      for impl_key, impl_value in implications :
      "Capability '${cap}' requires ${impl_key}"
      if contains(var.toolchain_capabilities.required, cap) && impl_key == "requires_network" && impl_value == true
    ]
  ])

  # All capability constraint violations
  capability_constraint_violations = concat(
    local.mutual_exclusion_violations,
    local.implication_violations
  )

  capability_constraints_valid = length(local.capability_constraint_violations) == 0
}

# ============================================================================
# CAPABILITY-SPECIFIC VALIDATION FUNCTIONS
# ============================================================================

locals {
  # Validate persistent-home capability
  persistent_home_valid = !contains(var.toolchain_capabilities.required, "persistent-home") || contains(local.effective_base_capabilities, "persistent-home")

  # Validate network-egress capability
  network_egress_valid = !contains(var.toolchain_capabilities.required, "network-egress") || contains(local.effective_base_capabilities, "network-egress")

  # Validate identity-mode capability
  identity_mode_valid = !contains(var.toolchain_capabilities.required, "identity-mode") || contains(local.effective_base_capabilities, "identity-mode")

  # Validate gpu-support capability
  gpu_support_valid = !contains(var.toolchain_capabilities.required, "gpu-support") || contains(local.effective_base_capabilities, "gpu-support")

  # Validate artifact-cache capability
  artifact_cache_valid = !contains(var.toolchain_capabilities.required, "artifact-cache") || contains(local.effective_base_capabilities, "artifact-cache")

  # Validate secrets-injection capability
  secrets_injection_valid = !contains(var.toolchain_capabilities.required, "secrets-injection") || contains(local.effective_base_capabilities, "secrets-injection")

  # Validate gui-vnc capability
  gui_vnc_valid = !contains(var.toolchain_capabilities.required, "gui-vnc") || contains(local.effective_base_capabilities, "gui-vnc")

  # Validate gui-rdp capability
  gui_rdp_valid = !contains(var.toolchain_capabilities.required, "gui-rdp") || contains(local.effective_base_capabilities, "gui-rdp")

  # Individual capability validation results
  capability_validations = {
    "persistent-home"   = local.persistent_home_valid
    "network-egress"    = local.network_egress_valid
    "identity-mode"     = local.identity_mode_valid
    "gpu-support"       = local.gpu_support_valid
    "artifact-cache"    = local.artifact_cache_valid
    "secrets-injection" = local.secrets_injection_valid
    "gui-vnc"           = local.gui_vnc_valid
    "gui-rdp"           = local.gui_rdp_valid
  }
}

# ============================================================================
# ADDITIONAL OUTPUTS
# ============================================================================

output "capability_validations" {
  description = "Individual capability validation results"
  value       = local.capability_validations
}

output "capability_constraint_violations" {
  description = "Violations of capability constraints (mutual exclusions, implications)"
  value       = local.capability_constraint_violations
}

output "capability_constraints_valid" {
  description = "Whether all capability constraints are satisfied"
  value       = local.capability_constraints_valid
}

