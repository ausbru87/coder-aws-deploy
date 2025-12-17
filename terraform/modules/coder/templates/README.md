# Coder Workspace Templates

This directory contains Coder workspace templates for the enterprise deployment.

## Templates

| Template | Platform | Description | T-Shirt Sizes |
|----------|----------|-------------|---------------|
| `pod-swdev` | EKS Pod | Software development workspace | SW Dev S/M/L, Platform/DevSecOps |
| `ec2-windev-gui` | EC2 | Windows development with GUI | SW Dev M/L |
| `ec2-datasci` | EC2 | Data science with GPU support | Data Sci Standard/Large/XLarge |

## Template Features

### pod-swdev
- Base OS: Ubuntu 22.04/24.04, Amazon Linux 2023
- GUI: Optional KasmVNC desktop
- Headless: SSH/VS Code Remote
- Persistence: /home/coder via EBS PVC
- Network isolation via NetworkPolicy

### ec2-windev-gui
- OS: Windows Server 2022
- Remote Desktop: NICE DCV (recommended) or WebRDP
- Pre-installed: Visual Studio, Git, dev tools

### ec2-datasci
- OS: Ubuntu 22.04 (CUDA), Amazon Linux 2023 (CUDA)
- GPU: g4dn (T4), g5 (A10G), p3 (V100), p4d (A100)
- Pre-installed: Jupyter Lab, PyTorch, TensorFlow, CUDA

## Deployment

Templates are deployed via the coderd Terraform provider. See `templates.tf` in the parent directory.

### Manual Deployment

```bash
# Push a template manually
coder templates push pod-swdev --directory ./templates/pod-swdev

# List templates
coder templates list

# View template versions
coder templates versions pod-swdev
```

### Terraform Deployment

Templates are managed declaratively via Terraform when `enable_template_management = true`:

```hcl
module "coder" {
  source = "./modules/coder"
  
  enable_coderd_provider     = true
  enable_template_management = true
  template_version           = "1.0.0"
  
  # ... other variables
}
```

## Requirements Covered

- **11.3**: Support both EC2-based and EKS pod-based workspaces
- **11.4**: Initial templates (pod-swdev, ec2-windev-gui, ec2-datasci)
- **11.5**: GUI support (KasmVNC, DCV, WebRDP)
- **11.6**: OS support (Windows, Amazon Linux, Ubuntu)
- **11.7**: Headless Linux workspaces
- **11.8**: GPU instance types and ML tooling
- **11a.1**: /home/coder persistence
- **3.1c**: NetworkPolicy for workspace isolation
- **12b.3**: Template access permissions via ACL
- **12g.5**: Git CLI pre-configured
- **13.1-13.3**: Auto-start/auto-stop
- **14.7a**: GPU provisioning up to 5 min
- **14.16**: T-shirt sized configurations
- **16.3**: Declarative template management

## Template Governance

Templates follow the governance workflow defined in Requirements 11b.1-11b.5:

1. Templates stored in Git (this directory)
2. Changes reviewed via pull request
3. CI/CD validates and tests templates
4. Platform owner and security approve changes
5. Terraform applies template updates

## Access Control

Template access is controlled via `coderd_template_acl` resources:

- **pod-swdev**: All developers, platform admins
- **ec2-windev-gui**: Developers who need Windows
- **ec2-datasci**: Data science team only (Requirement 14.17)

## Auto-Stop Configuration

All templates have auto-stop enabled by default (Requirements 5.9, 13.1, 13.2):

- Default TTL: 8 hours
- Activity bump: 1 hour
- Auto-stop days: Monday-Friday
- Dormant after: 7 days
- Auto-delete dormant: 30 days
