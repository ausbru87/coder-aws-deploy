# Base-K8s Infrastructure Module - Outputs
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
  value       = "${kubernetes_deployment_v1.workspace.metadata[0].name}.${var.namespace}.svc.cluster.local"
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
      type          = "pvc"
      size          = var.compute_profile.storage
      storage_class = var.storage_class
    }
  ] : []
}

output "metadata" {
  description = "Metadata about the provisioned workspace for tracking and auditing"
  value = {
    platform          = "kubernetes"
    os                = "linux"
    arch              = "amd64"
    toolchain_version = var.toolchain_template.version
    base_version      = var.base_module.version
    image_digest      = local.final_image
    ami_id            = null
    provisioned_at    = timestamp()
  }
}

# ============================================================================
# ADDITIONAL OUTPUTS (Kubernetes-specific)
# ============================================================================

output "deployment_name" {
  description = "Name of the Kubernetes deployment"
  value       = kubernetes_deployment_v1.workspace.metadata[0].name
}

output "namespace" {
  description = "Kubernetes namespace where the workspace is deployed"
  value       = var.namespace
}

output "service_account_name" {
  description = "Name of the service account used by the workspace"
  value       = kubernetes_service_account_v1.workspace.metadata[0].name
}

output "pvc_name" {
  description = "Name of the PVC for home directory (if persistent_home enabled)"
  value       = var.capabilities.persistent_home ? kubernetes_persistent_volume_claim_v1.home[0].metadata[0].name : null
}

output "vnc_service_name" {
  description = "Name of the VNC service (if gui_vnc enabled)"
  value       = var.capabilities.gui_vnc ? kubernetes_service_v1.vnc[0].metadata[0].name : null
}

output "labels" {
  description = "Labels applied to all resources"
  value       = local.common_labels
}
