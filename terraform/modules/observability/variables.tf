# Observability Module Variables
# Configures Fluent Bit, CloudWatch, and monitoring for Coder deployment
#
# Requirements: 3.5, 3.6, 3.7, 3.8, 8.1, 8.1a, 8.1b, 8.1c, 14.13, 14.20

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC provider for IRSA"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

# =============================================================================
# Log Retention Configuration
# =============================================================================

variable "log_retention_days" {
  description = "Number of days to retain logs in CloudWatch (minimum 90 days per Requirements 3.8)"
  type        = number
  default     = 90

  validation {
    condition     = var.log_retention_days >= 90
    error_message = "Log retention must be at least 90 days per compliance requirements."
  }
}

# =============================================================================
# Fluent Bit Configuration
# =============================================================================

variable "fluent_bit_version" {
  description = "Fluent Bit Helm chart version"
  type        = string
  default     = "0.47.10"
}

variable "fluent_bit_image_tag" {
  description = "Fluent Bit container image tag"
  type        = string
  default     = "3.2.2"
}

# =============================================================================
# CloudWatch Configuration
# =============================================================================

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for EKS"
  type        = bool
  default     = true
}

# =============================================================================
# Coder Observability Configuration
# =============================================================================

variable "coder_namespace" {
  description = "Kubernetes namespace where Coder is deployed"
  type        = string
  default     = "coder"
}

variable "enable_prometheus_metrics" {
  description = "Enable Prometheus metrics export from Coder (port 2112)"
  type        = bool
  default     = true
}

variable "enable_amp_integration" {
  description = "Enable Amazon Managed Service for Prometheus (AMP) integration"
  type        = bool
  default     = false
}

variable "amp_workspace_id" {
  description = "Amazon Managed Prometheus workspace ID (required if enable_amp_integration is true)"
  type        = string
  default     = ""
}

# =============================================================================
# CloudTrail Configuration
# =============================================================================

variable "enable_cloudtrail" {
  description = "Enable CloudTrail logging for security monitoring"
  type        = bool
  default     = true
}

variable "cloudtrail_s3_bucket_name" {
  description = "S3 bucket name for CloudTrail logs (will be created if not provided)"
  type        = string
  default     = ""
}

# =============================================================================
# Alerting Configuration
# =============================================================================

variable "alert_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms (optional)"
  type        = string
  default     = ""
}

variable "api_latency_p95_threshold_ms" {
  description = "P95 API latency threshold in milliseconds for alerting"
  type        = number
  default     = 500
}

variable "api_latency_p99_threshold_ms" {
  description = "P99 API latency threshold in milliseconds for alerting"
  type        = number
  default     = 1000
}

variable "scaling_delay_threshold_minutes" {
  description = "Scaling delay threshold in minutes for alerting"
  type        = number
  default     = 5
}

# =============================================================================
# Database Monitoring
# =============================================================================

variable "aurora_cluster_identifier" {
  description = "Aurora cluster identifier for monitoring"
  type        = string
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}


# =============================================================================
# Provisioner Key Monitoring Configuration
# Requirements: 12f.2, 12f.3
# =============================================================================

variable "enable_provisioner_key_monitoring" {
  description = "Enable CloudWatch alarms for provisioner key expiration monitoring"
  type        = bool
  default     = true
}

variable "provisioner_key_name" {
  description = "Name of the provisioner key to monitor"
  type        = string
  default     = "external-provisioner-key"
}

variable "provisioner_key_rotation_days" {
  description = "Number of days between provisioner key rotations (Requirement 12f.2)"
  type        = number
  default     = 90

  validation {
    condition     = var.provisioner_key_rotation_days >= 30 && var.provisioner_key_rotation_days <= 365
    error_message = "Provisioner key rotation must be between 30 and 365 days."
  }
}

variable "provisioner_key_warning_days" {
  description = "Days before expiration to trigger warning alert (Requirement 12f.2)"
  type        = number
  default     = 14

  validation {
    condition     = var.provisioner_key_warning_days >= 7 && var.provisioner_key_warning_days <= 30
    error_message = "Warning threshold must be between 7 and 30 days."
  }
}
