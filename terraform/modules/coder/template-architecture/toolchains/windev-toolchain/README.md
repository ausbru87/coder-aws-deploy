# Windows Development Toolchain Template

A portable toolchain template for Windows and .NET development workspaces.

## Overview

This toolchain provides a complete Windows development environment with:
- **Languages**: C# 12, .NET 8, PowerShell 7
- **Tools**: Visual Studio 2022, Azure CLI, Git, NuGet
- **Capabilities**: Persistent home directory, RDP desktop access

## Requirements Covered

| Requirement | Description |
|-------------|-------------|
| 11.4 | Windows development toolchain template |
| 11c.2 | Toolchain declares capabilities without infrastructure details |
| 11c.3 | Toolchain manifest with tools, versions, capabilities |
| 11c.4 | Define capabilities (compute, network, storage) |

## Compute Profiles

| Profile | vCPU | Memory | Storage | Use Case |
|---------|------|--------|---------|----------|
| sw-dev-medium | 4 | 8Gi | 50Gi | Standard Windows development (default) |
| sw-dev-large | 8 | 16Gi | 100Gi | Large solutions, heavy builds |

## Capabilities

### Required
- `persistent-home`: Persist user profile data across workspace restarts
- `gui-rdp`: RDP-based remote desktop for Visual Studio GUI

### Network
- `network-egress`: HTTPS-only (for NuGet, Azure, Git operations)

## Usage

### Basic Usage

```hcl
module "toolchain" {
  source = "git::https://github.com/org/toolchain-templates.git//windev-toolchain?ref=v1.0.0"
  
  compute_profile = "sw-dev-medium"
}
```

### With Additional Tools

```hcl
module "toolchain" {
  source = "git::https://github.com/org/toolchain-templates.git//windev-toolchain?ref=v1.0.0"
  
  compute_profile           = "sw-dev-large"
  vs_edition                = "Enterprise"
  install_ssms              = true
  install_azure_data_studio = true
}
```

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `compute_profile` | string | `sw-dev-medium` | T-shirt size for compute resources |
| `vs_edition` | string | `Professional` | Visual Studio edition |
| `vs_workloads` | list(string) | See defaults | VS workloads to install |
| `install_ssms` | bool | `false` | Install SQL Server Management Studio |
| `install_azure_data_studio` | bool | `false` | Install Azure Data Studio |
| `install_postman` | bool | `false` | Install Postman |
| `install_docker_desktop` | bool | `false` | Install Docker Desktop |
| `additional_packages` | list(string) | `[]` | Additional Chocolatey packages |
| `custom_startup_script` | string | `""` | Custom PowerShell startup script |

## Outputs

| Output | Description |
|--------|-------------|
| `name` | Toolchain template name |
| `version` | Toolchain template version |
| `capabilities` | Capability declarations for infrastructure base |
| `compute_profile` | Resolved compute resources |
| `bootstrap_script` | Workspace initialization script (PowerShell) |
| `environment_variables` | Environment variables to set |
| `languages` | Installed programming languages |
| `tools` | Installed development tools |
| `vs_config` | Visual Studio configuration |
| `health_checks` | Validation commands |

## Composition Example

```hcl
# 1. Source the toolchain
module "toolchain" {
  source = "git::https://github.com/org/toolchain-templates.git//windev-toolchain?ref=v1.0.0"
  
  compute_profile = "sw-dev-medium"
}

# 2. Validate composition
module "validation" {
  source = "./modules/coder/template-architecture/validation"
  
  toolchain_capabilities = module.toolchain.capabilities
  base_platform          = "ec2-windows"
}

# 3. Source infrastructure base
module "infra" {
  source = "./modules/coder/template-architecture/bases/base-ec2-windows"
  
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
    name    = "base-ec2-windows"
    version = "1.0.0"
  }
  
  depends_on = [module.validation]
}

# 4. Configure Coder agent
resource "coder_agent" "main" {
  os   = "windows"
  arch = "amd64"
  
  startup_script = module.toolchain.bootstrap_script
  env            = module.infra.runtime_env
}
```

## Supported Platforms

This toolchain can only be composed with:
- `base-ec2-windows`: Windows EC2 workspaces

Note: Windows workspaces are not supported on Kubernetes pods.

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2024-12 | Initial release |

## Maintainer

Platform Team - platform-team@example.com
