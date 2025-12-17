# ==============================================================================
# Coder AWS Deployment Pattern: Single Region Simple (SR-Simple)
# ==============================================================================
#
# This pattern deploys Coder with:
# - 1 availability zone for cost optimization
# - 1 coderd replica (non-HA)
# - No time-based autoscaling
# - On-demand instances only
# - Capacity for up to 100 concurrent workspaces
#
# Status: FUTURE (v2) - NOT YET VALIDATED
# AWS Region: us-east-1 (can be customized)
# Target Audience: Development/test environments, small teams (<10 users)
#
# ==============================================================================

# ==============================================================================
# Feature Flags
# ==============================================================================

deployment_features = {
  high_availability  = false # 1 AZ, 1 coderd replica, on-demand instances
  time_based_scaling = false # No scheduling (static capacity)
}

# ==============================================================================
# General Configuration
# ==============================================================================

project_name = "coder"
environment  = "dev"
owner        = "platform-team" # REQUIRED: Update with your team/owner
aws_region   = "us-east-1"

# ==============================================================================
# Network Configuration
# ==============================================================================

vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a"] # Single AZ for simplicity
max_workspaces       = 100
enable_vpc_endpoints = false # Cost optimization

# ==============================================================================
# EKS Configuration
# ==============================================================================

eks_cluster_version = "1.31"

# Control Node Group (coderd) - Minimal HA
control_node_instance_type = "m5.large"
control_node_min_size      = 1
control_node_max_size      = 2

# Provisioner Node Group
prov_node_instance_type = "c5.xlarge" # Smaller for dev
prov_node_min_size      = 0
prov_node_max_size      = 5
prov_node_desired_peak  = 1

# Workspace Node Group
ws_node_instance_type = "m5.xlarge" # Smaller for dev
ws_node_min_size      = 1
ws_node_max_size      = 10
ws_node_desired_peak  = 2
ws_use_spot_instances = false # On-demand for stability in dev

# ==============================================================================
# Time-Based Scaling Configuration (Disabled for SR-Simple)
# ==============================================================================

scaling_schedule_start = "" # Disabled
scaling_schedule_stop  = "" # Disabled
scaling_timezone       = "America/New_York"

# ==============================================================================
# Aurora PostgreSQL Configuration
# ==============================================================================

aurora_engine_version        = "16.4"
aurora_min_capacity          = 0.5
aurora_max_capacity          = 4 # Lower max for cost optimization
aurora_backup_retention_days = 7 # Shorter retention for dev

enable_cross_region_backup = false
backup_region              = ""

# ==============================================================================
# DNS and Certificate Configuration
# ==============================================================================

base_domain                  = "example.com" # REQUIRED
coder_subdomain              = "coder-dev"   # Results in coder-dev.example.com
route53_zone_id              = ""
create_acm_certificate       = true
existing_acm_certificate_arn = ""

# ==============================================================================
# OIDC Authentication Configuration
# ==============================================================================

oidc_issuer_url        = "https://login.microsoftonline.com/YOUR_TENANT_ID/v2.0" # REQUIRED
oidc_client_id         = "YOUR_CLIENT_ID"                                        # REQUIRED
oidc_client_secret_arn = "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret/..."   # REQUIRED

# ==============================================================================
# Coder Configuration
# ==============================================================================

coder_version           = "2.18.0"
coderd_replicas         = 1 # Non-HA for dev
max_workspaces_per_user = 5 # Higher limit for dev/test

# ==============================================================================
# Observability Configuration (Minimal)
# ==============================================================================

log_retention_days        = 7 # Shorter for cost optimization
enable_container_insights = false
enable_prometheus_metrics = false
enable_amp_integration    = false
enable_cloudtrail         = false
alert_sns_topic_arn       = ""

# ==============================================================================
# Coderd Provider Configuration
# ==============================================================================

enable_coderd_provider = false
coder_admin_token      = ""

idp_group_mappings = {}
