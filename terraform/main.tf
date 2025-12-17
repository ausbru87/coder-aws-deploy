# Coder Deployment on AWS EKS
# Main Terraform configuration for production-ready Coder platform
#
# This configuration provisions:
# - VPC with multi-AZ subnets for control plane, provisioners, and workspaces
# - EKS cluster with dedicated node groups
# - Aurora PostgreSQL Serverless v2 database
# - Network Load Balancer with TLS termination
# - Supporting AWS services (Route 53, ACM, Secrets Manager, CloudWatch)

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.26"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }
    coderd = {
      source  = "coder/coderd"
      version = "~> 0.0.11"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  # S3 backend configuration - uncomment and configure for production
  # backend "s3" {
  #   bucket         = "coder-terraform-state"
  #   key            = "coder/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "coder-terraform-locks"
  # }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Kubernetes Provider - configured after EKS cluster creation
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Helm Provider
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# Local values for common configurations
# Note: common_tags is defined in locals.tf with deployment pattern info
locals {
  cluster_name = "${var.project_name}-${var.environment}"

  # Slice availability zones based on feature flag
  selected_availability_zones = slice(var.availability_zones, 0, local.availability_zone_count)
}

# =============================================================================
# Quota Validation Module
# =============================================================================
# Pre-flight validation of AWS service quotas
# Requirements: 2a.1, 2a.2, 2a.3, 2a.4, 2a.5

module "quota_validation" {
  source = "./modules/quota-validation"

  aws_region     = var.aws_region
  max_workspaces = var.max_workspaces

  # Node group configurations for quota calculations
  control_node_max_size      = var.control_node_max_size
  control_node_instance_type = var.control_node_instance_type
  prov_node_max_size         = var.prov_node_max_size
  prov_node_instance_type    = var.prov_node_instance_type
  ws_node_max_size           = var.ws_node_max_size
  ws_node_instance_type      = var.ws_node_instance_type
  ws_use_spot_instances      = local.use_spot_instances # Feature flag: forced off for PubSec

  # Quota validation settings
  skip_quota_check             = var.skip_quota_check
  auto_request_quota_increases = var.auto_request_quota_increases
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  availability_zones   = local.selected_availability_zones # Feature flag: uses 1 or 3 AZs
  max_workspaces       = var.max_workspaces
  enable_vpc_endpoints = local.vpc_endpoints_enabled # Feature flag: forced true for PubSec

  tags = local.common_tags

  # Ensure quota validation passes before provisioning infrastructure
  depends_on = [module.quota_validation]
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  project_name    = var.project_name
  environment     = var.environment
  cluster_name    = local.cluster_name
  cluster_version = var.eks_cluster_version

  vpc_id             = module.vpc.vpc_id
  control_subnet_ids = module.vpc.control_subnet_ids
  prov_subnet_ids    = module.vpc.provisioner_subnet_ids
  ws_subnet_ids      = module.vpc.workspace_subnet_ids

  # Node group configurations
  control_node_instance_type = var.control_node_instance_type
  control_node_min_size      = var.control_node_min_size
  control_node_max_size      = var.control_node_max_size

  prov_node_instance_type = var.prov_node_instance_type
  prov_node_min_size      = var.prov_node_min_size
  prov_node_max_size      = var.prov_node_max_size
  prov_node_desired_peak  = var.prov_node_desired_peak

  ws_node_instance_type = var.ws_node_instance_type
  ws_node_min_size      = var.ws_node_min_size
  ws_node_max_size      = var.ws_node_max_size
  ws_node_desired_peak  = var.ws_node_desired_peak
  ws_use_spot_instances = local.use_spot_instances # Feature flag: forced off for PubSec

  # Scaling schedules (conditional based on time_based_scaling feature)
  enable_autoscaling_schedules = local.enable_autoscaling_schedules # Feature flag
  scaling_schedule_start       = var.scaling_schedule_start
  scaling_schedule_stop        = var.scaling_schedule_stop
  scaling_timezone             = var.scaling_timezone

  tags = local.common_tags
}

# Aurora PostgreSQL Module
module "aurora" {
  source = "./modules/aurora"

  project_name = var.project_name
  environment  = var.environment

  vpc_id                  = module.vpc.vpc_id
  database_subnet_ids     = module.vpc.database_subnet_ids
  allowed_security_groups = [module.eks.node_security_group_id]

  # Database configuration
  engine_version = var.aurora_engine_version
  min_capacity   = var.aurora_min_capacity
  max_capacity   = var.aurora_max_capacity

  # Backup configuration
  backup_retention_period    = var.aurora_backup_retention_days
  enable_cross_region_backup = local.cross_region_backup_enabled # Feature flag: enabled for MR
  backup_region              = var.backup_region

  tags = local.common_tags
}

# DNS Module - Phase 1: ACM Certificate
# Creates the ACM certificate first so it can be used by the NLB
module "dns" {
  source = "./modules/dns"

  project_name    = var.project_name
  environment     = var.environment
  base_domain     = var.base_domain
  coder_subdomain = var.coder_subdomain
  route53_zone_id = var.route53_zone_id

  # NLB configuration - empty initially, DNS records created in phase 2
  nlb_dns_name = ""
  nlb_zone_id  = ""

  # Certificate configuration
  create_certificate               = var.create_acm_certificate
  existing_certificate_arn         = var.existing_acm_certificate_arn
  certificate_transparency_logging = var.certificate_transparency_logging

  tags = local.common_tags
}

# Coder Module (Helm deployments and configuration)
module "coder" {
  source = "./modules/coder"

  project_name = var.project_name
  environment  = var.environment

  # EKS configuration
  cluster_name     = module.eks.cluster_name
  cluster_endpoint = module.eks.cluster_endpoint

  # Database configuration
  database_endpoint   = module.aurora.cluster_endpoint
  database_port       = module.aurora.cluster_port
  database_name       = module.aurora.database_name
  database_secret_arn = module.aurora.master_secret_arn

  # DNS and certificates
  base_domain         = var.base_domain
  coder_subdomain     = var.coder_subdomain
  acm_certificate_arn = module.dns.certificate_arn

  # OIDC configuration
  oidc_issuer_url        = var.oidc_issuer_url
  oidc_client_id         = var.oidc_client_id
  oidc_client_secret_arn = var.oidc_client_secret_arn

  # External auth (Git provider)
  external_auth_provider          = var.external_auth_provider
  external_auth_client_id         = var.external_auth_client_id
  external_auth_client_secret_arn = var.external_auth_client_secret_arn

  # Coder configuration
  coder_version           = var.coder_version
  coderd_replicas         = local.coderd_replicas # Feature flag: 1 for simple, 2+ for HA
  max_workspaces_per_user = var.max_workspaces_per_user

  # Network Load Balancer configuration
  # Requirements: 2.4, 12.7, 12.8, 12.8a
  nlb_ssl_policy         = var.nlb_ssl_policy
  nlb_cross_zone_enabled = var.nlb_cross_zone_enabled
  enable_stun            = var.enable_stun

  # IAM roles
  coder_server_role_arn = module.eks.coder_server_role_arn
  coder_prov_role_arn   = module.eks.coder_prov_role_arn

  tags = local.common_tags

  depends_on = [module.eks, module.aurora, module.dns]
}

# DNS Module - Phase 2: Route 53 Records
# Creates DNS records after the NLB is available
module "dns_records" {
  source = "./modules/dns"

  project_name    = var.project_name
  environment     = var.environment
  base_domain     = var.base_domain
  coder_subdomain = var.coder_subdomain
  route53_zone_id = var.route53_zone_id

  # NLB configuration for ALIAS records
  nlb_dns_name = module.coder.nlb_dns_name
  nlb_zone_id  = module.coder.nlb_zone_id

  # Don't create certificate again - use existing from phase 1
  create_certificate       = false
  existing_certificate_arn = module.dns.certificate_arn

  tags = local.common_tags

  depends_on = [module.coder]
}

# =============================================================================
# Observability Module
# =============================================================================
# Implements logging, monitoring, and alerting infrastructure
# Requirements: 3.5, 3.6, 3.7, 3.8, 8.1, 8.1a, 8.1b, 8.1c, 14.13, 14.20

module "observability" {
  source = "./modules/observability"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # EKS configuration
  cluster_name              = module.eks.cluster_name
  cluster_oidc_provider_arn = module.eks.cluster_oidc_provider_arn
  cluster_oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
  vpc_id                    = module.vpc.vpc_id

  # Log retention (90 days minimum per Requirements 3.8, 365 for PubSec)
  log_retention_days = local.computed_log_retention_days # Feature flag: 365 for PubSec

  # Fluent Bit configuration
  fluent_bit_version   = var.fluent_bit_version
  fluent_bit_image_tag = var.fluent_bit_image_tag

  # CloudWatch Container Insights
  enable_container_insights = var.enable_container_insights

  # Coder observability
  coder_namespace           = module.coder.coder_namespace
  enable_prometheus_metrics = var.enable_prometheus_metrics
  enable_amp_integration    = var.enable_amp_integration
  amp_workspace_id          = var.amp_workspace_id

  # CloudTrail
  enable_cloudtrail         = var.enable_cloudtrail
  cloudtrail_s3_bucket_name = var.cloudtrail_s3_bucket_name

  # Alerting
  alert_sns_topic_arn             = var.alert_sns_topic_arn
  api_latency_p95_threshold_ms    = var.api_latency_p95_threshold_ms
  api_latency_p99_threshold_ms    = var.api_latency_p99_threshold_ms
  scaling_delay_threshold_minutes = var.scaling_delay_threshold_minutes

  # Database monitoring
  aurora_cluster_identifier = module.aurora.cluster_id

  tags = local.common_tags

  depends_on = [module.eks, module.coder]
}
