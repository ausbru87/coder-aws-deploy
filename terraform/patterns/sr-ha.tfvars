# ==============================================================================
# Coder AWS Deployment Pattern: Single Region High Availability (SR-HA)
# ==============================================================================
#
# This pattern deploys Coder with:
# - 3 availability zones for high availability
# - 2 coderd replicas for redundancy
# - Time-based autoscaling (scale up at 06:45, down at 18:15 ET)
# - Spot instances for workspace nodes with on-demand fallback
# - Capacity for up to 3000 concurrent workspaces
#
# Validated: v1.0.0
# AWS Region: us-east-1 (can be customized)
# Target Audience: Production deployments with 10-30+ concurrent users
#
# ==============================================================================

# ==============================================================================
# Feature Flags
# ==============================================================================

deployment_features = {
  high_availability  = true # 3 AZs, 2+ coderd replicas, spot instances
  time_based_scaling = true # Auto-scale based on schedule (06:45-18:15 ET)
}

# ==============================================================================
# General Configuration
# ==============================================================================

project_name = "coder"
environment  = "prod"
owner        = "platform-team" # REQUIRED: Update with your team/owner
aws_region   = "us-east-1"

# ==============================================================================
# Network Configuration
# ==============================================================================

vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
max_workspaces       = 3000
enable_vpc_endpoints = true

# ==============================================================================
# EKS Configuration
# ==============================================================================

eks_cluster_version = "1.34"

# Control Node Group (coderd)
control_node_instance_type = "m5.large"
control_node_min_size      = 2
control_node_max_size      = 3

# Provisioner Node Group
prov_node_instance_type = "c5.2xlarge"
prov_node_min_size      = 0
prov_node_max_size      = 20
prov_node_desired_peak  = 5 # Pre-provision for morning startup

# Workspace Node Group
ws_node_instance_type = "m5.2xlarge"
ws_node_min_size      = 10
ws_node_max_size      = 200
ws_node_desired_peak  = 50 # Pre-provision for morning workspace creation
ws_use_spot_instances = true

# ==============================================================================
# Time-Based Scaling Configuration (SR-HA Feature)
# ==============================================================================

scaling_schedule_start = "45 6 * * MON-FRI"  # Scale up at 06:45 ET (before 7 AM work start)
scaling_schedule_stop  = "15 18 * * MON-FRI" # Scale down at 18:15 ET (after 6 PM work end)
scaling_timezone       = "America/New_York"

# ==============================================================================
# Aurora PostgreSQL Configuration
# ==============================================================================

aurora_engine_version        = "16.6"
aurora_min_capacity          = 0.5
aurora_max_capacity          = 16
aurora_backup_retention_days = 90

# Cross-region backup (disabled for SR-HA, enabled for MR)
enable_cross_region_backup = false
backup_region              = "us-west-2" # Only used if cross-region enabled

# ==============================================================================
# DNS and Certificate Configuration
# ==============================================================================

base_domain                  = "example.com" # REQUIRED: Update with your domain
coder_subdomain              = "coder"       # Results in coder.example.com
route53_zone_id              = ""            # Leave empty for auto-lookup
create_acm_certificate       = true
existing_acm_certificate_arn = ""

# ==============================================================================
# OIDC Authentication Configuration
# ==============================================================================

oidc_issuer_url        = "https://login.microsoftonline.com/YOUR_TENANT_ID/v2.0" # REQUIRED
oidc_client_id         = "YOUR_CLIENT_ID"                                        # REQUIRED
oidc_client_secret_arn = "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret/..."   # REQUIRED

# ==============================================================================
# External Authentication (Git Provider)
# ==============================================================================

external_auth_provider          = "github"
external_auth_client_id         = "" # Optional: GitHub OAuth App client ID
external_auth_client_secret_arn = "" # Optional: Secrets Manager ARN

# ==============================================================================
# Coder Configuration
# ==============================================================================

coder_version           = "2.29.1"
coderd_replicas         = 2 # HA: minimum 2 replicas
max_workspaces_per_user = 3

# ==============================================================================
# Observability Configuration
# ==============================================================================

log_retention_days           = 90 # Minimum for compliance
fluent_bit_version           = "4.2.1"
enable_container_insights    = true
enable_prometheus_metrics    = true
enable_amp_integration       = false
amp_workspace_id             = ""
enable_cloudtrail            = true
alert_sns_topic_arn          = ""
api_latency_p95_threshold_ms = 500
api_latency_p99_threshold_ms = 1000

# ==============================================================================
# Quota Validation Configuration
# ==============================================================================

skip_quota_check             = false
auto_request_quota_increases = false

# ==============================================================================
# Coderd Provider Configuration (Day 1/2 Operations)
# ==============================================================================

enable_coderd_provider = false # Set to true after Day 0 deployment
coder_admin_token      = ""    # Use CODER_SESSION_TOKEN env var instead

# IDP group mappings (configure after OIDC setup)
idp_group_mappings = {
  "coder-admins"     = "owner"
  "coder-developers" = "member"
  "coder-auditors"   = "auditor"
}

provisioner_key_tags = {
  scope = "organization"
}
