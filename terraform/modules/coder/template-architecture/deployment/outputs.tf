# Template Deployment Module - Outputs
# Requirements: 16.3, 12b.3

# =============================================================================
# TEMPLATE IDS
# =============================================================================

output "template_ids" {
  description = "Map of template names to their Coder IDs"
  value = merge(
    length(coderd_template.pod_swdev) > 0 ? { "pod-swdev" = coderd_template.pod_swdev[0].id } : {},
    length(coderd_template.ec2_windev_gui) > 0 ? { "ec2-windev-gui" = coderd_template.ec2_windev_gui[0].id } : {},
    length(coderd_template.ec2_datasci) > 0 ? { "ec2-datasci" = coderd_template.ec2_datasci[0].id } : {},
    length(coderd_template.ec2_datasci_gpu) > 0 ? { "ec2-datasci-gpu" = coderd_template.ec2_datasci_gpu[0].id } : {}
  )
}

output "template_versions" {
  description = "Map of template names to their current versions"
  value = merge(
    length(coderd_template.pod_swdev) > 0 ? { "pod-swdev" = var.template_version } : {},
    length(coderd_template.ec2_windev_gui) > 0 ? { "ec2-windev-gui" = var.template_version } : {},
    length(coderd_template.ec2_datasci) > 0 ? { "ec2-datasci" = var.template_version } : {},
    length(coderd_template.ec2_datasci_gpu) > 0 ? { "ec2-datasci-gpu" = var.template_version } : {}
  )
}

# =============================================================================
# DEPLOYMENT SUMMARY
# =============================================================================

output "deployment_summary" {
  description = "Summary of all deployed templates"
  value = merge(
    length(coderd_template.pod_swdev) > 0 ? {
      "pod-swdev" = {
        id           = coderd_template.pod_swdev[0].id
        display_name = coderd_template.pod_swdev[0].display_name
        version      = var.template_version
        toolchain    = "${var.pairing_configs["pod-swdev"].toolchain_name}@${var.pairing_configs["pod-swdev"].toolchain_version}"
        base         = "${var.pairing_configs["pod-swdev"].base_name}@${var.pairing_configs["pod-swdev"].base_version}"
      }
    } : {},
    length(coderd_template.ec2_windev_gui) > 0 ? {
      "ec2-windev-gui" = {
        id           = coderd_template.ec2_windev_gui[0].id
        display_name = coderd_template.ec2_windev_gui[0].display_name
        version      = var.template_version
        toolchain    = "${var.pairing_configs["ec2-windev-gui"].toolchain_name}@${var.pairing_configs["ec2-windev-gui"].toolchain_version}"
        base         = "${var.pairing_configs["ec2-windev-gui"].base_name}@${var.pairing_configs["ec2-windev-gui"].base_version}"
      }
    } : {},
    length(coderd_template.ec2_datasci) > 0 ? {
      "ec2-datasci" = {
        id           = coderd_template.ec2_datasci[0].id
        display_name = coderd_template.ec2_datasci[0].display_name
        version      = var.template_version
        toolchain    = "${var.pairing_configs["ec2-datasci"].toolchain_name}@${var.pairing_configs["ec2-datasci"].toolchain_version}"
        base         = "${var.pairing_configs["ec2-datasci"].base_name}@${var.pairing_configs["ec2-datasci"].base_version}"
      }
    } : {},
    length(coderd_template.ec2_datasci_gpu) > 0 ? {
      "ec2-datasci-gpu" = {
        id           = coderd_template.ec2_datasci_gpu[0].id
        display_name = coderd_template.ec2_datasci_gpu[0].display_name
        version      = var.template_version
        toolchain    = "${var.pairing_configs["ec2-datasci-gpu"].toolchain_name}@${var.pairing_configs["ec2-datasci-gpu"].toolchain_version}"
        base         = "${var.pairing_configs["ec2-datasci-gpu"].base_name}@${var.pairing_configs["ec2-datasci-gpu"].base_version}"
      }
    } : {}
  )
}

# =============================================================================
# PROVENANCE
# =============================================================================

output "deployment_provenance" {
  description = "Provenance records for all deployed templates"
  value       = local.deployment_provenance
}

# =============================================================================
# INDIVIDUAL TEMPLATE OUTPUTS
# =============================================================================

output "pod_swdev_id" {
  description = "ID of the pod-swdev template"
  value       = length(coderd_template.pod_swdev) > 0 ? coderd_template.pod_swdev[0].id : null
}

output "ec2_windev_gui_id" {
  description = "ID of the ec2-windev-gui template"
  value       = length(coderd_template.ec2_windev_gui) > 0 ? coderd_template.ec2_windev_gui[0].id : null
}

output "ec2_datasci_id" {
  description = "ID of the ec2-datasci template"
  value       = length(coderd_template.ec2_datasci) > 0 ? coderd_template.ec2_datasci[0].id : null
}

output "ec2_datasci_gpu_id" {
  description = "ID of the ec2-datasci-gpu template"
  value       = length(coderd_template.ec2_datasci_gpu) > 0 ? coderd_template.ec2_datasci_gpu[0].id : null
}

# =============================================================================
# DEPLOYMENT STATUS
# =============================================================================

output "deployed_templates" {
  description = "List of successfully deployed template names"
  value = compact([
    length(coderd_template.pod_swdev) > 0 ? "pod-swdev" : "",
    length(coderd_template.ec2_windev_gui) > 0 ? "ec2-windev-gui" : "",
    length(coderd_template.ec2_datasci) > 0 ? "ec2-datasci" : "",
    length(coderd_template.ec2_datasci_gpu) > 0 ? "ec2-datasci-gpu" : ""
  ])
}

output "deployment_count" {
  description = "Number of templates deployed"
  value = (
    (length(coderd_template.pod_swdev) > 0 ? 1 : 0) +
    (length(coderd_template.ec2_windev_gui) > 0 ? 1 : 0) +
    (length(coderd_template.ec2_datasci) > 0 ? 1 : 0) +
    (length(coderd_template.ec2_datasci_gpu) > 0 ? 1 : 0)
  )
}
