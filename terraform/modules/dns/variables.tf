# DNS Module Variables
# Configuration for Route 53 records and ACM certificates

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name for resource naming"
  type        = string
}

# =============================================================================
# Domain Configuration
# =============================================================================

variable "base_domain" {
  description = "Base domain owned by Route 53 (e.g., example.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*\\.[a-z]{2,}$", var.base_domain))
    error_message = "Base domain must be a valid domain name (e.g., example.com)."
  }
}

variable "coder_subdomain" {
  description = "Subdomain for Coder (e.g., 'coder' for coder.example.com)"
  type        = string
  default     = "coder"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.coder_subdomain))
    error_message = "Subdomain must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID for the base domain. If not provided, will be looked up by domain name."
  type        = string
  default     = ""
}

# =============================================================================
# Load Balancer Configuration
# =============================================================================

variable "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer. Required for creating DNS records."
  type        = string
  default     = ""
}

variable "nlb_zone_id" {
  description = "Route 53 zone ID of the Network Load Balancer. Required for creating DNS records."
  type        = string
  default     = ""
}

# =============================================================================
# Certificate Configuration
# =============================================================================

variable "create_certificate" {
  description = "Whether to create a new ACM certificate or use an existing one"
  type        = bool
  default     = true
}

variable "existing_certificate_arn" {
  description = "ARN of existing ACM certificate (if create_certificate is false)"
  type        = string
  default     = ""
}

variable "certificate_transparency_logging" {
  description = "Enable Certificate Transparency logging for the ACM certificate"
  type        = bool
  default     = true
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
