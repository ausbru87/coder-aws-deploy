# Coder Deployment Variables
# Configure these variables for your environment

# =============================================================================
# Feature Flags
# =============================================================================

variable "deployment_features" {
  description = "Feature flags for deployment patterns (v1.0: SR-HA and SR-Simple)"
  type = object({
    high_availability  = bool # true = SR-HA (3 AZ), false = SR-Simple (1 AZ)
    time_based_scaling = bool # true = time-based auto-scaling, false = static capacity
  })
  default = {
    high_availability  = true # v1.0 default: SR-HA
    time_based_scaling = true # Cost optimization enabled
  }

  validation {
    condition     = var.deployment_features.high_availability || !var.deployment_features.time_based_scaling
    error_message = "time_based_scaling requires high_availability=true (need multiple AZs for meaningful scaling)"
  }
}

# =============================================================================
# General Configuration
# =============================================================================

variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
  default     = "coder"
}

variable "environment" {
  description = "Environment name for resource naming"
  type        = string
  default     = "prod"
}

variable "owner" {
  description = "Owner of the resources for tagging"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

# =============================================================================
# VPC Configuration
# =============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "max_workspaces" {
  description = "Maximum number of concurrent workspaces for CIDR sizing"
  type        = number
  default     = 3000
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for AWS services (S3, ECR, etc.)"
  type        = bool
  default     = true
}

# =============================================================================
# EKS Configuration
# =============================================================================

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

# Control Node Group (coderd)
variable "control_node_instance_type" {
  description = "Instance type for control plane nodes"
  type        = string
  default     = "m5.large"
}

variable "control_node_min_size" {
  description = "Minimum number of control plane nodes"
  type        = number
  default     = 2
}

variable "control_node_max_size" {
  description = "Maximum number of control plane nodes"
  type        = number
  default     = 3
}

# Provisioner Node Group
variable "prov_node_instance_type" {
  description = "Instance type for provisioner nodes"
  type        = string
  default     = "c5.2xlarge"
}

variable "prov_node_min_size" {
  description = "Minimum number of provisioner nodes"
  type        = number
  default     = 0
}

variable "prov_node_max_size" {
  description = "Maximum number of provisioner nodes"
  type        = number
  default     = 20
}

variable "prov_node_desired_peak" {
  description = "Desired number of provisioner nodes during peak hours"
  type        = number
  default     = 5
}

# Workspace Node Group
variable "ws_node_instance_type" {
  description = "Instance type for workspace nodes"
  type        = string
  default     = "m5.2xlarge"
}

variable "ws_node_min_size" {
  description = "Minimum number of workspace nodes"
  type        = number
  default     = 10
}

variable "ws_node_max_size" {
  description = "Maximum number of workspace nodes"
  type        = number
  default     = 200
}

variable "ws_node_desired_peak" {
  description = "Desired number of workspace nodes during peak hours (pre-provisioning for morning usage)"
  type        = number
  default     = 50
}

variable "ws_use_spot_instances" {
  description = "Use spot instances for workspace nodes with on-demand fallback"
  type        = bool
  default     = true
}

# Scaling Schedules
variable "scaling_schedule_start" {
  description = "Cron expression for scaling up (e.g., '45 6 * * MON-FRI')"
  type        = string
  default     = "45 6 * * MON-FRI"
}

variable "scaling_schedule_stop" {
  description = "Cron expression for scaling down (e.g., '15 18 * * MON-FRI')"
  type        = string
  default     = "15 18 * * MON-FRI"
}

variable "scaling_timezone" {
  description = "Timezone for scaling schedules"
  type        = string
  default     = "America/New_York"
}

# =============================================================================
# Aurora PostgreSQL Configuration
# =============================================================================

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "16.4"
}

variable "aurora_min_capacity" {
  description = "Minimum ACU capacity for Aurora Serverless v2"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Maximum ACU capacity for Aurora Serverless v2"
  type        = number
  default     = 16
}

variable "aurora_backup_retention_days" {
  description = "Number of days to retain Aurora backups"
  type        = number
  default     = 90
}

variable "enable_cross_region_backup" {
  description = "Enable cross-region backup replication"
  type        = bool
  default     = true
}

variable "backup_region" {
  description = "Region for cross-region backup replication"
  type        = string
  default     = "us-west-2"
}

# =============================================================================
# DNS and Certificates
# =============================================================================

variable "base_domain" {
  description = "Base domain for Coder (e.g., example.com). Route 53 must own this domain."
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

variable "create_acm_certificate" {
  description = "Whether to create a new ACM certificate or use an existing one"
  type        = bool
  default     = true
}

variable "existing_acm_certificate_arn" {
  description = "ARN of existing ACM certificate (if create_acm_certificate is false)"
  type        = string
  default     = ""
}

variable "certificate_transparency_logging" {
  description = "Enable Certificate Transparency logging for the ACM certificate"
  type        = bool
  default     = true
}

# =============================================================================
# OIDC Authentication
# =============================================================================

variable "oidc_issuer_url" {
  description = "OIDC issuer URL for authentication"
  type        = string
}

variable "oidc_client_id" {
  description = "OIDC client ID"
  type        = string
}

variable "oidc_client_secret_arn" {
  description = "ARN of Secrets Manager secret containing OIDC client secret"
  type        = string
}

# =============================================================================
# External Authentication (Git Provider)
# =============================================================================

variable "external_auth_provider" {
  description = "External auth provider type (github, gitlab, bitbucket)"
  type        = string
  default     = "github"
}

variable "external_auth_client_id" {
  description = "External auth client ID"
  type        = string
  default     = ""
}

variable "external_auth_client_secret_arn" {
  description = "ARN of Secrets Manager secret containing external auth client secret"
  type        = string
  default     = ""
}

# =============================================================================
# Coder Configuration
# =============================================================================

variable "coder_version" {
  description = "Coder Helm chart version"
  type        = string
  default     = "2.18.0"
}

variable "coderd_replicas" {
  description = "Number of coderd replicas (static, no autoscaling)"
  type        = number
  default     = 2
}

variable "max_workspaces_per_user" {
  description = "Maximum workspaces per user (Coder internal quota)"
  type        = number
  default     = 3
}

# =============================================================================
# Network Load Balancer Configuration
# =============================================================================

variable "nlb_ssl_policy" {
  description = <<-EOT
    SSL/TLS security policy for the NLB. Must enforce TLS 1.2+ with approved cipher suites.
    Default: ELBSecurityPolicy-TLS13-1-2-2021-06 (TLS 1.2/1.3 with AES-GCM and ECDHE)
    
    Requirements: 12.7, 12.8, 12.8a
    - TLS 1.2 minimum, TLS 1.3 preferred
    - AES-128-GCM and AES-256-GCM cipher suites
    - ECDHE key exchange for forward secrecy (Fortune 2000 standards)
  EOT
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "nlb_cross_zone_enabled" {
  description = "Enable cross-zone load balancing for the NLB (recommended for HA)"
  type        = bool
  default     = true
}

variable "enable_stun" {
  description = "Enable STUN UDP port (3478) for NAT traversal and direct P2P connections"
  type        = bool
  default     = true
}


# =============================================================================
# Observability Configuration
# Requirements: 3.5, 3.6, 3.7, 3.8, 8.1, 8.1a, 8.1b, 8.1c, 14.13, 14.20
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

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for EKS"
  type        = bool
  default     = true
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
# Quota Validation Configuration
# Requirements: 2a.1, 2a.2, 2a.3, 2a.4, 2a.5
# =============================================================================

variable "skip_quota_check" {
  description = <<-EOT
    Skip AWS service quota validation during terraform plan/apply.
    WARNING: Setting this to true may result in deployment failures if quotas are insufficient.
    Only use this if you have manually verified quota availability.
  EOT
  type        = bool
  default     = false
}

variable "auto_request_quota_increases" {
  description = <<-EOT
    Automatically request AWS service quota increases if current quotas are insufficient.
    Note: Quota increase requests may take 1-5 business days to be approved.
  EOT
  type        = bool
  default     = false
}
