# Production Environment Configuration Example
# 
# This file demonstrates all available configuration options with detailed comments.
# Copy this file and customize for your environment:
#   cp environments/prod-example.tfvars environments/my-deployment.tfvars
#
# Usage: terraform plan -var-file=environments/my-deployment.tfvars
#
# Requirements Covered: 16.4

# =============================================================================
# GENERAL CONFIGURATION
# =============================================================================

# Project name used for resource naming (e.g., coder-prod-vpc, coder-prod-eks)
project_name = "coder"

# Environment name (prod, staging, dev)
# Used for resource naming and tagging
environment = "prod"

# Resource owner for tagging and cost allocation
# REQUIRED: Change this to your team or organization
owner = "platform-team"

# AWS region for deployment
# Optimized for US East Coast users per Requirement 4.8c
aws_region = "us-east-1"

# =============================================================================
# VPC CONFIGURATION
# =============================================================================

# VPC CIDR block - must be large enough for max_workspaces
# Default /16 supports up to 65,536 IP addresses
vpc_cidr = "10.0.0.0/16"

# Availability zones for multi-AZ deployment
# Minimum 3 AZs recommended for high availability
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Maximum concurrent workspaces for CIDR sizing calculations
# This affects subnet allocation, not actual limits
max_workspaces = 3000

# Enable VPC endpoints for AWS services (S3, ECR, Secrets Manager, CloudWatch)
# Reduces NAT Gateway costs and improves security
enable_vpc_endpoints = true

# =============================================================================
# EKS CLUSTER CONFIGURATION
# =============================================================================

# Kubernetes version - use latest stable EKS version
# Check: aws eks describe-addon-versions --kubernetes-version 1.31
eks_cluster_version = "1.31"

# -----------------------------------------------------------------------------
# Control Node Group (coderd)
# Static scaling per Requirement 4.1 - does not scale up or down
# -----------------------------------------------------------------------------

# Instance type for control plane nodes running coderd
# m5.large: 2 vCPU, 8 GB RAM - sufficient for coderd
control_node_instance_type = "m5.large"

# Minimum and maximum control nodes (static, no autoscaling)
control_node_min_size = 2
control_node_max_size = 3

# -----------------------------------------------------------------------------
# Provisioner Node Group
# Time-based scaling per Requirement 4.2
# -----------------------------------------------------------------------------

# Instance type for provisioner nodes
# c5.2xlarge: 8 vCPU, 16 GB RAM - compute-optimized for Terraform operations
prov_node_instance_type = "c5.2xlarge"

# Minimum provisioner nodes (scales to 0 outside work hours)
prov_node_min_size = 0

# Maximum provisioner nodes during peak
prov_node_max_size = 20

# Desired provisioner nodes during peak hours
prov_node_desired_peak = 5

# -----------------------------------------------------------------------------
# Workspace Node Group
# Time-based scaling per Requirement 4.3
# -----------------------------------------------------------------------------

# Instance type for workspace nodes
# m5.2xlarge: 8 vCPU, 32 GB RAM - balanced for development workloads
ws_node_instance_type = "m5.2xlarge"

# Minimum workspace nodes (maintains baseline capacity)
ws_node_min_size = 10

# Maximum workspace nodes at full capacity
ws_node_max_size = 200

# Desired workspace nodes during peak hours (pre-provisioning)
# Per Requirement 13.4: Pre-provision for morning usage
ws_node_desired_peak = 50

# Use spot instances for workspace nodes with on-demand fallback
# Per Requirement 5.1: Cost optimization with spot instances
ws_use_spot_instances = true

# -----------------------------------------------------------------------------
# Scaling Schedules
# Per Requirement 14.19: Complete 15 minutes before target time
# -----------------------------------------------------------------------------

# Scale up at 6:45 AM ET (15 min before 7 AM target)
scaling_schedule_start = "45 6 * * MON-FRI"

# Scale down at 6:15 PM ET (15 min before 6:30 PM target)
scaling_schedule_stop = "15 18 * * MON-FRI"

# Timezone for scaling schedules
scaling_timezone = "America/New_York"

# =============================================================================
# AURORA POSTGRESQL CONFIGURATION
# =============================================================================

# PostgreSQL engine version - use latest stable Aurora version
aurora_engine_version = "16.4"

# Aurora Serverless v2 capacity range (ACUs)
# 0.5 ACU = 1 GB RAM, scales automatically based on load
aurora_min_capacity = 0.5
aurora_max_capacity = 16

# Backup retention in days
# Per Requirement 8.5: Minimum 90 days for compliance
aurora_backup_retention_days = 90

# Cross-region backup replication
# Per Requirement 8.7: Protect against regional failures
enable_cross_region_backup = true
backup_region              = "us-west-2"

# =============================================================================
# DNS AND CERTIFICATES
# =============================================================================

# Base domain - Route 53 must own this domain
# REQUIRED: Change to your domain
base_domain = "example.com"

# Subdomain for Coder (creates coder.example.com)
coder_subdomain = "coder"

# Route 53 zone ID (leave empty for auto-lookup by domain name)
route53_zone_id = ""

# Create new ACM certificate or use existing
create_acm_certificate = true

# If using existing certificate, provide ARN
# existing_acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/existing-cert-id"

# Enable Certificate Transparency logging
certificate_transparency_logging = true

# =============================================================================
# OIDC AUTHENTICATION
# REQUIRED: Configure your identity provider
# =============================================================================

# OIDC issuer URL from your identity provider
# Examples:
#   Azure AD: https://login.microsoftonline.com/{tenant-id}/v2.0
#   Okta: https://{domain}.okta.com
#   Google: https://accounts.google.com
oidc_issuer_url = "https://login.microsoftonline.com/your-tenant-id/v2.0"

# OIDC client ID from your identity provider
oidc_client_id = "your-client-id"

# Secrets Manager ARN containing OIDC client secret
# Create secret: aws secretsmanager create-secret --name coder/prod/oidc-secret --secret-string "your-secret"
oidc_client_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:coder/prod/oidc-secret"

# =============================================================================
# EXTERNAL AUTHENTICATION (GIT PROVIDER)
# Optional: Configure for workspace Git access
# =============================================================================

# Git provider type
external_auth_provider = "github"

# External auth client ID (from GitHub/GitLab OAuth app)
external_auth_client_id = "your-github-client-id"

# Secrets Manager ARN containing external auth client secret
external_auth_client_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:coder/prod/github-secret"

# =============================================================================
# CODER CONFIGURATION
# =============================================================================

# Coder Helm chart version
coder_version = "2.18.0"

# Number of coderd replicas (static per Requirement 4.1)
coderd_replicas = 2

# Maximum workspaces per user (Coder internal quota)
# Per Requirement 14.15
max_workspaces_per_user = 3

# =============================================================================
# NETWORK LOAD BALANCER CONFIGURATION
# =============================================================================

# TLS security policy
# Per Requirements 12.7, 12.8, 12.8a: TLS 1.2+ with AES-GCM and ECDHE
nlb_ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"

# Enable cross-zone load balancing for high availability
nlb_cross_zone_enabled = true

# Enable STUN for NAT traversal and direct P2P connections
enable_stun = true

# =============================================================================
# OBSERVABILITY CONFIGURATION
# =============================================================================

# Log retention in CloudWatch
# Per Requirement 3.8: Minimum 90 days
log_retention_days = 90

# Fluent Bit version for log forwarding
fluent_bit_version   = "0.47.10"
fluent_bit_image_tag = "3.2.2"

# Enable CloudWatch Container Insights
enable_container_insights = true

# Enable Prometheus metrics export from Coder (port 2112)
enable_prometheus_metrics = true

# Amazon Managed Prometheus integration (optional)
enable_amp_integration = false
# amp_workspace_id = "ws-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Enable CloudTrail logging
enable_cloudtrail = true

# SNS topic for CloudWatch alarms (optional)
# alert_sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:coder-alerts"

# API latency thresholds for alerting
# Per Requirements 14.9, 14.10
api_latency_p95_threshold_ms = 500
api_latency_p99_threshold_ms = 1000

# Scaling delay threshold for alerting
scaling_delay_threshold_minutes = 5

# =============================================================================
# QUOTA VALIDATION
# =============================================================================

# Skip quota validation (not recommended for production)
skip_quota_check = false

# Automatically request quota increases if insufficient
auto_request_quota_increases = false

# =============================================================================
# CODERD PROVIDER (DAY 1/2 OPERATIONS)
# Enable after initial Coder deployment
# =============================================================================

# Enable coderd provider resources
# Set to true after Day 0 infrastructure is deployed and Coder is running
enable_coderd_provider = false

# IDP group mappings for Coder roles
# Customize group names to match your IDP
idp_group_mappings = {
  "coder-platform-admins" = {
    display_name    = "Platform Administrators"
    quota_allowance = 0 # Unlimited
  }
  "coder-template-owners" = {
    display_name    = "Template Owners"
    quota_allowance = 0 # Unlimited
  }
  "coder-security-audit" = {
    display_name    = "Security Auditors"
    quota_allowance = 0 # Unlimited (read-only)
  }
  "developers" = {
    display_name    = "Developers"
    quota_allowance = 100 # 100 credits
  }
}

# Provisioner key tags for scoping
provisioner_key_tags = {
  scope       = "organization"
  environment = "production"
}
