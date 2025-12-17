# Template Composition Module - Outputs
# Requirements: 11c.7, 11d.7
#
# These outputs provide the composed template configuration and provenance record.

# =============================================================================
# PROVENANCE RECORD (Requirement 11d.7)
# Records toolchain version, base version, and resolved artifact IDs
# =============================================================================

output "provenance" {
  description = <<-EOT
    Complete provenance record for the composed template.
    Includes toolchain version, infrastructure base version, and resolved artifact identifiers.
    Per Requirement 11d.7: Record composition provenance.
  EOT
  value       = local.provenance
}

output "toolchain_info" {
  description = "Information about the toolchain template used in composition"
  value       = local.provenance.toolchain
}

output "base_info" {
  description = "Information about the infrastructure base module used in composition"
  value       = local.provenance.base
}

output "artifact_info" {
  description = "Resolved artifact identifiers (image digests, AMI IDs)"
  value       = local.provenance.artifacts
}

# =============================================================================
# COMPOSED CONFIGURATION
# =============================================================================

output "composed_config" {
  description = <<-EOT
    Complete composed configuration ready for infrastructure base module.
    Includes all contract inputs, capabilities, and overrides.
  EOT
  value       = local.composed_config
}

output "template_name" {
  description = "Name of the composed template"
  value       = local.template_name
}

output "template_description" {
  description = "Description of the composed template"
  value       = local.template_description
}

# =============================================================================
# RESOLVED VALUES
# =============================================================================

output "compute_profile" {
  description = "Resolved compute profile with any overrides applied"
  value       = local.resolved_compute_profile
}

output "capabilities" {
  description = "Resolved capabilities with any overrides applied"
  value       = local.resolved_capabilities
}

output "image_id" {
  description = "Resolved image ID for the toolchain"
  value       = local.resolved_image_id
}

output "platform" {
  description = "Infrastructure platform type (kubernetes, ec2-linux, ec2-windows, ec2-gpu)"
  value       = local.platform
}

# =============================================================================
# VALIDATION RESULTS
# =============================================================================

output "validation_result" {
  description = "Validation status and details from the validation module"
  value = {
    passed                 = module.validation.validation_passed
    missing_capabilities   = module.validation.missing_capabilities
    override_violations    = module.validation.override_violations
    effective_capabilities = module.validation.effective_capabilities
  }
}

output "validation_passed" {
  description = "Whether all contract validations passed"
  value       = module.validation.validation_passed
}

# =============================================================================
# AGENT CONFIGURATION
# =============================================================================

output "agent_config" {
  description = <<-EOT
    Coder agent configuration for the composed template.
    Includes OS, architecture, and environment variables.
  EOT
  value       = local.agent_config
}

output "agent_os" {
  description = "Operating system for the Coder agent"
  value       = local.agent_config.os
}

output "agent_arch" {
  description = "CPU architecture for the Coder agent"
  value       = local.agent_config.arch
}

output "agent_env" {
  description = "Environment variables for the Coder agent"
  value       = local.agent_config.env
}

# =============================================================================
# INFRASTRUCTURE CONTEXT
# =============================================================================

output "infrastructure_context" {
  description = "Infrastructure context for the composed template"
  value = {
    namespace          = var.namespace
    storage_class      = var.storage_class
    aws_region         = var.aws_region
    vpc_id             = var.vpc_id
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }
}

# =============================================================================
# TAGS
# =============================================================================

output "tags" {
  description = "Tags to apply to composed resources including provenance metadata"
  value       = local.composed_config.tags
}
