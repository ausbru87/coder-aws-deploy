# Coder Deployment Outputs
# These outputs provide essential information for post-deployment configuration

# =============================================================================
# VPC Outputs
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "control_subnet_ids" {
  description = "IDs of control plane subnets"
  value       = module.vpc.control_subnet_ids
}

output "provisioner_subnet_ids" {
  description = "IDs of provisioner subnets"
  value       = module.vpc.provisioner_subnet_ids
}

output "workspace_subnet_ids" {
  description = "IDs of workspace subnets"
  value       = module.vpc.workspace_subnet_ids
}

output "database_subnet_ids" {
  description = "IDs of database subnets"
  value       = module.vpc.database_subnet_ids
}

# =============================================================================
# EKS Outputs
# =============================================================================

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS cluster API"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster authentication"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  value       = module.eks.cluster_oidc_issuer_url
}

output "node_security_group_id" {
  description = "Security group ID for EKS nodes"
  value       = module.eks.node_security_group_id
}

# =============================================================================
# Aurora Outputs
# =============================================================================

output "aurora_cluster_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = module.aurora.cluster_endpoint
}

output "aurora_cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = module.aurora.cluster_reader_endpoint
}

output "aurora_cluster_port" {
  description = "Aurora cluster port"
  value       = module.aurora.cluster_port
}

output "aurora_database_name" {
  description = "Name of the Coder database"
  value       = module.aurora.database_name
}

output "aurora_master_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = module.aurora.master_secret_arn
  sensitive   = true
}

# =============================================================================
# DNS and Certificate Outputs
# =============================================================================

output "coder_fqdn" {
  description = "Fully qualified domain name for Coder"
  value       = module.dns.coder_fqdn
}

output "coder_wildcard_fqdn" {
  description = "Wildcard FQDN for Coder workspaces"
  value       = module.dns.wildcard_fqdn
}

output "route53_zone_id" {
  description = "Route 53 hosted zone ID used for DNS records"
  value       = module.dns.route53_zone_id
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate for TLS termination"
  value       = module.dns.certificate_arn
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate"
  value       = module.dns.certificate_status
}

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = module.coder.nlb_dns_name
}

output "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  value       = module.coder.nlb_arn
}

output "nlb_ssl_policy" {
  description = "SSL/TLS security policy configured on the NLB (TLS 1.2+ with AES-GCM and ECDHE)"
  value       = module.coder.nlb_ssl_policy
}

output "nlb_cross_zone_enabled" {
  description = "Whether cross-zone load balancing is enabled on the NLB"
  value       = module.coder.nlb_cross_zone_enabled
}

output "nlb_stun_enabled" {
  description = "Whether STUN UDP port (3478) is enabled for NAT traversal"
  value       = module.coder.nlb_stun_enabled
}

output "dns_records_created" {
  description = "Whether DNS records were created"
  value       = module.dns_records.dns_records_created
}

output "access_url_record_fqdn" {
  description = "FQDN of the Route 53 A record for ACCESS_URL"
  value       = module.dns_records.access_url_record_fqdn
}

output "wildcard_record_fqdn" {
  description = "FQDN of the Route 53 A record for WILDCARD_ACCESS_URL"
  value       = module.dns_records.wildcard_record_fqdn
}

# =============================================================================
# Coder Outputs
# =============================================================================

output "coder_access_url" {
  description = "URL to access Coder dashboard"
  value       = module.dns.access_url
}

output "coder_wildcard_url" {
  description = "Wildcard URL for Coder workspaces"
  value       = module.dns.wildcard_access_url
}

output "coder_namespace" {
  description = "Kubernetes namespace for Coder control plane"
  value       = module.coder.coder_namespace
}

output "coder_provisioner_namespace" {
  description = "Kubernetes namespace for Coder provisioners"
  value       = module.coder.provisioner_namespace
}

output "coder_workspace_namespace" {
  description = "Kubernetes namespace for Coder workspaces"
  value       = module.coder.workspace_namespace
}

# =============================================================================
# Connection Information
# =============================================================================

output "kubeconfig_command" {
  description = "Command to update kubeconfig for cluster access"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "coder_login_command" {
  description = "Command to login to Coder CLI"
  value       = "coder login ${module.coder.access_url}"
}


# =============================================================================
# Observability Outputs
# =============================================================================

output "container_logs_group_name" {
  description = "CloudWatch Log Group for container logs"
  value       = module.observability.container_logs_group_name
}

output "coder_audit_logs_group_name" {
  description = "CloudWatch Log Group for Coder audit logs"
  value       = module.observability.coder_audit_logs_group_name
}

output "cloudtrail_name" {
  description = "Name of the CloudTrail trail"
  value       = module.observability.cloudtrail_name
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = module.observability.dashboard_name
}

output "log_retention_days" {
  description = "Configured log retention period in days"
  value       = module.observability.log_retention_days
}

# =============================================================================
# Quota Validation Outputs
# Requirements: 2a.1, 2a.2, 2a.4
# =============================================================================

output "quota_validation_summary" {
  description = "Summary of AWS service quota requirements"
  value       = module.quota_validation.quota_summary
}

output "required_quotas" {
  description = "Map of required AWS service quotas for the deployment"
  value       = module.quota_validation.required_quotas
}

output "calculated_vcpus" {
  description = "Calculated vCPU requirements by node group"
  value       = module.quota_validation.calculated_vcpus
}
