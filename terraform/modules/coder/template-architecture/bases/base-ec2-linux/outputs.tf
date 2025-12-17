# Base-EC2-Linux Infrastructure Module - Outputs
# Contract outputs that this infrastructure base module provides
#
# Requirements Covered:
# - 11d.1: Minimal, stable interface between toolchain and infrastructure layers
# - 11d.3: Infrastructure base outputs (agent_endpoint, env_vars, volume_mounts, metadata)
# - 11d.7: Record composition provenance (toolchain version, base version, artifact IDs)

# ============================================================================
# CONTRACT OUTPUTS (Required by all infrastructure base modules)
# ============================================================================

output "agent_endpoint" {
  description = "The endpoint where the Coder agent can be reached"
  value       = aws_instance.workspace.private_ip
}

output "runtime_env" {
  description = "Environment variables to inject into the workspace runtime"
  value       = local.runtime_env
}

output "volume_mounts" {
  description = "Volume mounts configured for the workspace"
  value = var.capabilities.persistent_home ? [
    {
      path          = "/home/coder"
      type          = "ebs"
      size          = var.compute_profile.storage
      storage_class = "gp3"
    }
  ] : []
}

output "metadata" {
  description = "Metadata about the provisioned workspace for tracking and auditing"
  value = {
    platform          = "ec2-linux"
    os                = "linux"
    arch              = "amd64"
    toolchain_version = var.toolchain_template.version
    base_version      = var.base_module.version
    image_digest      = null
    ami_id            = local.selected_ami
    provisioned_at    = timestamp()
  }
}

# ============================================================================
# ADDITIONAL OUTPUTS (EC2-specific)
# ============================================================================

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.workspace.id
}

output "instance_type" {
  description = "EC2 instance type"
  value       = local.instance_type
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.workspace.private_ip
}

output "public_ip" {
  description = "Public IP address (if Elastic IP assigned)"
  value       = var.assign_elastic_ip ? aws_eip.workspace[0].public_ip : null
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.workspace.id
}

output "ebs_volume_id" {
  description = "EBS volume ID for home directory (if persistent_home enabled)"
  value       = var.capabilities.persistent_home ? aws_ebs_volume.home[0].id : null
}

output "tags" {
  description = "Tags applied to all resources"
  value       = local.common_tags
}
