# Default Template Pairings - Outputs
# Requirement 11c.8: Instance administrators select toolchain + base pairings

# =============================================================================
# PAIRING CONFIGURATIONS
# =============================================================================

output "pairing_configs" {
  description = <<-EOT
    Complete configuration for each enabled pairing.
    Includes toolchain, base, versions, capabilities, and infrastructure context.
  EOT
  value       = local.pairing_configs
}

output "enabled_pairings" {
  description = "List of enabled pairing names"
  value       = var.enabled_pairings
}

output "pairing_metadata" {
  description = <<-EOT
    Metadata for each pairing including versions and capabilities.
    Useful for documentation and UI display.
  EOT
  value       = local.pairing_metadata
}

# =============================================================================
# INDIVIDUAL PAIRING OUTPUTS
# =============================================================================

output "pod_swdev" {
  description = "Configuration for pod-swdev pairing (swdev-toolchain + base-k8s)"
  value       = lookup(local.pairing_configs, "pod-swdev", null)
}

output "ec2_windev_gui" {
  description = "Configuration for ec2-windev-gui pairing (windev-toolchain + base-ec2-windows)"
  value       = lookup(local.pairing_configs, "ec2-windev-gui", null)
}

output "ec2_datasci" {
  description = "Configuration for ec2-datasci pairing (datasci-toolchain + base-ec2-linux)"
  value       = lookup(local.pairing_configs, "ec2-datasci", null)
}

output "ec2_datasci_gpu" {
  description = "Configuration for ec2-datasci-gpu pairing (datasci-toolchain + base-ec2-gpu)"
  value       = lookup(local.pairing_configs, "ec2-datasci-gpu", null)
}

# =============================================================================
# SUMMARY OUTPUTS
# =============================================================================

output "pairing_summary" {
  description = "Summary of all enabled pairings"
  value = {
    for name, config in local.pairing_configs :
    name => {
      toolchain = "${config.toolchain_name}@${config.toolchain_version}"
      base      = "${config.base_name}@${config.base_version}"
      platform  = config.platform
    }
  }
}

output "toolchain_versions" {
  description = "Map of toolchain names to versions"
  value       = var.toolchain_versions
}

output "base_versions" {
  description = "Map of base module names to versions"
  value       = var.base_versions
}
