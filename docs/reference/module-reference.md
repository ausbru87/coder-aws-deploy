# Module and Provider Reference

This document provides comprehensive reference documentation for all Terraform modules and providers used in the Coder deployment architecture.

## Table of Contents

- [AWS Provider Modules](#aws-provider-modules)
  - [VPC Module](#vpc-module)
  - [EKS Module](#eks-module)
  - [Aurora Module](#aurora-module)
  - [DNS Module](#dns-module)
  - [Observability Module](#observability-module)
  - [Quota Validation Module](#quota-validation-module)
  - [Coder Module](#coder-module)
- [Coderd Provider Resources](#coderd-provider-resources)
  - [Provider Configuration](#provider-configuration)
  - [Data Sources](#data-sources)
  - [Resources](#resources)

---

## AWS Provider Modules

### VPC Module

**Path:** `modules/vpc/`

Creates the VPC, subnets, NAT gateways, and VPC endpoints for the Coder deployment.

#### Variables

| Variable | Type | Description | Default | Required |
|----------|------|-------------|---------|----------|
| `project_name` | string | Project name for resource naming | - | Yes |
| `environment` | string | Environment name (prod, staging, dev) | - | Yes |
| `vpc_cidr` | string | CIDR block for the VPC | `10.0.0.0/16` | No |
| `availability_zones` | list(string) | List of AZs to deploy into | - | Yes |
| `max_workspaces` | number | Max concurrent workspaces for CIDR sizing | `3000` | No |
| `enable_vpc_endpoints` | bool | Enable VPC endpoints for AWS services | `true` | No |
| `enable_flow_logs` | bool | Enable VPC Flow Logs | `true` | No |
| `flow_log_retention_days` | number | Flow log retention in CloudWatch | `90` | No |
| `tags` | map(string) | Additional tags for resources | `{}` | No |

#### Outputs

| Output | Type | Description |
|--------|------|-------------|
| `vpc_id` | string | VPC ID |
| `public_subnet_ids` | list(string) | Public subnet IDs |
| `private_control_subnet_ids` | list(string) | Control plane subnet IDs |
| `private_provisioner_subnet_ids` | list(string) | Provisioner subnet IDs |
| `private_workspace_subnet_ids` | list(string) | Workspace subnet IDs |
| `database_subnet_ids` | list(string) | Database subnet IDs |
| `nat_gateway_ids` | list(string) | NAT Gateway IDs |
| `node_security_group_id` | string | EKS node security group ID |
| `rds_security_group_id` | string | RDS security group ID |
| `vpc_endpoint_security_group_id` | string | VPC endpoint security group ID |

#### Subnet CIDR Allocation

| Subnet Type | CIDR Range | Purpose |
|-------------|------------|---------|
| Public | 10.0.0.0/20, 10.0.16.0/20, 10.0.32.0/20 | NAT Gateways, NLB ENIs |
| Private (Control) | 10.0.48.0/20, 10.0.64.0/20, 10.0.80.0/20 | coderd nodes |
| Private (Provisioner) | 10.0.96.0/20, 10.0.112.0/20, 10.0.128.0/20 | Provisioner nodes |
| Private (Workspace) | 10.0.144.0/18 | Workspace nodes (larger allocation) |
| Database | 10.0.208.0/21, 10.0.216.0/21, 10.0.224.0/21 | Aurora PostgreSQL |

---

### EKS Module

**Path:** `modules/eks/`

Creates the EKS cluster, node groups, IAM roles, and Kubernetes controllers.

#### Variables

| Variable | Type | Description | Default | Required |
|----------|------|-------------|---------|----------|
| `project_name` | string | Project name for resource naming | - | Yes |
| `environment` | string | Environment name | - | Yes |
| `cluster_version` | string | Kubernetes version | `1.31` | No |
| `vpc_id` | string | VPC ID | - | Yes |
| `subnet_ids` | list(string) | Subnet IDs for EKS | - | Yes |
| `node_security_group_id` | string | Security group for nodes | - | Yes |

##### Control Node Group

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `control_node_instance_type` | string | Instance type | `m5.large` |
| `control_node_min_size` | number | Minimum nodes | `2` |
| `control_node_max_size` | number | Maximum nodes | `3` |
| `control_node_desired_size` | number | Desired nodes | `2` |
| `control_node_disk_size` | number | EBS volume size (GB) | `100` |

##### Provisioner Node Group

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `prov_node_instance_type` | string | Instance type | `c5.2xlarge` |
| `prov_node_min_size` | number | Minimum nodes | `0` |
| `prov_node_max_size` | number | Maximum nodes | `20` |
| `prov_node_desired_size` | number | Desired nodes (off-peak) | `0` |
| `prov_node_desired_peak` | number | Desired nodes (peak) | `5` |
| `prov_node_disk_size` | number | EBS volume size (GB) | `100` |

##### Workspace Node Group

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `ws_node_instance_type` | string | Instance type | `m5.2xlarge` |
| `ws_node_min_size` | number | Minimum nodes | `10` |
| `ws_node_max_size` | number | Maximum nodes | `200` |
| `ws_node_desired_size` | number | Desired nodes (off-peak) | `10` |
| `ws_node_desired_peak` | number | Desired nodes (peak) | `50` |
| `ws_node_disk_size` | number | EBS volume size (GB) | `200` |
| `ws_use_spot_instances` | bool | Use spot instances | `true` |
| `ws_spot_allocation_strategy` | string | Spot allocation strategy | `capacity-optimized` |

##### Scaling Schedule

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `scaling_schedule_start` | string | Cron for scale up | `45 6 * * MON-FRI` |
| `scaling_schedule_stop` | string | Cron for scale down | `15 18 * * MON-FRI` |
| `scaling_timezone` | string | Timezone for schedules | `America/New_York` |

#### Outputs

| Output | Type | Description |
|--------|------|-------------|
| `cluster_name` | string | EKS cluster name |
| `cluster_endpoint` | string | EKS API endpoint |
| `cluster_certificate_authority_data` | string | Cluster CA certificate |
| `cluster_oidc_issuer_url` | string | OIDC issuer URL for IRSA |
| `cluster_oidc_provider_arn` | string | OIDC provider ARN |
| `control_node_group_arn` | string | Control node group ARN |
| `prov_node_group_arn` | string | Provisioner node group ARN |
| `ws_node_group_arn` | string | Workspace node group ARN |
| `coder_server_role_arn` | string | IAM role ARN for coderd |
| `coder_prov_role_arn` | string | IAM role ARN for provisioners |

#### Node Taints

| Node Group | Taint Key | Taint Value | Effect |
|------------|-----------|-------------|--------|
| coder-control | `coder.com/nodepool` | `control` | `NoSchedule` |
| coder-prov | `coder.com/nodepool` | `provisioner` | `NoSchedule` |
| coder-ws | `coder.com/nodepool` | `workspace` | `NoSchedule` |

---

### Aurora Module

**Path:** `modules/aurora/`

Creates the Aurora PostgreSQL Serverless v2 cluster for Coder metadata storage.

#### Variables

| Variable | Type | Description | Default | Required |
|----------|------|-------------|---------|----------|
| `project_name` | string | Project name | - | Yes |
| `environment` | string | Environment name | - | Yes |
| `vpc_id` | string | VPC ID | - | Yes |
| `subnet_ids` | list(string) | Database subnet IDs | - | Yes |
| `security_group_id` | string | RDS security group ID | - | Yes |
| `engine_version` | string | PostgreSQL version | `16.4` | No |
| `min_capacity` | number | Min ACU capacity | `0.5` | No |
| `max_capacity` | number | Max ACU capacity | `16` | No |
| `backup_retention_days` | number | Backup retention (min 90) | `90` | No |
| `enable_cross_region_backup` | bool | Enable cross-region replication | `true` | No |
| `backup_region` | string | Cross-region backup destination | `us-west-2` | No |
| `deletion_protection` | bool | Enable deletion protection | `true` | No |
| `storage_encrypted` | bool | Enable encryption at rest | `true` | No |
| `kms_key_id` | string | KMS key for encryption | `""` (AWS managed) | No |
| `iam_database_authentication_enabled` | bool | Enable IAM auth | `true` | No |

#### Outputs

| Output | Type | Description |
|--------|------|-------------|
| `cluster_endpoint` | string | Writer endpoint |
| `cluster_reader_endpoint` | string | Reader endpoint |
| `cluster_port` | number | Database port (5432) |
| `cluster_database_name` | string | Database name |
| `cluster_master_username` | string | Master username |
| `cluster_master_password_secret_arn` | string | Secrets Manager ARN for password |
| `cluster_arn` | string | Cluster ARN |

---

### DNS Module

**Path:** `modules/dns/`

Configures Route 53 records and ACM certificates.

#### Variables

| Variable | Type | Description | Default | Required |
|----------|------|-------------|---------|----------|
| `base_domain` | string | Base domain name | - | Yes |
| `coder_subdomain` | string | Subdomain for Coder | `coder` | No |
| `route53_zone_id` | string | Zone ID (auto-lookup if empty) | `""` | No |
| `create_acm_certificate` | bool | Create new ACM certificate | `true` | No |
| `existing_acm_certificate_arn` | string | Existing cert ARN | `""` | No |
| `nlb_dns_name` | string | NLB DNS name for A record | - | Yes |
| `nlb_zone_id` | string | NLB hosted zone ID | - | Yes |
| `certificate_transparency_logging` | bool | Enable CT logging | `true` | No |

#### Outputs

| Output | Type | Description |
|--------|------|-------------|
| `access_url` | string | Full Coder URL (https://coder.example.com) |
| `wildcard_access_url` | string | Wildcard URL (*.coder.example.com) |
| `acm_certificate_arn` | string | ACM certificate ARN |
| `route53_zone_id` | string | Route 53 zone ID |

---

### Observability Module

**Path:** `modules/observability/`

Configures CloudWatch, CloudTrail, dashboards, and alerts.

#### Variables

| Variable | Type | Description | Default | Required |
|----------|------|-------------|---------|----------|
| `project_name` | string | Project name | - | Yes |
| `environment` | string | Environment name | - | Yes |
| `log_retention_days` | number | Log retention (min 90) | `90` | No |
| `enable_cloudtrail` | bool | Enable CloudTrail | `true` | No |
| `cloudtrail_s3_bucket_name` | string | S3 bucket for CloudTrail | `""` | No |
| `enable_container_insights` | bool | Enable Container Insights | `true` | No |
| `alert_sns_topic_arn` | string | SNS topic for alarms | `""` | No |
| `api_latency_p95_threshold_ms` | number | P95 latency threshold | `500` | No |
| `api_latency_p99_threshold_ms` | number | P99 latency threshold | `1000` | No |
| `scaling_delay_threshold_minutes` | number | Scaling delay threshold | `5` | No |
| `provisioner_key_expiration_days` | number | Key expiration alert threshold | `14` | No |

#### Outputs

| Output | Type | Description |
|--------|------|-------------|
| `cloudwatch_log_group_arns` | map(string) | Log group ARNs by component |
| `cloudtrail_arn` | string | CloudTrail ARN |
| `dashboard_url` | string | CloudWatch dashboard URL |
| `alarm_arns` | list(string) | CloudWatch alarm ARNs |

---

### Quota Validation Module

**Path:** `modules/quota-validation/`

Validates AWS service quotas before deployment.

#### Variables

| Variable | Type | Description | Default | Required |
|----------|------|-------------|---------|----------|
| `aws_region` | string | AWS region | - | Yes |
| `max_workspaces` | number | Max concurrent workspaces | `3000` | No |
| `skip_quota_check` | bool | Skip validation | `false` | No |
| `auto_request_quota_increases` | bool | Auto-request increases | `false` | No |

#### Outputs

| Output | Type | Description |
|--------|------|-------------|
| `quota_status` | map(object) | Status of each quota check |
| `quota_sufficient` | bool | Whether all quotas are sufficient |
| `quota_increase_requests` | list(string) | Pending quota increase request IDs |

---

### Coder Module

**Path:** `modules/coder/`

Deploys Coder via Helm and configures the platform.

#### Variables

| Variable | Type | Description | Default | Required |
|----------|------|-------------|---------|----------|
| `project_name` | string | Project name | - | Yes |
| `environment` | string | Environment name | - | Yes |
| `coder_version` | string | Helm chart version | `2.18.0` | No |
| `coderd_replicas` | number | Number of coderd replicas | `2` | No |
| `access_url` | string | Coder access URL | - | Yes |
| `wildcard_access_url` | string | Wildcard access URL | - | Yes |
| `database_url` | string | PostgreSQL connection URL | - | Yes |
| `oidc_issuer_url` | string | OIDC issuer URL | - | Yes |
| `oidc_client_id` | string | OIDC client ID | - | Yes |
| `oidc_client_secret_arn` | string | Secrets Manager ARN | - | Yes |
| `external_auth_provider` | string | Git provider type | `github` | No |
| `external_auth_client_id` | string | External auth client ID | `""` | No |
| `external_auth_client_secret_arn` | string | External auth secret ARN | `""` | No |
| `max_workspaces_per_user` | number | Workspace quota per user | `3` | No |
| `enable_prometheus_metrics` | bool | Enable Prometheus metrics | `true` | No |
| `nlb_ssl_policy` | string | NLB TLS policy | `ELBSecurityPolicy-TLS13-1-2-2021-06` | No |
| `acm_certificate_arn` | string | ACM certificate ARN | - | Yes |

#### Outputs

| Output | Type | Description |
|--------|------|-------------|
| `access_url` | string | Coder access URL |
| `coder_namespace` | string | Coder namespace |
| `provisioner_namespace` | string | Provisioner namespace |
| `workspace_namespace` | string | Workspace namespace |
| `nlb_dns_name` | string | NLB DNS name |
| `nlb_zone_id` | string | NLB hosted zone ID |

---

## Coderd Provider Resources

The coderd Terraform provider enables declarative management of Coder configuration for Day 1/2 operations.

**Provider Documentation:** https://registry.terraform.io/providers/coder/coderd/latest/docs

### Provider Configuration

```hcl
provider "coderd" {
  # URL of the Coder deployment
  url = "https://coder.example.com"

  # Authentication (use environment variable CODER_SESSION_TOKEN)
  # token = var.coder_admin_token  # Not recommended for production
}
```

#### Environment Variables

| Variable | Description |
|----------|-------------|
| `CODER_SESSION_TOKEN` | Authentication token (recommended) |
| `CODER_URL` | Coder URL (alternative to provider config) |

### Data Sources

#### coderd_organization

Retrieves organization information.

```hcl
data "coderd_organization" "default" {
  is_default = true
}

# Or by ID
data "coderd_organization" "specific" {
  id = "org-uuid"
}
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | string | Organization UUID |
| `name` | string | Organization name |
| `is_default` | bool | Whether this is the default org |

#### coderd_user

Retrieves user information.

```hcl
data "coderd_user" "admin" {
  username = "admin"
}
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | string | User UUID |
| `username` | string | Username |
| `email` | string | Email address |
| `roles` | list(string) | Assigned roles |

#### coderd_group

Retrieves group information.

```hcl
data "coderd_group" "developers" {
  organization_id = data.coderd_organization.default.id
  name            = "developers"
}
```

### Resources

#### coderd_group

Manages Coder groups for IDP sync.

```hcl
resource "coderd_group" "platform_admins" {
  organization_id = data.coderd_organization.default.id
  name            = "coder-platform-admins"
  display_name    = "Platform Administrators"
  avatar_url      = ""
  quota_allowance = 0  # Unlimited
}
```

| Argument | Type | Description | Required |
|----------|------|-------------|----------|
| `organization_id` | string | Organization UUID | Yes |
| `name` | string | Group name (matches IDP group) | Yes |
| `display_name` | string | Display name | No |
| `avatar_url` | string | Avatar URL | No |
| `quota_allowance` | number | Quota in credits (0 = unlimited) | No |

#### coderd_template

Manages Coder templates declaratively.

```hcl
resource "coderd_template" "pod_swdev" {
  organization_id = data.coderd_organization.default.id
  name            = "pod-swdev"
  display_name    = "Pod Software Development"
  description     = "Kubernetes pod-based software development workspace"
  icon            = "/emojis/1f4bb.png"

  versions = [{
    directory = "${path.module}/templates/pod-swdev"
    active    = true
    name      = "v1.0.0"
    message   = "Initial release"
  }]

  # Access control
  acl = {
    groups = [
      {
        id   = coderd_group.developers.id
        role = "use"
      },
      {
        id   = coderd_group.template_owners.id
        role = "admin"
      }
    ]
  }

  # Template settings
  default_ttl_ms              = 28800000  # 8 hours
  activity_bump_ms            = 3600000   # 1 hour
  autostop_requirement_days   = 1
  autostop_requirement_weeks  = 0
  allow_user_autostart        = true
  allow_user_autostop         = true
  allow_user_cancel_workspace = true
}
```

| Argument | Type | Description | Required |
|----------|------|-------------|----------|
| `organization_id` | string | Organization UUID | Yes |
| `name` | string | Template name (URL-safe) | Yes |
| `display_name` | string | Display name | No |
| `description` | string | Template description | No |
| `icon` | string | Icon path or emoji | No |
| `versions` | list(object) | Template versions | Yes |
| `acl` | object | Access control list | No |
| `default_ttl_ms` | number | Default workspace TTL | No |
| `activity_bump_ms` | number | Activity bump duration | No |
| `allow_user_autostart` | bool | Allow user autostart | No |
| `allow_user_autostop` | bool | Allow user autostop | No |

#### coderd_provisioner_key

Manages provisioner authentication keys.

```hcl
resource "coderd_provisioner_key" "external" {
  organization_id = data.coderd_organization.default.id
  name            = "external-provisioner-key"

  tags = {
    scope       = "organization"
    environment = "production"
  }
}
```

| Argument | Type | Description | Required |
|----------|------|-------------|----------|
| `organization_id` | string | Organization UUID | Yes |
| `name` | string | Key name | Yes |
| `tags` | map(string) | Tags for provisioner scoping | No |

| Attribute | Type | Description |
|-----------|------|-------------|
| `key` | string | The provisioner key (sensitive) |
| `id` | string | Key UUID |

---

## Related Documentation

- **[Workspace Template Contract Reference](./template-contract.md)** - Interface specification for workspace templates
- **[Deployment Guide](../guides/deployment-guide.md)** - Step-by-step deployment instructions
- **[Configuration Guide](../guides/configuration-guide.md)** - Configuration best practices and examples
- **[Architecture Overview](../architecture-overview.md)** - System architecture and design decisions
