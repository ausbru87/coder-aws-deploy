# Template Contract Schema

This directory contains the contract schema definition that governs the interface between toolchain templates (portable layer) and infrastructure base modules (instance-specific layer).

## Overview

The template contract defines:
- **Inputs**: What infrastructure base modules must accept
- **Outputs**: What infrastructure base modules must provide
- **Capabilities**: Features that toolchain templates can request

## Files

| File | Purpose |
|------|---------|
| `contract-schema.yaml` | Complete contract schema in YAML format |
| `capabilities.yaml` | Capability definitions and compute profiles |
| `variables.tf` | Terraform variable definitions for contract inputs |
| `outputs.tf` | Terraform output definitions for contract outputs |

## Contract Version

Current version: **1.0**

Breaking changes to the contract require a major version bump (e.g., 1.0 → 2.0).

## Contract Inputs

Infrastructure base modules MUST accept these inputs:

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `workspace_name` | string | Yes | Name of the workspace |
| `owner` | string | Yes | Username of workspace owner |
| `compute_profile` | object | Yes | CPU, memory, storage, GPU configuration |
| `image_id` | string | Yes | Toolchain image reference |
| `capabilities` | object | No | Requested capabilities |
| `toolchain_template` | object | Yes | Toolchain template metadata |
| `base_module` | object | Yes | Infrastructure base metadata |
| `overrides` | object | No | Controlled overrides |

### Compute Profile Structure

```hcl
compute_profile = {
  cpu       = 4           # vCPUs (1-64)
  memory    = "8Gi"       # Memory allocation
  storage   = "100Gi"     # Storage allocation
  gpu_count = 0           # GPU count (0-8)
  gpu_type  = null        # nvidia-t4, nvidia-a10g, nvidia-v100, nvidia-a100
}
```

### Capabilities Structure

```hcl
capabilities = {
  persistent_home   = true          # Persist /home/coder
  network_egress    = "https-only"  # none, https-only, unrestricted
  identity_mode     = "iam"         # oidc, iam, workload-identity
  gpu_support       = false         # Request GPU resources
  artifact_cache    = false         # Enable build caching
  secrets_injection = "variables"   # variables, vault, secrets-manager
  gui_vnc           = false         # KasmVNC desktop
  gui_rdp           = false         # Windows RDP
}
```

## Contract Outputs

Infrastructure base modules MUST provide these outputs:

| Output | Type | Description |
|--------|------|-------------|
| `agent_endpoint` | string | Coder agent connection endpoint |
| `runtime_env` | map(string) | Environment variables for workspace |
| `volume_mounts` | list(object) | Configured volume mounts |
| `metadata` | object | Provenance and tracking metadata |

### Metadata Structure

```hcl
metadata = {
  platform          = "kubernetes"  # kubernetes, ec2-linux, ec2-windows, ec2-gpu
  os                = "linux"       # linux, windows
  arch              = "amd64"       # amd64, arm64
  toolchain_version = "1.2.0"       # Toolchain template version
  base_version      = "3.1.0"       # Infrastructure base version
  image_digest      = "sha256:..."  # Container image digest (if applicable)
  ami_id            = "ami-..."     # AMI ID (if applicable)
  provisioned_at    = "2024-..."    # ISO 8601 timestamp
}
```

## Capabilities

### Core Capabilities

| Capability | Type | Default | Description |
|------------|------|---------|-------------|
| `persistent-home` | bool | true | Persist /home/coder directory |
| `network-egress` | enum | https-only | Outbound network policy |
| `identity-mode` | enum | iam | Cloud authentication method |
| `gpu-support` | bool | false | GPU resource allocation |
| `artifact-cache` | bool | false | Build artifact caching |
| `secrets-injection` | enum | variables | Secret delivery mechanism |
| `gui-vnc` | bool | false | VNC desktop (Linux) |
| `gui-rdp` | bool | false | RDP desktop (Windows) |

### Compute Profiles (T-Shirt Sizes)

| Profile | CPU | Memory | Storage | GPU | Use Case |
|---------|-----|--------|---------|-----|----------|
| `sw-dev-small` | 2 | 4Gi | 20Gi | 0 | Light development |
| `sw-dev-medium` | 4 | 8Gi | 50Gi | 0 | Standard development |
| `sw-dev-large` | 8 | 16Gi | 100Gi | 0 | Heavy development |
| `platform-devsecops` | 4 | 8Gi | 100Gi | 0 | Platform engineering |
| `datasci-standard` | 8 | 32Gi | 500Gi | 0 | Data analysis |
| `datasci-large` | 16 | 64Gi | 1Ti | 1 | ML training |
| `datasci-xlarge` | 32 | 64Gi | 2Ti | 4 | Large-scale ML |

### Platform Capability Support

| Capability | Kubernetes | EC2 Linux | EC2 Windows | EC2 GPU |
|------------|------------|-----------|-------------|---------|
| persistent-home | ✅ | ✅ | ✅ | ✅ |
| network-egress | ✅ | ✅ | ✅ | ✅ |
| identity-mode | ✅ | ✅ | ✅ | ✅ |
| gpu-support | ❌ | ❌ | ❌ | ✅ |
| artifact-cache | ✅ | ✅ | ❌ | ✅ |
| secrets-injection | ✅ | ✅ | ✅ | ✅ |
| gui-vnc | ✅ | ✅ | ❌ | ✅ |
| gui-rdp | ❌ | ❌ | ✅ | ❌ |

## Usage

### For Toolchain Template Authors

1. Declare capabilities in `toolchain.yaml`:
   ```yaml
   capabilities:
     required:
       - persistent-home
       - outbound-https
     optional:
       - gui-vnc
   ```

2. Reference compute profiles:
   ```yaml
   compute:
     profiles: [sw-dev-small, sw-dev-medium, sw-dev-large]
     default: sw-dev-medium
   ```

### For Infrastructure Base Module Authors

1. Copy `variables.tf` to your base module
2. Implement all required outputs per `outputs.tf`
3. Implement capability logic based on `capabilities.yaml`
4. Validate capability support for your platform

### For Template Composition

```hcl
module "toolchain" {
  source = "git::https://github.com/org/toolchain-templates.git//swdev-toolchain?ref=v1.2.0"
}

module "infra" {
  source = "git::https://github.com/org/coder-bases.git//base-k8s?ref=v3.1.0"
  
  workspace_name = data.coder_workspace.me.name
  owner          = data.coder_workspace_owner.me.name
  compute_profile = var.compute_profile
  image_id       = module.toolchain.image_id
  capabilities   = module.toolchain.capabilities
  
  toolchain_template = {
    name    = "swdev-toolchain"
    version = "1.2.0"
  }
  base_module = {
    name    = "base-k8s"
    version = "3.1.0"
  }
}
```

## Requirements Covered

- **11d.1**: Minimal, stable interface between layers
- **11d.2**: Toolchain template inputs specification
- **11d.3**: Infrastructure base outputs specification
- **11d.4**: Infrastructure base inputs specification
- **11c.4**: Capability definitions
- **11g.1**: Capability-only infrastructure access
- **14.16**: T-shirt size compute profiles

