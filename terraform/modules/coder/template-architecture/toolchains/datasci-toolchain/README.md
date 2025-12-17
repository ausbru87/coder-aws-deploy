# Data Science Toolchain Template

A portable toolchain template for data science and machine learning workspaces.

## Overview

This toolchain provides a complete data science environment with:
- **Languages**: Python 3.12, R 4.x (optional)
- **Tools**: Jupyter Lab, CUDA toolkit (optional), DVC, MLflow
- **Libraries**: PyTorch, TensorFlow, scikit-learn, pandas, and more
- **Capabilities**: Persistent storage, HTTPS egress, optional GPU support

## Requirements Covered

| Requirement | Description |
|-------------|-------------|
| 11.4 | Data science toolchain template |
| 11.9 | GPU instance types and pre-installed ML tooling |
| 11c.2 | Toolchain declares capabilities without infrastructure details |
| 11c.3 | Toolchain manifest with tools, versions, capabilities |
| 11c.4 | Define capabilities (compute, network, storage) |

## Compute Profiles

| Profile | vCPU | Memory | Storage | GPU | Use Case |
|---------|------|--------|---------|-----|----------|
| datasci-standard | 8 | 32Gi | 500Gi | None | Data analysis (default) |
| datasci-large | 16 | 64Gi | 1Ti | 1x T4 | ML training |
| datasci-xlarge | 32 | 64Gi | 2Ti | 4x A100 | Large-scale ML |

## Capabilities

### Required
- `persistent-home`: Persist /home/coder, datasets, and models across restarts
- `outbound-https`: HTTPS egress for package downloads, model downloads

### Optional
- `gpu-support`: GPU acceleration for ML training (enable with `enable_gpu = true`)
- `gui-vnc`: VNC desktop for visualization tools (enable with `enable_gui = true`)

## Usage

### Basic Usage (CPU-only)

```hcl
module "toolchain" {
  source = "git::https://github.com/org/toolchain-templates.git//datasci-toolchain?ref=v1.0.0"
  
  compute_profile = "datasci-standard"
}
```

### With GPU Support

```hcl
module "toolchain" {
  source = "git::https://github.com/org/toolchain-templates.git//datasci-toolchain?ref=v1.0.0"
  
  compute_profile = "datasci-large"
  enable_gpu      = true
  gpu_type        = "nvidia-t4"
}
```

### Large-Scale ML Training

```hcl
module "toolchain" {
  source = "git::https://github.com/org/toolchain-templates.git//datasci-toolchain?ref=v1.0.0"
  
  compute_profile = "datasci-xlarge"
  enable_gpu      = true
  gpu_type        = "nvidia-a100"
  install_ray     = true  # Distributed computing
}
```

### With R Support

```hcl
module "toolchain" {
  source = "git::https://github.com/org/toolchain-templates.git//datasci-toolchain?ref=v1.0.0"
  
  compute_profile = "datasci-standard"
  install_r       = true
}
```

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `compute_profile` | string | `datasci-standard` | T-shirt size for compute resources |
| `enable_gpu` | bool | `false` | Enable GPU support |
| `gpu_type` | string | `nvidia-t4` | GPU type (t4, a10g, v100, a100) |
| `enable_gui` | bool | `false` | Enable VNC desktop |
| `install_pytorch` | bool | `true` | Install PyTorch |
| `install_tensorflow` | bool | `true` | Install TensorFlow |
| `install_r` | bool | `false` | Install R and packages |
| `install_tensorboard` | bool | `true` | Install TensorBoard |
| `install_mlflow` | bool | `true` | Install MLflow |
| `install_dvc` | bool | `true` | Install DVC |
| `install_wandb` | bool | `false` | Install Weights & Biases |
| `install_ray` | bool | `false` | Install Ray |
| `additional_pip_packages` | list(string) | `[]` | Additional pip packages |
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
| `libraries` | Installed ML libraries |
| `gpu_config` | GPU configuration |
| `health_checks` | Validation commands |

## Composition Example

```hcl
# 1. Source the toolchain
module "toolchain" {
  source = "git::https://github.com/org/toolchain-templates.git//datasci-toolchain?ref=v1.0.0"
  
  compute_profile = "datasci-large"
  enable_gpu      = true
}

# 2. Validate composition
module "validation" {
  source = "./modules/coder/template-architecture/validation"
  
  toolchain_capabilities = module.toolchain.capabilities
  base_platform          = "ec2-gpu"
}

# 3. Source infrastructure base
module "infra" {
  source = "./modules/coder/template-architecture/bases/base-ec2-gpu"
  
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
    name    = "base-ec2-gpu"
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

This toolchain can be composed with:
- `base-k8s`: Kubernetes pod workspaces (CPU-only)
- `base-ec2-linux`: Linux EC2 workspaces (CPU-only)
- `base-ec2-gpu`: GPU EC2 workspaces (GPU support)

Note: GPU workspaces require `base-ec2-gpu` infrastructure base.

## GPU Instance Types

| GPU Type | AWS Instance | Use Case |
|----------|--------------|----------|
| nvidia-t4 | g4dn.* | Inference, light training |
| nvidia-a10g | g5.* | Training, inference |
| nvidia-v100 | p3.* | Training |
| nvidia-a100 | p4d.* | Large-scale training |

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2024-12 | Initial release |

## Maintainer

Platform Team - platform-team@example.com
