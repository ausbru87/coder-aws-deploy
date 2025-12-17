# EC2-based Windows Development Workspace Template

This template creates an EC2-based Windows Server 2022 workspace for Windows development.

## Features

- **OS**: Windows Server 2022
- **Remote Desktop**: NICE DCV (recommended) or WebRDP
- **Pre-installed**: Visual Studio, Git, common dev tools
- **Auto-start/Auto-stop**: Configured for 0700/1800 ET
- **Encrypted Storage**: EBS volumes with encryption enabled

## T-Shirt Sizes

| Size | Instance Type | vCPU | RAM | Storage | Use Case |
|------|---------------|------|-----|---------|----------|
| SW Dev Medium | m5.xlarge | 4 | 16GB | 50GB | Standard Windows development |
| SW Dev Large | m5.2xlarge | 8 | 32GB | 100GB | Heavy Windows development |

## Remote Desktop Options

### NICE DCV (Recommended)
- High-performance remote desktop protocol
- GPU acceleration support
- Low latency streaming
- Native Windows integration

### WebRDP
- Browser-based RDP access via Apache Guacamole
- No client software required
- Works through firewalls

## Requirements Covered

- **11.4**: Initial templates include ec2-windev-gui
- **11.5**: GUI support via DCV or WebRDP
- **11.6**: Support Windows operating system

## Usage

1. Push this template to Coder:
   ```bash
   coder templates push ec2-windev-gui --directory ./templates/ec2-windev-gui
   ```

2. Configure auto-start/auto-stop schedule in Coder admin settings

3. Users can create workspaces from this template via the Coder UI

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `vpc_id` | VPC ID for the workspace | Required |
| `subnet_id` | Subnet ID for the workspace | Required |
| `instance_profile_name` | IAM instance profile name | Required |
| `default_region` | Default AWS region | `us-east-1` |

## Security

- Security group allows only outbound HTTPS/HTTP and DNS
- EBS volumes are encrypted at rest
- IAM instance profile provides least-privilege access
- Workspace is isolated in private subnet

## Pre-installed Software

The Windows AMI includes:
- Visual Studio 2022 (Community/Professional based on license)
- Git for Windows
- Windows Terminal
- PowerShell 7
- .NET SDK
- Node.js LTS
- Python 3.x
