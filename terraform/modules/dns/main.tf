# DNS Module for Coder Deployment
# Configures Route 53 records and ACM certificates for TLS termination
#
# This module creates:
# - ACM certificate with automatic DNS validation and renewal
# - A/ALIAS record for ACCESS_URL (coder.example.com) pointing to NLB
# - Wildcard A/ALIAS record for WILDCARD_ACCESS_URL (*.coder.example.com)
#
# Requirements: 3.3, 6.4, 6.5
#
# Note: The certificate is created and validated first, then DNS records
# are created once the NLB is available. This avoids circular dependencies.

locals {
  # Construct full domain names
  coder_fqdn    = "${var.coder_subdomain}.${var.base_domain}"
  wildcard_fqdn = "*.${var.coder_subdomain}.${var.base_domain}"

  # Certificate domains (primary + wildcard)
  certificate_domains = [local.coder_fqdn, local.wildcard_fqdn]

  # Determine if we should create DNS records (NLB must be available)
  create_dns_records = var.nlb_dns_name != "" && var.nlb_zone_id != ""
}

# =============================================================================
# Route 53 Hosted Zone Data Source
# =============================================================================

# Look up the hosted zone if not provided
data "aws_route53_zone" "main" {
  name         = var.base_domain
  private_zone = false
}

locals {
  zone_id = var.route53_zone_id != "" ? var.route53_zone_id : data.aws_route53_zone.main.zone_id
}

# =============================================================================
# ACM Certificate
# =============================================================================

# Create ACM certificate for domain and wildcard
# ACM certificates automatically renew when using DNS validation
# Certificate is created first and can be used by NLB before DNS records exist
resource "aws_acm_certificate" "coder" {
  count = var.create_certificate ? 1 : 0

  domain_name               = local.coder_fqdn
  subject_alternative_names = [local.wildcard_fqdn]
  validation_method         = "DNS"

  options {
    certificate_transparency_logging_preference = var.certificate_transparency_logging ? "ENABLED" : "DISABLED"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-coder-cert"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# DNS Validation Records for ACM Certificate
# =============================================================================

# Create DNS validation records for the ACM certificate
resource "aws_route53_record" "cert_validation" {
  for_each = var.create_certificate ? {
    for dvo in aws_acm_certificate.coder[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.zone_id
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "coder" {
  count = var.create_certificate ? 1 : 0

  certificate_arn         = aws_acm_certificate.coder[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# =============================================================================
# Route 53 A/ALIAS Records for Coder
# =============================================================================

# A/ALIAS record for ACCESS_URL (coder.example.com)
# Points to the Network Load Balancer
resource "aws_route53_record" "coder_access_url" {
  count = local.create_dns_records ? 1 : 0

  zone_id = local.zone_id
  name    = local.coder_fqdn
  type    = "A"

  alias {
    name                   = var.nlb_dns_name
    zone_id                = var.nlb_zone_id
    evaluate_target_health = true
  }
}

# Wildcard A/ALIAS record for WILDCARD_ACCESS_URL (*.coder.example.com)
# Points to the Network Load Balancer for workspace subdomains
resource "aws_route53_record" "coder_wildcard_url" {
  count = local.create_dns_records ? 1 : 0

  zone_id = local.zone_id
  name    = local.wildcard_fqdn
  type    = "A"

  alias {
    name                   = var.nlb_dns_name
    zone_id                = var.nlb_zone_id
    evaluate_target_health = true
  }
}
