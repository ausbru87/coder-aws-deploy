# DNS Module Outputs

# =============================================================================
# Domain Outputs
# =============================================================================

output "coder_fqdn" {
  description = "Fully qualified domain name for Coder ACCESS_URL"
  value       = local.coder_fqdn
}

output "wildcard_fqdn" {
  description = "Fully qualified domain name for Coder WILDCARD_ACCESS_URL"
  value       = local.wildcard_fqdn
}

output "access_url" {
  description = "HTTPS URL for Coder dashboard access"
  value       = "https://${local.coder_fqdn}"
}

output "wildcard_access_url" {
  description = "HTTPS wildcard URL for Coder workspaces"
  value       = "https://${local.wildcard_fqdn}"
}

# =============================================================================
# Route 53 Outputs
# =============================================================================

output "route53_zone_id" {
  description = "Route 53 hosted zone ID used for DNS records"
  value       = local.zone_id
}

output "access_url_record_name" {
  description = "Name of the Route 53 A record for ACCESS_URL"
  value       = local.create_dns_records ? aws_route53_record.coder_access_url[0].name : null
}

output "access_url_record_fqdn" {
  description = "FQDN of the Route 53 A record for ACCESS_URL"
  value       = local.create_dns_records ? aws_route53_record.coder_access_url[0].fqdn : null
}

output "wildcard_record_name" {
  description = "Name of the Route 53 A record for WILDCARD_ACCESS_URL"
  value       = local.create_dns_records ? aws_route53_record.coder_wildcard_url[0].name : null
}

output "wildcard_record_fqdn" {
  description = "FQDN of the Route 53 A record for WILDCARD_ACCESS_URL"
  value       = local.create_dns_records ? aws_route53_record.coder_wildcard_url[0].fqdn : null
}

output "dns_records_created" {
  description = "Whether DNS records were created (requires NLB to be available)"
  value       = local.create_dns_records
}

# =============================================================================
# Certificate Outputs
# =============================================================================

output "certificate_arn" {
  description = "ARN of the ACM certificate for TLS termination"
  value       = var.create_certificate ? aws_acm_certificate.coder[0].arn : var.existing_certificate_arn
}

output "certificate_domain_name" {
  description = "Primary domain name of the ACM certificate"
  value       = var.create_certificate ? aws_acm_certificate.coder[0].domain_name : null
}

output "certificate_status" {
  description = "Status of the ACM certificate"
  value       = var.create_certificate ? aws_acm_certificate.coder[0].status : null
}

output "certificate_validation_status" {
  description = "Whether the certificate has been validated"
  value       = var.create_certificate ? (length(aws_acm_certificate_validation.coder) > 0 ? "VALIDATED" : "PENDING") : "EXTERNAL"
}

output "certificate_not_after" {
  description = "Expiration date of the ACM certificate (auto-renewed by ACM)"
  value       = var.create_certificate ? aws_acm_certificate.coder[0].not_after : null
}
