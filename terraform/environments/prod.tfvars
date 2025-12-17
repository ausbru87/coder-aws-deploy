# Production Environment Configuration
# Usage: terraform plan -var-file=environments/prod.tfvars

# =============================================================================
# General Configuration
# =============================================================================
project_name = "coder"
environment  = "prod"
owner        = "platform-team"
aws_region   = "us-east-1"

# =============================================================================
# VPC Configuration
# =============================================================================
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
max_workspaces       = 3000 # Full capacity for production
enable_vpc_endpoints = true

# =============================================================================
# EKS Configuration
# =============================================================================
eks_cluster_version = "1.31"

# Control Node Group (coderd) - static scaling per requirements
control_node_instance_type = "m5.large"
control_node_min_size      = 2
control_node_max_size      = 3

# Provisioner Node Group - time-based scaling
prov_node_instance_type = "c5.2xlarge"
prov_node_min_size      = 0
prov_node_max_size      = 20

# Workspace Node Group - time-based scaling with spot instances
ws_node_instance_type = "m5.2xlarge"
ws_node_min_size      = 10
ws_node_max_size      = 200
ws_use_spot_instances = true

# Scaling Schedules (0645/1815 ET - 15 min before target per Req 14.19)
scaling_schedule_start = "45 6 * * MON-FRI"
scaling_schedule_stop  = "15 18 * * MON-FRI"
scaling_timezone       = "America/New_York"

# =============================================================================
# Aurora PostgreSQL Configuration
# =============================================================================
aurora_engine_version        = "16.4"
aurora_min_capacity          = 0.5
aurora_max_capacity          = 16
aurora_backup_retention_days = 90 # Per Req 8.5
enable_cross_region_backup   = true
backup_region                = "us-west-2"

# =============================================================================
# DNS and Certificates
# =============================================================================
base_domain         = "example.com"
coder_subdomain     = "coder"
acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/prod-cert-id"

# =============================================================================
# OIDC Authentication
# =============================================================================
oidc_issuer_url        = "https://login.microsoftonline.com/tenant-id/v2.0"
oidc_client_id         = "prod-client-id"
oidc_client_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:coder/prod/oidc-secret"

# =============================================================================
# External Authentication (Git Provider)
# =============================================================================
external_auth_provider          = "github"
external_auth_client_id         = "prod-github-client-id"
external_auth_client_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:coder/prod/github-secret"

# =============================================================================
# Coder Configuration
# =============================================================================
coder_version           = "2.18.0"
coderd_replicas         = 2 # Static per Req 4.1
max_workspaces_per_user = 3 # Per Req 14.15
