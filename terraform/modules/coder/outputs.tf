# Coder Module Outputs

output "access_url" {
  description = "Coder access URL"
  value       = local.access_url
}

output "wildcard_access_url" {
  description = "Coder wildcard access URL"
  value       = local.wildcard_access_url
}

output "coder_namespace" {
  description = "Kubernetes namespace for Coder control plane"
  value       = kubernetes_namespace_v1.coder.metadata[0].name
}

output "provisioner_namespace" {
  description = "Kubernetes namespace for Coder provisioners"
  value       = kubernetes_namespace_v1.coder_prov.metadata[0].name
}

output "workspace_namespace" {
  description = "Kubernetes namespace for Coder workspaces"
  value       = kubernetes_namespace_v1.coder_ws.metadata[0].name
}

output "nlb_hostname" {
  description = "NLB hostname for DNS configuration"
  value       = kubernetes_service_v1.coder_nlb.status[0].load_balancer[0].ingress[0].hostname
}

output "nlb_dns_name" {
  description = "NLB DNS name for Route 53 ALIAS records"
  value       = data.aws_lb.coder_nlb.dns_name
}

output "nlb_zone_id" {
  description = "NLB Route 53 zone ID for ALIAS records"
  value       = data.aws_lb.coder_nlb.zone_id
}

output "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  value       = data.aws_lb.coder_nlb.arn
}

output "nlb_ssl_policy" {
  description = "SSL/TLS security policy configured on the NLB"
  value       = var.nlb_ssl_policy
}

output "nlb_cross_zone_enabled" {
  description = "Whether cross-zone load balancing is enabled"
  value       = var.nlb_cross_zone_enabled
}

output "nlb_stun_enabled" {
  description = "Whether STUN UDP port is enabled for NAT traversal"
  value       = var.enable_stun
}

# =============================================================================
# Service Account Token Outputs
# Requirements: 12d.3, 12d.8
# =============================================================================

output "cicd_token_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the CI/CD service account token"
  value       = var.enable_cicd_service_account ? aws_secretsmanager_secret.cicd_token[0].arn : null
}

output "cicd_token_secret_name" {
  description = "Name of the Secrets Manager secret containing the CI/CD service account token"
  value       = var.enable_cicd_service_account ? aws_secretsmanager_secret.cicd_token[0].name : null
}

output "cicd_token_access_policy_arn" {
  description = "ARN of the IAM policy for CI/CD token access"
  value       = var.enable_cicd_service_account ? aws_iam_policy.cicd_token_access[0].arn : null
}

output "cicd_service_account_name" {
  description = "Name of the CI/CD service account user in Coder"
  value       = var.cicd_service_account_name
}

output "cicd_token_expiration_days" {
  description = "Token expiration period in days"
  value       = var.cicd_token_expiration_days
}
