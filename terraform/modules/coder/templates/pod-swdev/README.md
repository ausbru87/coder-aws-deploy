# Pod-based Software Development Workspace Template

This template creates a Kubernetes pod-based workspace for software development.

## Features

- **Base OS Options**: Ubuntu 22.04 LTS, Ubuntu 24.04 LTS, Amazon Linux 2023
- **GUI Option**: KasmVNC for browser-based desktop access
- **Headless Option**: SSH and VS Code Remote access
- **Persistent Storage**: /home/coder persisted via EBS-backed PVC
- **Git Integration**: Pre-configured with Coder external auth
- **Network Isolation**: NetworkPolicy for workspace isolation
- **Auto-start/Auto-stop**: Configured for 0700/1800 ET

## T-Shirt Sizes

| Size | vCPU | RAM | Storage | Use Case |
|------|------|-----|---------|----------|
| SW Dev Small | 2 | 4GB | 20GB | Light development |
| SW Dev Medium | 4 | 8GB | 50GB | Standard development |
| SW Dev Large | 8 | 16GB | 100GB | Heavy development |
| Platform/DevSecOps | 4 | 8GB | 100GB | Infrastructure work |

## Requirements Covered

- **11.3**: Support both EC2-based and EKS pod-based workspaces
- **11.4**: Initial templates include pod-swdev
- **11.5**: GUI support via KasmVNC
- **11.6**: Support Windows, Amazon Linux, Ubuntu OS
- **11.7**: Headless Linux workspaces on Amazon Linux and Ubuntu
- **11a.1**: Persist /home/coder directory
- **3.1c**: NetworkPolicy for workspace isolation
- **12g.5**: Git CLI pre-configured with external auth
- **13.1**: Auto-start/auto-stop enabled
- **13.2**: Auto-stop at 1800 ET
- **13.3**: Auto-start at 0700 ET

## Usage

1. Push this template to Coder:
   ```bash
   coder templates push pod-swdev --directory ./templates/pod-swdev
   ```

2. Configure auto-start/auto-stop schedule in Coder admin settings

3. Users can create workspaces from this template via the Coder UI

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `namespace` | Kubernetes namespace for workspaces | `coder-ws` |
| `storage_class` | Storage class for PVCs | `gp3-encrypted` |

## Network Policy

The template includes a NetworkPolicy that:
- Allows ingress only from the Coder control plane namespace
- Allows egress to DNS (UDP/TCP 53)
- Allows egress to the Coder control plane
- Allows egress to HTTP/HTTPS (ports 80/443) for Git and package managers
- Blocks direct communication between workspaces
