# Base-EC2-GPU Infrastructure Module

GPU-enabled EC2-based workspace infrastructure module for Coder. This module implements the infrastructure base layer for GPU EC2 workspaces with CUDA and ML tooling pre-installed.

## Overview

This module provisions AWS EC2 GPU resources for Coder workspaces including:
- GPU EC2 instances (g4dn, g5, p3, p4d)
- AWS Deep Learning AMI with CUDA pre-installed
- EBS gp3 volume for /home/coder persistence
- IAM instance profile for AWS API access
- Security groups for workspace isolation
- Optional KasmVNC for GUI workspaces

## Requirements Covered

| Requirement | Description | Implementation |
|-------------|-------------|----------------|
| 11.5 | Deploy base-ec2-gpu module | This module |
| 11.9 | GPU instance types | g4dn, g5, p3, p4d |
| 14.7a | GPU provisioning time | Up to 5 min (not pre-warmed) |

## Supported GPU Types

| GPU Type | Instance Family | GPU | Use Case |
|----------|-----------------|-----|----------|
| nvidia-t4 | g4dn | NVIDIA T4 | Inference, light training |
| nvidia-a10g | g5 | NVIDIA A10G | Balanced training |
| nvidia-v100 | p3 | NVIDIA V100 | High performance |
| nvidia-a100 | p4d | NVIDIA A100 | Enterprise ML |

## Supported Capabilities

| Capability | Supported | Notes |
|------------|-----------|-------|
| persistent-home | ✅ | EBS gp3 volume |
| network-egress | ✅ | Security group rules |
| identity-mode | ✅ | IAM instance profile |
| gpu-support | ✅ | Required for this module |
| artifact-cache | ✅ | EFS mount or S3 |
| secrets-injection | ✅ | variables, secrets-manager |
| gui-vnc | ✅ | KasmVNC |
| gui-rdp | ❌ | Linux only |

## Usage

```hcl
module "workspace_infra" {
  source = "./modules/coder/template-architecture/bases/base-ec2-gpu"

  # Contract inputs
  workspace_name = data.coder_workspace.me.name
  owner          = data.coder_workspace_owner.me.name
  
  compute_profile = {
    cpu       = 8
    memory    = "32Gi"
    storage   = "500Gi"
    gpu_count = 1
    gpu_type  = "nvidia-t4"
  }
  
  capabilities = {
    persistent_home = true
    network_egress  = "https-only"
    identity_mode   = "iam"
    gpu_support     = true
    gui_vnc         = false
  }

  toolchain_template = {
    name    = "datasci-toolchain"
    version = "1.1.0"
  }

  # EC2-specific
  vpc_id                  = var.vpc_id
  subnet_id               = var.subnet_id
  availability_zone       = var.availability_zone
  instance_profile_name   = var.instance_profile_name
  coder_agent_init_script = coder_agent.main.init_script
}
```

## Instance Type Selection

The module automatically selects the appropriate instance type based on:
- `gpu_type`: Determines the instance family (g4dn, g5, p3, p4d)
- `gpu_count`: Determines the instance size within the family

| GPU Type | GPU Count | Instance Type |
|----------|-----------|---------------|
| nvidia-t4 | 1 | g4dn.xlarge |
| nvidia-t4 | 4 | g4dn.12xlarge |
| nvidia-a10g | 1 | g5.xlarge |
| nvidia-a10g | 4 | g5.12xlarge |
| nvidia-v100 | 1 | p3.2xlarge |
| nvidia-v100 | 4 | p3.8xlarge |
| nvidia-v100 | 8 | p3.16xlarge |
| nvidia-a100 | 8 | p4d.24xlarge |

## Provisioning Time

**Important**: GPU instances are not pre-warmed. Provisioning may take up to 5 minutes depending on:
- GPU availability in the selected AZ
- Instance type demand
- AMI size

## Pre-installed Software

The AWS Deep Learning AMI includes:
- CUDA drivers and toolkit
- cuDNN
- PyTorch
- TensorFlow
- Conda environment
- Jupyter Lab

## Inputs

### Contract Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| workspace_name | string | yes | Workspace name |
| owner | string | yes | Workspace owner username |
| compute_profile | object | yes | CPU, memory, storage, GPU allocation |
| image_id | string | no | AMI ID (defaults to Deep Learning AMI) |
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

## Outputs

### Contract Outputs

| Name | Type | Description |
|------|------|-------------|
| agent_endpoint | string | Instance private IP |
| runtime_env | map(string) | Environment variables |
| volume_mounts | list(object) | Volume mount configuration |
| metadata | object | Provenance and tracking data |

### GPU-Specific Outputs

| Name | Type | Description |
|------|------|-------------|
| instance_id | string | EC2 instance ID |
| instance_type | string | EC2 instance type |
| gpu_type | string | GPU type |
| gpu_count | number | Number of GPUs |

## Security

- Encrypted EBS volumes (gp3)
- Security groups enforce network isolation
- IAM instance profile with least-privilege
- No SSH access by default (Coder agent only)
