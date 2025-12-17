# Base-EC2-Linux Infrastructure Module

Linux EC2-based workspace infrastructure module for Coder. This module implements the infrastructure base layer for Linux EC2 workspaces.

## Overview

This module provisions AWS EC2 resources for Coder workspaces including:
- EC2 instance with configurable compute resources
- EBS gp3 volume for /home/coder persistence
- IAM instance profile for AWS API access
- Security groups for workspace isolation
- Optional KasmVNC for GUI workspaces

## Requirements Covered

| Requirement | Description | Implementation |
|-------------|-------------|----------------|
| 11.5 | Deploy base-ec2-linux module | This module |
| 11.6 | KasmVNC for GUI workspaces | gui_vnc capability |
| 11.7 | Headless workspaces | Default mode |
| 11.8 | OS options | amazon-linux-2023, ubuntu-22.04/24.04 |
| 11a.1 | Persist /home/coder | EBS gp3 volume |

## Supported Capabilities

| Capability | Supported | Notes |
|------------|-----------|-------|
| persistent-home | ✅ | EBS gp3 volume |
| network-egress | ✅ | Security group rules |
| identity-mode | ✅ | IAM instance profile |
| gpu-support | ❌ | Use base-ec2-gpu module |
| artifact-cache | ✅ | EFS mount or S3 |
| secrets-injection | ✅ | variables, secrets-manager |
| gui-vnc | ✅ | KasmVNC |
| gui-rdp | ❌ | Use base-ec2-windows module |

## Usage

```hcl
module "workspace_infra" {
  source = "./modules/coder/template-architecture/bases/base-ec2-linux"

  # Contract inputs
  workspace_name = data.coder_workspace.me.name
  owner          = data.coder_workspace_owner.me.name
  
  compute_profile = {
    cpu     = 4
    memory  = "8Gi"
    storage = "50Gi"
  }
  
  capabilities = {
    persistent_home = true
    network_egress  = "https-only"
    identity_mode   = "iam"
    gui_vnc         = false
  }

  toolchain_template = {
    name    = "swdev-toolchain"
    version = "1.2.0"
  }

  # EC2-specific
  vpc_id                  = var.vpc_id
  subnet_id               = var.subnet_id
  availability_zone       = var.availability_zone
  instance_profile_name   = var.instance_profile_name
  coder_agent_init_script = coder_agent.main.init_script
}
```

## Inputs

### Contract Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| workspace_name | string | yes | Workspace name |
| owner | string | yes | Workspace owner username |
| compute_profile | object | yes | CPU, memory, storage allocation |
| image_id | string | no | AMI ID (defaults to OS-based) |
| capabilities | object | no | Requested capabilities |
| toolchain_template | object | yes | Toolchain template info |

### EC2-Specific Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| vpc_id | string | required | VPC ID |
| subnet_id | string | required | Subnet ID |
| availability_zone | string | required | AZ for EBS volumes |
| instance_profile_name | string | required | IAM instance profile |
| os_type | string | "ubuntu-22.04" | Operating system |
| kms_key_id | string | null | KMS key for encryption |

## Outputs

### Contract Outputs

| Name | Type | Description |
|------|------|-------------|
| agent_endpoint | string | Instance private IP |
| runtime_env | map(string) | Environment variables |
| volume_mounts | list(object) | Volume mount configuration |
| metadata | object | Provenance and tracking data |

### EC2-Specific Outputs

| Name | Type | Description |
|------|------|-------------|
| instance_id | string | EC2 instance ID |
| instance_type | string | EC2 instance type |
| private_ip | string | Private IP address |
| security_group_id | string | Security group ID |
| ebs_volume_id | string | EBS volume ID |

## Security

- Encrypted EBS volumes (gp3)
- Security groups enforce network isolation
- IAM instance profile with least-privilege
- No SSH access by default (Coder agent only)
