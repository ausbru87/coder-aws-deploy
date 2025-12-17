# Quota Validation Module
# Requirements: 2a.1, 2a.2, 2a.3, 2a.4, 2a.5
#
# This module validates AWS service quotas before infrastructure provisioning
# and blocks deployment if quotas are insufficient.

locals {
  # Instance type to vCPU mapping
  instance_vcpus = {
    "m5.large"     = 2
    "m5.xlarge"    = 4
    "m5.2xlarge"   = 8
    "m5.4xlarge"   = 16
    "c5.large"     = 2
    "c5.xlarge"    = 4
    "c5.2xlarge"   = 8
    "c5.4xlarge"   = 16
    "g4dn.xlarge"  = 4
    "g4dn.2xlarge" = 8
    "g5.xlarge"    = 4
    "g5.2xlarge"   = 8
    "p3.2xlarge"   = 8
    "p4d.24xlarge" = 96
  }

  # Calculate vCPUs for each node group
  control_vcpus = var.control_node_max_size * lookup(local.instance_vcpus, var.control_node_instance_type, 2)
  prov_vcpus    = var.prov_node_max_size * lookup(local.instance_vcpus, var.prov_node_instance_type, 8)
  ws_vcpus      = var.ws_node_max_size * lookup(local.instance_vcpus, var.ws_node_instance_type, 8)

  # Apply buffer
  buffer_multiplier = 1 + (var.quota_buffer_percent / 100)

  # Required quotas with buffer
  required_quotas = {
    # EC2 Quotas
    ec2_ondemand_standard_vcpus = ceil((local.control_vcpus + local.prov_vcpus + (var.ws_use_spot_instances ? 0 : local.ws_vcpus)) * local.buffer_multiplier)
    ec2_spot_standard_vcpus     = var.ws_use_spot_instances ? ceil(local.ws_vcpus * local.buffer_multiplier) : 0
    ec2_ondemand_g_vcpus        = var.enable_gpu_workspaces ? ceil(var.max_gpu_workspaces * 8 * local.buffer_multiplier) : 0
    ec2_ondemand_p_vcpus        = var.enable_gpu_workspaces ? ceil(var.max_gpu_workspaces * 8 * 0.25 * local.buffer_multiplier) : 0
    ec2_elastic_ips             = 6 # 3 NAT Gateways (one per AZ) + buffer

    # EBS Quotas (in TiB)
    ebs_gp3_storage_tib = ceil((var.max_workspaces * var.average_workspace_storage_gb / 1024) * local.buffer_multiplier)
    ebs_gp3_iops        = ceil(var.max_workspaces * 100 * local.buffer_multiplier) # 100 IOPS per workspace average

    # VPC Quotas
    vpc_count                = 5
    subnets_per_vpc          = 50
    nat_gateways_per_az      = 5
    network_interfaces       = ceil(var.max_workspaces * 2 * local.buffer_multiplier) # 2 ENIs per workspace average
    security_groups_per_vpc  = 300
    rules_per_security_group = 200

    # EKS Quotas
    eks_clusters            = 10
    managed_node_groups     = 30
    nodes_per_managed_group = ceil(var.ws_node_max_size * local.buffer_multiplier)

    # RDS/Aurora Quotas
    db_clusters    = 40
    db_storage_gib = 100000

    # Other Quotas
    secrets_manager_secrets = 500
    route53_hosted_zones    = 50
    acm_certificates        = 2500
  }

  # Quota definitions with service codes and quota codes
  quota_definitions = [
    {
      name         = "Running On-Demand Standard instances"
      service_code = "ec2"
      quota_code   = "L-1216C47A"
      required     = local.required_quotas.ec2_ondemand_standard_vcpus
      unit         = "vCPUs"
    },
    {
      name         = "All Standard Spot Instance Requests"
      service_code = "ec2"
      quota_code   = "L-34B43A08"
      required     = local.required_quotas.ec2_spot_standard_vcpus
      unit         = "vCPUs"
    },
    {
      name         = "Running On-Demand G and VT instances"
      service_code = "ec2"
      quota_code   = "L-DB2E81BA"
      required     = local.required_quotas.ec2_ondemand_g_vcpus
      unit         = "vCPUs"
    },
    {
      name         = "Running On-Demand P instances"
      service_code = "ec2"
      quota_code   = "L-417A185B"
      required     = local.required_quotas.ec2_ondemand_p_vcpus
      unit         = "vCPUs"
    },
    {
      name         = "EC2-VPC Elastic IPs"
      service_code = "ec2"
      quota_code   = "L-0263D0A3"
      required     = local.required_quotas.ec2_elastic_ips
      unit         = "IPs"
    },
    {
      name         = "Storage for gp3 volumes"
      service_code = "ebs"
      quota_code   = "L-7A658B76"
      required     = local.required_quotas.ebs_gp3_storage_tib
      unit         = "TiB"
    },
    {
      name         = "VPCs per Region"
      service_code = "vpc"
      quota_code   = "L-F678F1CE"
      required     = local.required_quotas.vpc_count
      unit         = "VPCs"
    },
    {
      name         = "Subnets per VPC"
      service_code = "vpc"
      quota_code   = "L-407747CB"
      required     = local.required_quotas.subnets_per_vpc
      unit         = "subnets"
    },
    {
      name         = "NAT gateways per AZ"
      service_code = "vpc"
      quota_code   = "L-FE5A380F"
      required     = local.required_quotas.nat_gateways_per_az
      unit         = "NAT GWs"
    },
    {
      name         = "Network interfaces per Region"
      service_code = "vpc"
      quota_code   = "L-DF5E4CA3"
      required     = local.required_quotas.network_interfaces
      unit         = "ENIs"
    },
    {
      name         = "EKS Clusters"
      service_code = "eks"
      quota_code   = "L-1194D53C"
      required     = local.required_quotas.eks_clusters
      unit         = "clusters"
    },
    {
      name         = "Managed node groups per cluster"
      service_code = "eks"
      quota_code   = "L-6D54EA21"
      required     = local.required_quotas.managed_node_groups
      unit         = "node groups"
    },
    {
      name         = "Nodes per managed node group"
      service_code = "eks"
      quota_code   = "L-BD136A63"
      required     = local.required_quotas.nodes_per_managed_group
      unit         = "nodes"
    },
    {
      name         = "DB clusters"
      service_code = "rds"
      quota_code   = "L-952B80B8"
      required     = local.required_quotas.db_clusters
      unit         = "clusters"
    },
  ]
}

# Generate quota requirements JSON for scripts
resource "local_file" "quota_requirements" {
  filename = "${path.module}/generated/quota-requirements.json"
  content = jsonencode({
    region            = var.aws_region
    max_workspaces    = var.max_workspaces
    buffer_percent    = var.quota_buffer_percent
    required_quotas   = local.required_quotas
    quota_definitions = local.quota_definitions
  })
}

# Pre-flight quota validation
resource "null_resource" "quota_preflight_check" {
  count = var.skip_quota_check ? 0 : 1

  triggers = {
    max_workspaces = var.max_workspaces
    region         = var.aws_region
  }

  provisioner "local-exec" {
    command     = "${path.module}/scripts/preflight-check.sh"
    interpreter = ["bash", "-c"]

    environment = {
      AWS_REGION              = var.aws_region
      QUOTA_REQUIREMENTS_FILE = "${path.module}/generated/quota-requirements.json"
      AUTO_REQUEST_INCREASES  = var.auto_request_quota_increases ? "true" : "false"
    }
  }

  depends_on = [local_file.quota_requirements]
}
