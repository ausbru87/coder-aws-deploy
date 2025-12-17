# Coder Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

# Database
variable "database_endpoint" {
  description = "Aurora cluster endpoint"
  type        = string
}

variable "database_port" {
  description = "Aurora cluster port"
  type        = number
}

variable "database_name" {
  description = "Database name"
  type        = string
}

variable "database_secret_arn" {
  description = "ARN of Secrets Manager secret for database credentials"
  type        = string
}

# DNS and Certificates
variable "base_domain" {
  description = "Base domain for Coder"
  type        = string
}

variable "coder_subdomain" {
  description = "Subdomain for Coder"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate"
  type        = string
}

# OIDC Authentication
variable "oidc_issuer_url" {
  description = "OIDC issuer URL (e.g., https://login.microsoftonline.com/{tenant}/v2.0)"
  type        = string
}

variable "oidc_client_id" {
  description = "OIDC client ID"
  type        = string
}

variable "oidc_client_secret_arn" {
  description = "ARN of Secrets Manager secret for OIDC client secret"
  type        = string
}

variable "oidc_email_domain" {
  description = "Restrict OIDC signups to specific email domain (empty = allow all)"
  type        = string
  default     = ""
}

variable "oidc_group_field" {
  description = "OIDC token claim containing group membership (varies by IDP)"
  type        = string
  default     = "groups"
}

variable "oidc_group_regex_filter" {
  description = "Regex filter for which IDP groups to sync (empty = sync all)"
  type        = string
  default     = "^coder-.*|^developers$"
}

variable "oidc_group_mapping" {
  description = <<-EOT
    JSON mapping of IDP groups to Coder roles.
    
    Requirements: 12c.4-12c.7
    - coder-platform-admins -> user-admin (Requirement 12c.4)
    - coder-template-owners -> template-admin (Requirement 12c.5)
    - coder-security-audit -> auditor (Requirement 12c.6)
    - developers -> member (Requirement 12c.7)
    
    Format: {"idp-group-name": "coder-role-name"}
    
    Available Coder roles:
    - owner: Full system administration (assign manually, not via mapping)
    - user-admin: User lifecycle management
    - template-admin: Template lifecycle management
    - auditor: Read-only audit access
    - member: Standard user access (default)
  EOT
  type        = string
  default     = "{\"coder-platform-admins\":\"user-admin\",\"coder-template-owners\":\"template-admin\",\"coder-security-audit\":\"auditor\",\"developers\":\"member\"}"
}

variable "oidc_ignore_email_verified" {
  description = "Ignore email verification status from IDP"
  type        = string
  default     = "false"
}

# External Authentication
variable "external_auth_provider" {
  description = "External auth provider type (e.g., github, gitlab, bitbucket)"
  type        = string
  default     = "github"
}

variable "external_auth_id" {
  description = "External auth provider ID (used in templates)"
  type        = string
  default     = "primary-git"
}

variable "external_auth_client_id" {
  description = "External auth client ID"
  type        = string
}

variable "external_auth_client_secret_arn" {
  description = "ARN of Secrets Manager secret for external auth client secret"
  type        = string
  default     = ""
}

variable "external_auth_scopes" {
  description = "OAuth scopes for external auth provider"
  type        = string
  default     = "repo,user:email"
}

variable "external_auth_display_name" {
  description = "Display name for external auth provider in Coder UI"
  type        = string
  default     = "GitHub"
}

# Coder Configuration
variable "coder_version" {
  description = "Coder Helm chart version"
  type        = string
}

variable "coder_image_tag" {
  description = "Coder container image tag (use specific version in production)"
  type        = string
  default     = "latest"
}

variable "coderd_replicas" {
  description = "Number of coderd replicas"
  type        = number
  default     = 2
}

variable "max_workspaces_per_user" {
  description = "Maximum workspaces per user (Requirement 14.15)"
  type        = number
  default     = 3
}

# Session Management
variable "session_duration" {
  description = "Session duration (Requirement 12e.1: 8 hours inactivity timeout)"
  type        = string
  default     = "8h"
}

variable "disable_password_auth" {
  description = "Disable password authentication (OIDC only)"
  type        = string
  default     = "true"
}

# Workspace Lifecycle
variable "default_quiet_hours_schedule" {
  description = "Default quiet hours schedule for workspaces (cron format, ET timezone)"
  type        = string
  default     = "CRON_TZ=America/New_York 0 18 * * *"
}

# DERP/Networking
variable "derp_stun_addresses" {
  description = "STUN server addresses for NAT traversal"
  type        = string
  default     = "stun.l.google.com:19302"
}

variable "derp_force_websockets" {
  description = "Force WebSocket connections for DERP (better for corporate firewalls)"
  type        = string
  default     = "false"
}

# Logging
variable "verbose_logging" {
  description = "Enable verbose logging"
  type        = string
  default     = "false"
}

# Experiments
variable "experiments" {
  description = "Comma-separated list of experimental features to enable"
  type        = string
  default     = ""
}

# Resource Limits
variable "coderd_cpu_request" {
  description = "CPU request for coderd pods"
  type        = string
  default     = "500m"
}

variable "coderd_memory_request" {
  description = "Memory request for coderd pods"
  type        = string
  default     = "1Gi"
}

variable "coderd_cpu_limit" {
  description = "CPU limit for coderd pods"
  type        = string
  default     = "2000m"
}

variable "coderd_memory_limit" {
  description = "Memory limit for coderd pods"
  type        = string
  default     = "4Gi"
}

# IAM Roles
variable "coder_server_role_arn" {
  description = "ARN of Coder server IAM role"
  type        = string
}

variable "coder_prov_role_arn" {
  description = "ARN of Coder provisioner IAM role"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_coderd_provider" {
  description = "Enable coderd provider resources (requires Coder to be deployed first)"
  type        = bool
  default     = false
}

# =============================================================================
# Provisioner Configuration
# Requirements: 11.1, 15.2, 12f.1-12f.6
# =============================================================================

variable "provisioner_replicas" {
  description = "Number of provisioner replicas"
  type        = number
  default     = 3
}

variable "provisioner_key_secret_name" {
  description = "Name of Kubernetes secret containing provisioner key"
  type        = string
  default     = "coder-provisioner-key"
}

variable "provisioner_tags" {
  description = "Provisioner tags for organization/template isolation (Requirement 12f.4)"
  type        = string
  default     = "scope=organization"
}

variable "provisioner_poll_interval" {
  description = "Provisioner poll interval for new jobs"
  type        = string
  default     = "1s"
}

variable "provisioner_poll_jitter" {
  description = "Provisioner poll jitter to prevent thundering herd"
  type        = string
  default     = "100ms"
}

variable "provisioner_log_human" {
  description = "Enable human-readable log format for provisioners"
  type        = string
  default     = "true"
}

variable "provisioner_log_level" {
  description = <<-EOT
    Log level for provisioner daemon (Requirement 12f.6).
    Options: debug, info, warn, error
    Use 'debug' for detailed access logging during troubleshooting.
  EOT
  type        = string
  default     = "info"

  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.provisioner_log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

variable "provisioner_log_json" {
  description = <<-EOT
    Enable JSON log format for provisioners (Requirement 12f.6).
    JSON format enables CloudWatch Logs Insights queries for audit compliance.
    Logs include: template name, workspace name, owner, provisioning status.
  EOT
  type        = string
  default     = "true"
}

variable "provisioner_cpu_request" {
  description = "CPU request for provisioner pods"
  type        = string
  default     = "1000m"
}

variable "provisioner_memory_request" {
  description = "Memory request for provisioner pods"
  type        = string
  default     = "2Gi"
}

variable "provisioner_cpu_limit" {
  description = "CPU limit for provisioner pods"
  type        = string
  default     = "4000m"
}

variable "provisioner_memory_limit" {
  description = "Memory limit for provisioner pods"
  type        = string
  default     = "8Gi"
}

# =============================================================================
# Coderd Provider Configuration (Day 1/2 Operations)
# Requirements: 14.15, 16.3, 12c.1-12c.10
# =============================================================================

variable "platform_admin_quota_allowance" {
  description = "Quota allowance for platform administrators (higher than default)"
  type        = number
  default     = 10
}

variable "template_owner_quota_allowance" {
  description = "Quota allowance for template owners"
  type        = number
  default     = 5
}

variable "developer_quota_allowance" {
  description = "Quota allowance for developers (Requirement 14.15: max 3 workspaces)"
  type        = number
  default     = 3
}

variable "provisioner_key_tags" {
  description = "Tags for provisioner key scoping (Requirement 12f.4)"
  type        = map(string)
  default = {
    scope = "organization"
  }
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

# =============================================================================
# Provisioner Scoping Configuration
# Requirements: 12f.4, 12f.5, 12f.6
# =============================================================================

variable "enable_gpu_provisioner" {
  description = <<-EOT
    Enable dedicated provisioner for GPU workloads (Requirement 12f.4).
    When enabled, creates a separate provisioner key scoped to GPU templates.
    This allows isolation of GPU provisioning from general workloads.
  EOT
  type        = bool
  default     = false
}

variable "enable_windows_provisioner" {
  description = <<-EOT
    Enable dedicated provisioner for Windows workloads (Requirement 12f.4).
    When enabled, creates a separate provisioner key scoped to Windows templates.
    This allows isolation of Windows provisioning from Linux workloads.
  EOT
  type        = bool
  default     = false
}

variable "provisioner_access_logging" {
  description = <<-EOT
    Enable detailed access logging for provisioners (Requirement 12f.6).
    When enabled, provisioner access logs will identify which templates were provisioned.
    Logs are forwarded to CloudWatch for audit and compliance.
  EOT
  type        = bool
  default     = true
}

# =============================================================================
# User Lifecycle Configuration
# Requirements: 12c.9, 12c.10
# =============================================================================

variable "oidc_allow_signups" {
  description = <<-EOT
    Allow automatic user provisioning via OIDC (Requirement 12c.9).
    When enabled, users are automatically created on first OIDC login.
    Group memberships are synchronized from IDP claims.
  EOT
  type        = bool
  default     = true
}

variable "user_deprovisioning_days" {
  description = <<-EOT
    Maximum days to revoke user access after termination (Requirement 12c.10).
    This is a documentation/policy value - actual deprovisioning is handled
    by removing users from IDP groups and/or suspending in Coder.
  EOT
  type        = number
  default     = 30

  validation {
    condition     = var.user_deprovisioning_days > 0 && var.user_deprovisioning_days <= 30
    error_message = "User deprovisioning must occur within 30 days per Requirement 12c.10."
  }
}

# =============================================================================
# Network Load Balancer Configuration
# =============================================================================

variable "nlb_ssl_policy" {
  description = <<-EOT
    SSL/TLS security policy for the NLB. Must enforce TLS 1.2+ with approved cipher suites.
    Default: ELBSecurityPolicy-TLS13-1-2-2021-06 (TLS 1.2/1.3 with AES-GCM and ECDHE)
    
    This policy meets Fortune 2000 security standards (Requirement 12.8a):
    - TLS 1.2 minimum, TLS 1.3 preferred
    - AES-128-GCM and AES-256-GCM cipher suites
    - ECDHE key exchange for forward secrecy
    
    Alternative policies:
    - ELBSecurityPolicy-TLS13-1-3-2021-06: TLS 1.3 only (most restrictive)
    - ELBSecurityPolicy-TLS-1-2-2017-01: TLS 1.2 only (legacy compatibility)
  EOT
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  validation {
    condition = contains([
      "ELBSecurityPolicy-TLS13-1-2-2021-06",
      "ELBSecurityPolicy-TLS13-1-3-2021-06",
      "ELBSecurityPolicy-TLS-1-2-2017-01",
      "ELBSecurityPolicy-TLS-1-2-Ext-2018-06",
      "ELBSecurityPolicy-FS-1-2-2019-08",
      "ELBSecurityPolicy-FS-1-2-Res-2019-08",
      "ELBSecurityPolicy-FS-1-2-Res-2020-10"
    ], var.nlb_ssl_policy)
    error_message = "SSL policy must be a valid AWS NLB security policy that enforces TLS 1.2+."
  }
}

variable "nlb_cross_zone_enabled" {
  description = "Enable cross-zone load balancing for the NLB"
  type        = bool
  default     = true
}

variable "nlb_health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.nlb_health_check_interval >= 10 && var.nlb_health_check_interval <= 300
    error_message = "Health check interval must be between 10 and 300 seconds."
  }
}

variable "nlb_health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 10

  validation {
    condition     = var.nlb_health_check_timeout >= 2 && var.nlb_health_check_timeout <= 120
    error_message = "Health check timeout must be between 2 and 120 seconds."
  }
}

variable "nlb_healthy_threshold" {
  description = "Number of consecutive successful health checks required"
  type        = number
  default     = 2

  validation {
    condition     = var.nlb_healthy_threshold >= 2 && var.nlb_healthy_threshold <= 10
    error_message = "Healthy threshold must be between 2 and 10."
  }
}

variable "nlb_unhealthy_threshold" {
  description = "Number of consecutive failed health checks required"
  type        = number
  default     = 3

  validation {
    condition     = var.nlb_unhealthy_threshold >= 2 && var.nlb_unhealthy_threshold <= 10
    error_message = "Unhealthy threshold must be between 2 and 10."
  }
}

variable "nlb_deregistration_delay" {
  description = "Deregistration delay in seconds for target group"
  type        = number
  default     = 30

  validation {
    condition     = var.nlb_deregistration_delay >= 0 && var.nlb_deregistration_delay <= 3600
    error_message = "Deregistration delay must be between 0 and 3600 seconds."
  }
}

variable "enable_stun" {
  description = "Enable STUN UDP port (3478) for NAT traversal and direct P2P connections"
  type        = bool
  default     = true
}


# =============================================================================
# Observability Configuration
# Requirements: 8.1a, 8.1b, 8.1c, 15.2a
# =============================================================================

variable "enable_prometheus_metrics" {
  description = "Enable Prometheus metrics export from Coder (port 2112)"
  type        = bool
  default     = true
}

variable "enable_service_monitor" {
  description = "Enable ServiceMonitor for Prometheus Operator"
  type        = bool
  default     = false
}

variable "prometheus_namespace" {
  description = "Namespace where Prometheus is deployed"
  type        = string
  default     = "monitoring"
}

variable "enable_amp_integration" {
  description = "Enable Amazon Managed Service for Prometheus (AMP) integration"
  type        = bool
  default     = false
}

variable "amp_remote_write_url" {
  description = "AMP remote write URL (required if enable_amp_integration is true)"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region for AMP integration"
  type        = string
  default     = "us-east-1"
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights integration"
  type        = bool
  default     = false
}

variable "enable_grafana_dashboards" {
  description = "Enable pre-configured Grafana dashboards"
  type        = bool
  default     = false
}

variable "enable_alerting" {
  description = "Enable Prometheus alerting rules"
  type        = bool
  default     = true
}

variable "scrape_interval" {
  description = "Prometheus scrape interval"
  type        = string
  default     = "30s"
}

variable "scrape_timeout" {
  description = "Prometheus scrape timeout"
  type        = string
  default     = "10s"
}

variable "collect_agent_stats" {
  description = "Collect detailed agent/workspace metrics"
  type        = string
  default     = "true"
}

variable "collect_db_metrics" {
  description = "Collect database connection pool metrics"
  type        = string
  default     = "true"
}


# =============================================================================
# Service Account Token Configuration
# Requirements: 12d.3, 12d.6, 12d.7, 12d.8, 12d.9
# =============================================================================

variable "enable_cicd_service_account" {
  description = <<-EOT
    Enable CI/CD service account token infrastructure (Requirement 12d.3).
    When enabled, creates Secrets Manager secret for storing the service account token.
    The actual token must be created via Coder CLI and stored in the secret.
  EOT
  type        = bool
  default     = true
}

variable "cicd_service_account_name" {
  description = <<-EOT
    Name of the CI/CD service account user in Coder (Requirement 12d.7).
    This user should have Template Admin role only for least-privilege access.
  EOT
  type        = string
  default     = "cicd-template-deployer"
}

variable "cicd_token_expiration_days" {
  description = <<-EOT
    Service account token expiration in days (Requirement 12d.6).
    Tokens expire after this period and must be rotated.
    Default: 90 days per security requirements.
  EOT
  type        = number
  default     = 90

  validation {
    condition     = var.cicd_token_expiration_days >= 30 && var.cicd_token_expiration_days <= 90
    error_message = "Token expiration must be between 30 and 90 days per Requirement 12d.6."
  }
}

variable "cicd_token_rotation_warning_days" {
  description = <<-EOT
    Days before token expiration to trigger rotation warning (Requirement 12d.6).
    CloudWatch alarm will alert when token is within this many days of expiration.
  EOT
  type        = number
  default     = 14

  validation {
    condition     = var.cicd_token_rotation_warning_days >= 7 && var.cicd_token_rotation_warning_days <= 30
    error_message = "Rotation warning must be between 7 and 30 days."
  }
}

variable "cicd_token_secret_name" {
  description = <<-EOT
    Name of the Secrets Manager secret for CI/CD token (Requirement 12d.8).
    The secret stores the Coder API token for CI/CD template deployment.
  EOT
  type        = string
  default     = "coder/cicd/template-deployer-token"
}

variable "security_alert_sns_topic_arn" {
  description = <<-EOT
    ARN of SNS topic for security alerts (Requirement 12d.9).
    Used for token compromise notifications and expiration warnings.
  EOT
  type        = string
  default     = ""
}
