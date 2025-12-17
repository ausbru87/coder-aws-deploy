# Coder Deployment on AWS EKS

This Terraform repository provisions a production-ready Coder platform on Amazon EKS following AWS Well-Architected principles. It supports up to 3000 concurrent workspaces with 99.9% availability.

## 📖 Documentation

**Complete documentation has been moved to [`/docs/`](../docs/README.md) at the repository root.**

**Quick links:**
- 🚀 [Quick Start Guide](../docs/getting-started/quickstart.md) - Deploy SR-HA in 60 minutes
- 📐 [Architecture Overview](../docs/getting-started/overview.md) - Infrastructure and network architecture
- 🎯 [Choosing a Pattern](../docs/getting-started/choosing-a-pattern.md) - SR-HA vs SR-Simple vs Multi-Region vs PubSec
- ⚙️ [Configuration Reference](../docs/configuration/variables.md) - All Terraform variables
- 🔧 [Operations Guide](../docs/operations/day2-operations.md) - Day-to-day operations and runbooks
- 🆘 [Troubleshooting](../docs/operations/troubleshooting.md) - Common issues and solutions
- 💰 [Cost Estimation](../docs/reference/cost-estimation.md) - Detailed cost breakdowns

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Day 0/1/2 Operations](#day-012-operations)
- [Template Architecture](#template-architecture)
- [Configuration Reference](#configuration-reference)
- [Scaling](#scaling)
- [Troubleshooting](#troubleshooting)
- [References](#references)

## Architecture Overview

The deployment creates:

| Component | AWS Service | Purpose |
|-----------|-------------|---------|
| Network | VPC | Multi-AZ subnets for control plane, provisioners, workspaces, database |
| Compute | EKS | Three dedicated node groups (control, provisioner, workspace) |
| Database | Aurora PostgreSQL Serverless v2 | Coder metadata storage with multi-AZ HA |
| Load Balancer | NLB | TLS termination via ACM, STUN for P2P |
| DNS | Route 53 | Domain management for ACCESS_URL and WILDCARD_ACCESS_URL |
| Secrets | Secrets Manager | OIDC credentials, database credentials |
| Monitoring | CloudWatch | Logs, metrics, dashboards, alerts |

### Module Structure

```
terraform/
├── main.tf                 # Root module configuration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── backend.tf              # S3 backend configuration
├── coderd.tf               # Coderd provider for Day 1/2 ops
├── coderd_variables.tf     # Coderd provider variables
├── backend-config/
│   └── prod.hcl            # Production backend config
├── environments/
│   └── prod.tfvars         # Production configuration
# Documentation moved to /docs/ at repository root
# See ../docs/README.md for complete documentation
├── test/                   # Terratest tests (Go 1.24+)
│   ├── terraform_test.go
│   └── property_test.go
└── modules/
    ├── vpc/                # VPC, subnets, NAT, endpoints
    ├── eks/                # EKS cluster, node groups, IAM
    ├── aurora/             # Aurora PostgreSQL Serverless v2
    ├── dns/                # Route 53 records, ACM certificates
    ├── observability/      # CloudWatch, CloudTrail, dashboards
    ├── quota-validation/   # AWS quota pre-flight checks
    └── coder/              # Coder Helm deployments
        ├── templates/      # Monolithic templates (legacy)
        ├── template-architecture/  # Two-layer template system
        │   ├── contract/           # Contract schema definitions
        │   ├── validation/         # Contract validation
        │   ├── composition/        # Template composition
        │   ├── pairings/           # Default pairings
        │   ├── deployment/         # coderd_template deployment
        │   ├── toolchains/         # Portable toolchain templates
        │   └── bases/              # Instance-specific infra bases
        └── values/         # Helm values templates
```

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| AWS CLI | >= 2.0 | AWS resource management |
| Terraform | >= 1.5.0 | Infrastructure provisioning |
| kubectl | >= 1.29 | Kubernetes management |
| Helm | >= 3.0 | Chart deployments |

### Required AWS Service Quotas

Run the quota validation before deployment:

```bash
cd modules/quota-validation
./scripts/preflight-check.sh
```

| Service | Quota | Required Value |
|---------|-------|----------------|
| EC2 | Running On-Demand Standard instances | 800 vCPUs |
| EC2 | Running Spot Standard instances | 1600 vCPUs |
| EKS | Clusters per region | 5 |
| VPC | VPCs per region | 5 |
| VPC | NAT Gateways per AZ | 3 |
| EBS | General Purpose SSD (gp3) volume storage | 50 TiB |
| Aurora | DB clusters | 10 |

### Coder License

- Coder Premium License required
- All users must be licensed (Requirement 17.1-17.4)

## Quick Start

### 1. Initialize Backend (First Time Only)

```bash
# Initialize with local backend first
terraform init

# Create S3 bucket and DynamoDB table for state management
# See backend.tf for bootstrap resources

# After creating backend resources, migrate to S3
terraform init -backend-config=backend-config/prod.hcl -migrate-state
```

### 2. Configure Variables

```bash
# Copy example tfvars
cp environments/prod.tfvars my-deployment.tfvars

# Edit with your values
vim my-deployment.tfvars
```

Required variables to configure:
- `base_domain` - Your domain (e.g., example.com)
- `oidc_issuer_url` - Your identity provider URL
- `oidc_client_id` - OIDC client ID
- `oidc_client_secret_arn` - Secrets Manager ARN for OIDC secret
- `owner` - Resource owner for tagging

### 3. Run Pre-flight Checks

```bash
# Validate AWS quotas
./modules/quota-validation/scripts/preflight-check.sh

# Validate Terraform configuration
terraform validate
```

### 4. Deploy Infrastructure

```bash
# Plan deployment
terraform plan -var-file=my-deployment.tfvars -out=tfplan

# Apply infrastructure
terraform apply tfplan
```

### 5. Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name coder-prod
```

### 6. Verify Deployment

```bash
# Check Coder pods
kubectl get pods -n coder

# Check provisioner pods
kubectl get pods -n coder-prov

# Get Coder URL
terraform output coder_access_url

# Run smoke tests
curl -s https://$(terraform output -raw coder_access_url)/healthz
```

## Day 0/1/2 Operations

### Day 0: Infrastructure Provisioning

Day 0 operations provision the foundational AWS infrastructure using Terraform AWS provider resources.

| Operation | Description | Terraform Resources |
|-----------|-------------|---------------------|
| VPC Setup | Network, subnets, NAT, endpoints | `module.vpc` |
| EKS Cluster | Control plane, node groups, IAM | `module.eks` |
| Database | Aurora PostgreSQL Serverless v2 | `module.aurora` |
| DNS | Route 53 records, ACM certificates | `module.dns` |
| Observability | CloudWatch, CloudTrail | `module.observability` |

```bash
# Day 0: Full infrastructure deployment
terraform apply -var-file=environments/prod.tfvars
```

### Day 1: Initial Configuration

Day 1 operations configure Coder itself using the coderd Terraform provider after infrastructure is deployed.

| Operation | Description | Terraform Resources |
|-----------|-------------|---------------------|
| Coder Deployment | Helm chart installation | `module.coder` |
| OIDC Setup | Authentication configuration | Helm values |
| Provisioner Setup | External provisioner deployment | `coderd_provisioner_key` |
| Group Creation | IDP group sync setup | `coderd_group` |
| Initial Templates | Deploy workspace templates | `coderd_template` |

```bash
# Day 1: Enable coderd provider after Coder is running
# Set enable_coderd_provider = true in tfvars
terraform apply -var-file=environments/prod.tfvars

# Or set via environment variable
export CODER_SESSION_TOKEN="your-admin-token"
terraform apply -var-file=environments/prod.tfvars -var="enable_coderd_provider=true"
```

### Day 2: Ongoing Management

Day 2 operations handle ongoing platform management using the coderd provider.

| Operation | Description | Terraform Resources |
|-----------|-------------|---------------------|
| Template Updates | Deploy new template versions | `coderd_template` |
| Group Management | Update IDP group mappings | `coderd_group` |
| Quota Changes | Adjust user quotas | `coderd_group.quota_allowance` |
| Provisioner Keys | Rotate keys (90-day cycle) | `coderd_provisioner_key` |
| Scaling | Adjust node group sizes | `module.eks` variables |

```bash
# Day 2: Update templates
terraform apply -var-file=environments/prod.tfvars -target=coderd_template.pod_swdev

# Day 2: Rotate provisioner key
terraform taint coderd_provisioner_key.external
terraform apply -var-file=environments/prod.tfvars
```

## Template Architecture

This deployment uses a two-layer template architecture for workspace definitions:

### Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Two-Layer Template Architecture                      │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │              Toolchain Layer (Portable)                              │    │
│  │                                                                      │    │
│  │  Declares WHAT a workspace should be:                                │    │
│  │  - Languages (Go, Python, Node.js)                                   │    │
│  │  - Tools (terraform, kubectl, docker)                                │    │
│  │  - Capabilities (persistent-home, network-egress)                    │    │
│  │                                                                      │    │
│  │  Examples: swdev-toolchain, windev-toolchain, datasci-toolchain      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │              Template Contract (Capability Interface)                │    │
│  │                                                                      │    │
│  │  Inputs:  workspace_name, owner, compute_profile, image_id          │    │
│  │  Outputs: agent_endpoint, runtime_env, volume_mounts, metadata      │    │
│  │  Capabilities: persistent-home, network-egress, identity-mode, etc. │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │              Infrastructure Base Layer (Instance-Specific)           │    │
│  │                                                                      │    │
│  │  Defines HOW workspaces run:                                         │    │
│  │  - Compute (K8s pods, EC2 instances)                                 │    │
│  │  - Networking (security groups, NetworkPolicy)                       │    │
│  │  - Storage (PVC, EBS volumes)                                        │    │
│  │  - Identity (IRSA, instance profiles)                                │    │
│  │                                                                      │    │
│  │  Examples: base-k8s, base-ec2-linux, base-ec2-windows, base-ec2-gpu  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Default Template Pairings

| Composed Template | Toolchain | Infrastructure Base | Use Case |
|-------------------|-----------|---------------------|----------|
| pod-swdev | swdev-toolchain | base-k8s | Software development (K8s pods) |
| ec2-windev-gui | windev-toolchain | base-ec2-windows | Windows development with GUI |
| ec2-datasci | datasci-toolchain | base-ec2-linux | Data science (Linux) |
| ec2-datasci-gpu | datasci-toolchain | base-ec2-gpu | ML training with GPU |

### Toolchain Templates

Located in `modules/coder/template-architecture/toolchains/`:

| Toolchain | Languages | Tools | Capabilities |
|-----------|-----------|-------|--------------|
| swdev-toolchain | Go 1.23, Node 22, Python 3.12 | terraform, kubectl, gh, docker-cli | persistent-home, outbound-https, gui-vnc (opt) |
| windev-toolchain | C#, .NET 8 | Visual Studio 2022, Git, Azure CLI | persistent-home, gui-rdp |
| datasci-toolchain | Python 3.12, R 4.x | Jupyter, CUDA toolkit, PyTorch, TensorFlow | persistent-home, outbound-https, gpu-support (opt) |

### Infrastructure Base Modules

Located in `modules/coder/template-architecture/bases/`:

| Base Module | Platform | OS Support | Key Features |
|-------------|----------|------------|--------------|
| base-k8s | Kubernetes | Amazon Linux 2023, Ubuntu 22.04/24.04 | NetworkPolicy isolation, PVC storage, IRSA |
| base-ec2-linux | EC2 | Amazon Linux 2023, Ubuntu 22.04/24.04 | EBS gp3, KasmVNC, instance profile |
| base-ec2-windows | EC2 | Windows Server 2022 | NICE DCV/WebRDP, EBS gp3 |
| base-ec2-gpu | EC2 | Amazon Linux 2023, Ubuntu 22.04 | g4dn/g5/p3/p4d, CUDA pre-installed |

### Template Contract

See `modules/coder/template-architecture/contract/` for full schema.

**Contract Inputs** (Infrastructure Base Accepts):
- `workspace_name` - Workspace name
- `owner` - Workspace owner username
- `compute_profile` - CPU, memory, storage, GPU configuration
- `image_id` - Toolchain image reference
- `capabilities` - Requested capabilities object

**Contract Outputs** (Infrastructure Base Provides):
- `agent_endpoint` - Coder agent endpoint
- `runtime_env` - Environment variables map
- `volume_mounts` - Volume mount configuration
- `metadata` - Provenance and tracking data

### Capabilities

| Capability | Type | Default | Description |
|------------|------|---------|-------------|
| persistent-home | boolean | true | Persist /home/coder across restarts |
| network-egress | enum | https-only | none, https-only, unrestricted |
| identity-mode | enum | iam | oidc, iam, workload-identity |
| gpu-support | boolean | false | Request GPU resources |
| artifact-cache | boolean | false | Enable build caching |
| secrets-injection | enum | variables | variables, vault, secrets-manager |
| gui-vnc | boolean | false | VNC desktop (Linux) |
| gui-rdp | boolean | false | RDP desktop (Windows) |

For detailed template architecture documentation, see `modules/coder/template-architecture/README.md`.



## Configuration Reference

### General Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `project_name` | Project name for resource naming | `coder` | No |
| `environment` | Environment name (prod, staging) | `prod` | No |
| `owner` | Resource owner for tagging | - | Yes |
| `aws_region` | AWS region for deployment | `us-east-1` | No |

### VPC Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `availability_zones` | List of AZs to use | `["us-east-1a", "us-east-1b", "us-east-1c"]` |
| `max_workspaces` | Max concurrent workspaces for CIDR sizing | `3000` |
| `enable_vpc_endpoints` | Enable VPC endpoints for AWS services | `true` |

### EKS Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `eks_cluster_version` | Kubernetes version | `1.31` |
| `control_node_instance_type` | Control node instance type | `m5.large` |
| `control_node_min_size` | Min control nodes | `2` |
| `control_node_max_size` | Max control nodes | `3` |
| `prov_node_instance_type` | Provisioner node instance type | `c5.2xlarge` |
| `prov_node_min_size` | Min provisioner nodes | `0` |
| `prov_node_max_size` | Max provisioner nodes | `20` |
| `prov_node_desired_peak` | Desired provisioner nodes at peak | `5` |
| `ws_node_instance_type` | Workspace node instance type | `m5.2xlarge` |
| `ws_node_min_size` | Min workspace nodes | `10` |
| `ws_node_max_size` | Max workspace nodes | `200` |
| `ws_node_desired_peak` | Desired workspace nodes at peak | `50` |
| `ws_use_spot_instances` | Use spot instances for workspaces | `true` |

### Scaling Schedule Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `scaling_schedule_start` | Cron for scale up | `45 6 * * MON-FRI` |
| `scaling_schedule_stop` | Cron for scale down | `15 18 * * MON-FRI` |
| `scaling_timezone` | Timezone for schedules | `America/New_York` |

### Aurora PostgreSQL Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aurora_engine_version` | PostgreSQL version | `16.4` |
| `aurora_min_capacity` | Min ACU capacity | `0.5` |
| `aurora_max_capacity` | Max ACU capacity | `16` |
| `aurora_backup_retention_days` | Backup retention (min 90) | `90` |
| `enable_cross_region_backup` | Enable cross-region replication | `true` |
| `backup_region` | Cross-region backup destination | `us-west-2` |

### DNS and Certificate Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `base_domain` | Base domain (Route 53 must own) | - | Yes |
| `coder_subdomain` | Subdomain for Coder | `coder` | No |
| `route53_zone_id` | Route 53 zone ID (auto-lookup if empty) | `""` | No |
| `create_acm_certificate` | Create new ACM certificate | `true` | No |
| `existing_acm_certificate_arn` | Existing ACM cert ARN | `""` | No |

### OIDC Authentication Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `oidc_issuer_url` | OIDC issuer URL | Yes |
| `oidc_client_id` | OIDC client ID | Yes |
| `oidc_client_secret_arn` | Secrets Manager ARN for OIDC secret | Yes |

### External Authentication Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `external_auth_provider` | Git provider (github, gitlab, bitbucket) | `github` |
| `external_auth_client_id` | External auth client ID | `""` |
| `external_auth_client_secret_arn` | Secrets Manager ARN for client secret | `""` |

### Coder Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `coder_version` | Helm chart version | `2.18.0` |
| `coderd_replicas` | Number of coderd replicas (static) | `2` |
| `max_workspaces_per_user` | Workspace quota per user | `3` |

### Network Load Balancer Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `nlb_ssl_policy` | TLS security policy | `ELBSecurityPolicy-TLS13-1-2-2021-06` |
| `nlb_cross_zone_enabled` | Enable cross-zone load balancing | `true` |
| `enable_stun` | Enable STUN UDP port (3478) | `true` |

### Observability Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `log_retention_days` | CloudWatch log retention (min 90) | `90` |
| `fluent_bit_version` | Fluent Bit Helm chart version | `0.47.10` |
| `enable_container_insights` | Enable CloudWatch Container Insights | `true` |
| `enable_prometheus_metrics` | Enable Prometheus metrics (port 2112) | `true` |
| `enable_amp_integration` | Enable Amazon Managed Prometheus | `false` |
| `amp_workspace_id` | AMP workspace ID (if AMP enabled) | `""` |
| `enable_cloudtrail` | Enable CloudTrail logging | `true` |
| `alert_sns_topic_arn` | SNS topic for CloudWatch alarms | `""` |
| `api_latency_p95_threshold_ms` | P95 latency alert threshold | `500` |
| `api_latency_p99_threshold_ms` | P99 latency alert threshold | `1000` |

### Quota Validation Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `skip_quota_check` | Skip quota validation (not recommended) | `false` |
| `auto_request_quota_increases` | Auto-request quota increases | `false` |

### Coderd Provider Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_coderd_provider` | Enable coderd provider (after Day 0) | `false` |
| `coder_admin_token` | Admin token (use env var instead) | `""` |
| `idp_group_mappings` | IDP group to Coder role mappings | See defaults |
| `provisioner_key_tags` | Tags for provisioner key scoping | `{scope = "organization"}` |

## Scaling

### Time-Based Scaling

Node groups scale based on work hours (default: 0645-1815 ET):

```hcl
# Scale up 15 minutes before 7 AM ET
scaling_schedule_start = "45 6 * * MON-FRI"

# Scale down 15 minutes before 6 PM ET  
scaling_schedule_stop  = "15 18 * * MON-FRI"

scaling_timezone = "America/New_York"
```

### Manual Scaling

```bash
# Adjust workspace node group
aws eks update-nodegroup-config \
  --cluster-name coder-prod \
  --nodegroup-name coder-prod-ws \
  --scaling-config minSize=20,maxSize=300,desiredSize=50

# Adjust provisioner node group
aws eks update-nodegroup-config \
  --cluster-name coder-prod \
  --nodegroup-name coder-prod-prov \
  --scaling-config minSize=2,maxSize=30,desiredSize=10
```

### Scaling via Terraform

```bash
# Update tfvars
ws_node_max_size = 300
ws_node_desired_peak = 100

# Apply changes
terraform apply -var-file=environments/prod.tfvars
```

## Troubleshooting

### Common Issues

#### Pods Stuck in Pending

```bash
# Check node group scaling
kubectl describe nodes | grep -A5 "Taints:"

# Check pending pods
kubectl get pods -A --field-selector=status.phase=Pending

# Check node group status
aws eks describe-nodegroup --cluster-name coder-prod --nodegroup-name coder-prod-ws
```

**Solutions:**
- Verify node group has capacity
- Check node taints match pod tolerations
- Verify instance type availability in region

#### Database Connection Errors

```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids sg-xxx

# Check Secrets Manager permissions
aws secretsmanager get-secret-value --secret-id coder/prod/db-password

# Check Aurora cluster status
aws rds describe-db-clusters --db-cluster-identifier coder-prod
```

**Solutions:**
- Verify security group allows 5432 from node SG
- Check IAM role has Secrets Manager access
- Verify Aurora cluster is available

#### OIDC Authentication Failures

```bash
# Check OIDC configuration
kubectl get configmap -n coder coder-config -o yaml

# Check Coder logs for auth errors
kubectl logs -n coder -l app.kubernetes.io/name=coder | grep -i oidc
```

**Solutions:**
- Verify issuer URL is correct
- Check client ID matches IDP configuration
- Verify client secret in Secrets Manager

#### Template Composition Errors

```bash
# Validate toolchain template
cd modules/coder/template-architecture/toolchains/swdev-toolchain
terraform validate

# Check contract validation
cd modules/coder/template-architecture/validation
terraform plan
```

**Solutions:**
- Verify toolchain capabilities match base module support
- Check compute profile is valid
- Verify image references are accessible

### Useful Commands

```bash
# View Coder logs
kubectl logs -n coder -l app.kubernetes.io/name=coder -f

# View provisioner logs
kubectl logs -n coder-prov -l app.kubernetes.io/name=coder-provisioner -f

# Check node group status
aws eks describe-nodegroup --cluster-name coder-prod --nodegroup-name coder-prod-ws

# Check Aurora cluster
aws rds describe-db-clusters --db-cluster-identifier coder-prod

# Check NLB health
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:...

# View CloudWatch logs
aws logs tail /aws/eks/coder-prod/cluster --follow

# Check provisioner key expiration
kubectl get secret -n coder-prov coder-provisioner-key -o jsonpath='{.metadata.annotations}'
```

### Log Locations

| Component | Log Location |
|-----------|--------------|
| Coder (coderd) | CloudWatch: `/coder/prod/coderd` |
| Provisioners | CloudWatch: `/coder/prod/provisioner` |
| Workspaces | CloudWatch: `/coder/prod/workspaces` |
| EKS Control Plane | CloudWatch: `/aws/eks/coder-prod/cluster` |
| VPC Flow Logs | CloudWatch: `/coder/prod/vpc-flow-logs` |
| CloudTrail | S3: `coder-prod-cloudtrail-logs` |

## References

### AWS Documentation

- [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Aurora PostgreSQL User Guide](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/)
- [VPC User Guide](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [Network Load Balancer Guide](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/)
- [Route 53 Developer Guide](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [EBS CSI Driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)
- [IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

### Coder Documentation

- [Coder Documentation](https://coder.com/docs)
- [Coder Helm Chart](https://github.com/coder/coder/tree/main/helm)
- [External Provisioners](https://coder.com/docs/admin/provisioners)
- [Template Development](https://coder.com/docs/templates)
- [Coder Registry](https://registry.coder.com)

### Terraform Providers

- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest)
- [Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest)
- [coderd Provider](https://registry.terraform.io/providers/coder/coderd/latest)

### Internal Documentation

**Complete documentation is now located in [`/docs/`](../docs/README.md) at the repository root.**

**Key operational guides:**
- [Day 0: Deployment](../docs/operations/day0-deployment.md) - Infrastructure deployment procedures
- [Day 1: Configuration](../docs/operations/day1-configuration.md) - Initial configuration and setup
- [Day 2: Operations](../docs/operations/day2-operations.md) - Ongoing operations and runbooks
- [RBAC Configuration](../docs/configuration/rbac.md) - Role-based access control setup
- [Authentication](../docs/configuration/authentication.md) - OIDC/SAML configuration
- [Provisioner Key Rotation](../docs/operations/provisioner-key-rotation.md) - Key lifecycle management
- [Token Management](../docs/operations/token-management.md) - Service account tokens
- [Compliance Controls](../docs/reference/compliance-controls.md) - Security controls and SoD
- [Template Architecture](modules/coder/template-architecture/README.md) - Workspace templates
- [FAQ](../docs/reference/faq.md) - Frequently asked questions
