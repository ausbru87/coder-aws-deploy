# Base-EC2-Windows Infrastructure Module

Windows EC2-based workspace infrastructure module for Coder. This module implements the infrastructure base layer for Windows EC2 workspaces with NICE DCV or WebRDP access.

## Overview

This module provisions AWS EC2 resources for Windows Coder workspaces including:
- Windows Server 2022 EC2 instance
- NICE DCV (recommended) or WebRDP for remote desktop access
- EBS gp3 volume for user data persistence
- IAM instance profile for AWS API access
- Security groups for workspace isolation

## Requirements Covered

| Requirement | Description | Implementation |
|-------------|-------------|----------------|
| 11.5 | Deploy base-ec2-windows module | This module |
| 11.6 | NICE DCV or WebRDP | remote_desktop_type variable |
| 11.7 | Windows Server 2022 | Hardened AMI |

## Supported Capabilities

| Capability | Supported | Notes |
|------------|-----------|-------|
| persistent-home | ✅ | EBS gp3 volume (D: drive) |
| network-egress | ✅ | Security group rules |
| identity-mode | ✅ | IAM instance profile |
| gpu-support | ❌ | Not supported on Windows |
| artifact-cache | ❌ | Not supported |
| secrets-injection | ✅ | variables, secrets-manager |
| gui-vnc | ❌ | Use gui-rdp instead |
| gui-rdp | ✅ | NICE DCV or WebRDP |

## Usage

```hcl
module "workspace_infra" {
  source = "./modules/coder/template-architecture/bases/base-ec2-windows"

  # Contract inputs
  workspace_name = data.coder_workspace.me.name
  owner          = data.coder_workspace_owner.me.name
  
  compute_profile = {
    cpu     = 4
    memory  = "16Gi"
    storage = "100Gi"
  }
  
  capabilities = {
    persistent_home = true
    network_egress  = "https-only"
    identity_mode   = "iam"
    gui_rdp         = true
  }

  toolchain_template = {
    name    = "windev-toolchain"
    version = "1.0.0"
  }

  # EC2-specific
  vpc_id                  = var.vpc_id
  subnet_id               = var.subnet_id
  availability_zone       = var.availability_zone
  instance_profile_name   = var.instance_profile_name
  remote_desktop_type     = "dcv"
  coder_agent_init_script = coder_agent.main.init_script
}
```

## Remote Desktop Options

### NICE DCV (Recommended)
- High-performance remote desktop with GPU acceleration
- Low latency streaming
- Supports USB device redirection
- Automatic session management

### WebRDP
- Browser-based RDP access via Apache Guacamole
- No client software required
- Standard RDP protocol

## Inputs

### Contract Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| workspace_name | string | yes | Workspace name |
| owner | string | yes | Workspace owner username |
| compute_profile | object | yes | CPU, memory, storage allocation |
| image_id | string | no | AMI ID (defaults to Windows Server 2022) |
| capabilities | object | no | Requested capabilities |
| toolchain_template | object | yes | Toolchain template info |

### EC2-Specific Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| vpc_id | string | required | VPC ID |
| subnet_id | string | required | Subnet ID |
| availability_zone | string | required | AZ for EBS volumes |
| instance_profile_name | string | required | IAM instance profile |
| remote_desktop_type | string | "dcv" | dcv or webrdp |
| windows_password | string | sensitive | Windows user password |

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
| remote_desktop_type | string | Remote desktop protocol |

## Security

- Encrypted EBS volumes (gp3)
- Security groups enforce network isolation
- IAM instance profile with least-privilege
- Windows Firewall configured
- NICE DCV with TLS encryption
