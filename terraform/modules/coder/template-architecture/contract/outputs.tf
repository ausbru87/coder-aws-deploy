# Template Contract - Terraform Output Definitions
# These outputs define the contract outputs that infrastructure base modules MUST provide.
#
# Requirements Covered:
# - 11d.1: Define minimal, stable interface between toolchain and infrastructure layers
# - 11d.3: Specify infrastructure base outputs (agent_endpoint, env_vars, volume_mounts, metadata)
# - 11d.7: Record composition provenance (toolchain version, base version, artifact IDs)

# ============================================================================
# CONTRACT OUTPUTS
# Infrastructure base modules MUST provide these outputs
# ============================================================================

# Note: This file serves as a template/reference for infrastructure base modules.
# Each base module should copy and implement these outputs.

# output "agent_endpoint" {
#   type        = string
#   description = "The endpoint where the Coder agent can be reached"
#   
#   # Example implementations:
#   # - Kubernetes: kubernetes_pod.workspace.status[0].pod_ip
#   # - EC2: aws_instance.workspace.private_ip
# }

# output "runtime_env" {
#   type        = map(string)
#   description = "Environment variables to inject into the workspace runtime"
#   
#   # Example:
#   # value = {
#   #   "CODER_WORKSPACE_NAME" = var.workspace_name
#   #   "CODER_OWNER"          = var.owner
#   #   "AWS_REGION"           = data.aws_region.current.name
#   # }
# }

# output "volume_mounts" {
#   type = list(object({
#     path          = string
#     type          = string
#     size          = string
#     storage_class = optional(string)
#   }))
#   description = "Volume mounts configured for the workspace"
#   
#   # Example:
#   # value = [
#   #   {
#   #     path          = "/home/coder"
#   #     type          = "pvc"
#   #     size          = "100Gi"
#   #     storage_class = "gp3"
#   #   }
#   # ]
# }

# output "metadata" {
#   type = object({
#     platform          = string
#     os                = string
#     arch              = string
#     toolchain_version = string
#     base_version      = string
#     image_digest      = optional(string)
#     ami_id            = optional(string)
#     provisioned_at    = string
#   })
#   description = "Metadata about the provisioned workspace for tracking and auditing"
#   
#   # Example:
#   # value = {
#   #   platform          = "kubernetes"
#   #   os                = "linux"
#   #   arch              = "amd64"
#   #   toolchain_version = var.toolchain_template.version
#   #   base_version      = var.base_module.version
#   #   image_digest      = "sha256:abc123..."
#   #   ami_id            = null
#   #   provisioned_at    = timestamp()
#   # }
# }

# ============================================================================
# OUTPUT TYPE DEFINITIONS (for reference)
# ============================================================================

# These locals define the expected output types for documentation purposes.
# Infrastructure base modules should ensure their outputs match these types.

locals {
  # Output type reference - agent_endpoint
  _agent_endpoint_type = "string"

  # Output type reference - runtime_env
  _runtime_env_type = "map(string)"

  # Output type reference - volume_mounts
  _volume_mounts_type = <<-EOT
    list(object({
      path          = string
      type          = string  # pvc, ebs, efs, local
      size          = string
      storage_class = optional(string)
    }))
  EOT

  # Output type reference - metadata
  _metadata_type = <<-EOT
    object({
      platform          = string  # kubernetes, ec2-linux, ec2-windows, ec2-gpu
      os                = string  # linux, windows
      arch              = string  # amd64, arm64
      toolchain_version = string
      base_version      = string
      image_digest      = optional(string)
      ami_id            = optional(string)
      provisioned_at    = string
    })
  EOT

  # Contract version for compatibility checking
  contract_version = "1.0"
}

