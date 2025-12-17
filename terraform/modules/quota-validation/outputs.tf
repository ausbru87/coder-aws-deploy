# Quota Validation Module Outputs
# Requirements: 2a.1, 2a.2, 2a.4

output "required_quotas" {
  description = "Map of required AWS service quotas"
  value       = local.required_quotas
}

output "quota_definitions" {
  description = "List of quota definitions with service codes and quota codes"
  value       = local.quota_definitions
}

output "quota_requirements_file" {
  description = "Path to the generated quota requirements JSON file"
  value       = local_file.quota_requirements.filename
}

output "quota_validation_passed" {
  description = "Indicates quota validation has been executed (use as dependency)"
  value       = var.skip_quota_check ? true : null_resource.quota_preflight_check[0].id != ""
}

output "calculated_vcpus" {
  description = "Calculated vCPU requirements by node group"
  value = {
    control_vcpus = local.control_vcpus
    prov_vcpus    = local.prov_vcpus
    ws_vcpus      = local.ws_vcpus
    total_vcpus   = local.control_vcpus + local.prov_vcpus + local.ws_vcpus
  }
}

output "quota_summary" {
  description = "Human-readable summary of quota requirements"
  value       = <<-EOT
    AWS Service Quota Requirements Summary
    ======================================
    Region: ${var.aws_region}
    Max Workspaces: ${var.max_workspaces}
    Buffer: ${var.quota_buffer_percent}%

    EC2 Quotas:
    - On-Demand Standard vCPUs: ${local.required_quotas.ec2_ondemand_standard_vcpus}
    - Spot Standard vCPUs: ${local.required_quotas.ec2_spot_standard_vcpus}
    - On-Demand G/VT vCPUs: ${local.required_quotas.ec2_ondemand_g_vcpus}
    - On-Demand P vCPUs: ${local.required_quotas.ec2_ondemand_p_vcpus}
    - Elastic IPs: ${local.required_quotas.ec2_elastic_ips}

    EBS Quotas:
    - GP3 Storage: ${local.required_quotas.ebs_gp3_storage_tib} TiB

    VPC Quotas:
    - VPCs: ${local.required_quotas.vpc_count}
    - Subnets per VPC: ${local.required_quotas.subnets_per_vpc}
    - NAT Gateways per AZ: ${local.required_quotas.nat_gateways_per_az}
    - Network Interfaces: ${local.required_quotas.network_interfaces}

    EKS Quotas:
    - Clusters: ${local.required_quotas.eks_clusters}
    - Node Groups per Cluster: ${local.required_quotas.managed_node_groups}
    - Nodes per Node Group: ${local.required_quotas.nodes_per_managed_group}

    RDS Quotas:
    - DB Clusters: ${local.required_quotas.db_clusters}
  EOT
}
