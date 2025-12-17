# Software Development Toolchain Template

A portable toolchain template for general-purpose software development workspaces.

## Overview

This toolchain provides a complete software development environment with:
- **Languages**: Go 1.23, Node.js 22, Python 3.12
- **Tools**: Terraform, kubectl, GitHub CLI, Docker CLI, and more
- **Capabilities**: Persistent home directory, HTTPS egress, optional GUI

## Requirements Covered

| Requirement | Description |
|-------------|-------------|
| 11.4 | Software development toolchain template |
| 11c.2 | Toolchain declares capabilities without infrastructure details |
| 11c.3 | Toolchain manifest with tools, versions, capabilities |
| 11c.4 | Define capabilities (compute, network, storage) |
| 11f.1 | Portable template without infrastructure-specific details |
| 11f.2 | Declare required capabilities and dependencies |

## Compute Profiles

| Profile | vCPU | Memory | Storage | Use Case |
|---------|------|--------|---------|----------|
| sw-dev-small | 2 | 4Gi | 20Gi | Light development |
| sw-dev-medium | 4 | 8Gi | 50Gi | Standard development (default) |
| sw-dev-large | 8 | 16Gi | 100Gi | Heavy development |
| platform-devsecops | 4 | 8Gi | 100Gi | Platform/DevSecOps work |

## Capabilities

### Required
- `persistent-home`: Persist /home/coder across workspace restarts
- `outbound-https`: HTTPS egress for package downloads and Git operations

### Optional
- `gui-vnc`: VNC-based desktop environment (enable with `enable_gui = true`)

## Usage

### Basic Usage

```hcl
module "toolchain" {
  source = "git::https://github.com/org/toolchain-templates.git//swdev-toolchain?ref=v1.0.0"
  
  compute_profile = "sw-dev-medium"
}
```

### With GUI Enabled

```hcl
module "toolchain" {
  source = "git::https://github.com/org/toolchain-templates.git//swdev-toolchain?ref=v1.0.0"
  
  compute_profile = "sw-dev-large"
  enable_gui      = true
}
```

### With Optional Tools

```hcl
module "toolchain" {
  source = "git::https://github.com/org/toolchain-templates.git//swdev-toolchain?ref=v1.0.0"
  
  compute_profile  = "platform-devsecops"
  install_aws_cli  = true
  install_helm     = true
  install_k9s      = true
}
```

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `compute_profile` | string | `sw-dev-medium` | T-shirt size for compute resources |
| `enable_gui` | bool | `false` | Enable VNC desktop environment |
| `enable_docker` | bool | `true` | Enable Docker CLI |
| `install_aws_cli` | bool | `true` | Install AWS CLI v2 |
| `install_helm` | bool | `true` | Install Helm |
| `install_k9s` | bool | `false` | Install k9s TUI |
| `additional_packages` | list(string) | `[]` | Additional packages to install |
| `custom_startup_script` | string | `""` | Custom startup script |

## Outputs

| Output | Description |
|--------|-------------|
| `name` | Toolchain template name |
| `version` | Toolchain template version |
| `capabilities` | Capability declarations for infrastructure base |
| `compute_profile` | Resolved compute resources |
| `bootstrap_script` | Workspace initialization script |
| `environment_variables` | Environment variables to set |
| `languages` | Installed programming languages |
| `tools` | Installed development tools |
| `image_id` | Container image reference |
| `health_checks` | Validation commands |

## Composition Example

```hcl
# 1. Source the toolchain
module "toolchain" {
  source = "git::https://github.com/org/toolchain-templates.git//swdev-toolchain?ref=v1.0.0"
  
  compute_profile = "sw-dev-medium"
}

# 2. Validate composition
module "validation" {
  source = "./modules/coder/template-architecture/validation"
  
  toolchain_capabilities = module.toolchain.capabilities
  base_platform          = "kubernetes"
}

# 3. Source infrastructure base
module "infra" {
  source = "./modules/coder/template-architecture/bases/base-k8s"
  
  workspace_name  = data.coder_workspace.me.name
  owner           = data.coder_workspace_owner.me.name
  compute_profile = module.toolchain.compute_profile
  image_id        = module.toolchain.image_id
  capabilities    = module.toolchain.capabilities
  
  toolchain_template = {
    name    = module.toolchain.name
    version = module.toolchain.version
  }
  base_module = {
    name    = "base-k8s"
    version = "1.0.0"
  }
  
  depends_on = [module.validation]
}

# 4. Configure Coder agent
resource "coder_agent" "main" {
  os   = module.infra.metadata.os
  arch = module.infra.metadata.arch
  
  startup_script = module.toolchain.bootstrap_script
  env            = module.infra.runtime_env
}
```

## Supported Platforms

This toolchain can be composed with the following infrastructure bases:
- `base-k8s`: Kubernetes pod workspaces
- `base-ec2-linux`: Linux EC2 workspaces

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2024-12 | Initial release |

## Maintainer

Platform Team - platform-team@example.com
