# Workspace Template Contract Reference

This document defines the interface specification between portable toolchain templates and instance-specific infrastructure base modules. The template contract enables composable workspace architectures by establishing a stable API contract between components.

## Overview

The template contract separates workspace concerns into two distinct components:

1. **Toolchain Templates** - Portable, tool-specific configurations (e.g., Python development, data science, platform engineering)
2. **Infrastructure Base Modules** - Platform-specific implementations (e.g., Kubernetes pods, EC2 instances, GPU workloads)

This separation enables:
- Toolchain templates to be reused across different infrastructure platforms
- Infrastructure bases to support multiple toolchain types
- Independent versioning and testing of each layer
- Clear capability negotiation between components

**Contract Schema Location:** `modules/coder/template-architecture/contract/contract-schema.yaml`

---

## Table of Contents

- [Contract Inputs](#contract-inputs)
- [Contract Outputs](#contract-outputs)
- [Capability Interface](#capability-interface)
- [Compute Profiles](#compute-profiles)
- [Capability Constraints](#capability-constraints)
- [Example Terraform Usage](#example-terraform-usage)

---

## Contract Inputs

Infrastructure base modules MUST accept these inputs from toolchain templates:

| Input | Type | Description | Required |
|-------|------|-------------|----------|
| `workspace_name` | string | Workspace name from `data.coder_workspace.me.name` | Yes |
| `owner` | string | Owner username from `data.coder_workspace_owner.me.name` | Yes |
| `compute_profile` | object | Compute resources (see below) | Yes |
| `image_id` | string | Toolchain image reference | Yes |
| `capabilities` | object | Requested capabilities | Yes |

### Compute Profile Object

The compute profile defines the resource allocation for the workspace:

```hcl
variable "compute_profile" {
  type = object({
    cpu       = number        # vCPUs (1-64)
    memory    = string        # Memory (e.g., "8Gi")
    storage   = string        # Storage (e.g., "100Gi")
    gpu_count = optional(number, 0)
    gpu_type  = optional(string)  # nvidia-t4, nvidia-a10g, nvidia-v100, nvidia-a100
  })
}
```

**Example:**
```hcl
compute_profile = {
  cpu       = 4
  memory    = "8Gi"
  storage   = "100Gi"
  gpu_count = 0
  gpu_type  = null
}
```

---

## Contract Outputs

Infrastructure base modules MUST provide these outputs to complete the workspace provisioning:

| Output | Type | Description |
|--------|------|-------------|
| `agent_endpoint` | string | Coder agent endpoint |
| `runtime_env` | map(string) | Environment variables |
| `volume_mounts` | list(object) | Volume mount configuration |
| `metadata` | object | Provenance and tracking data |

### Volume Mount Object

Volume mounts define persistent and ephemeral storage for the workspace:

```hcl
output "volume_mounts" {
  value = [
    {
      path          = "/home/coder"
      type          = "pvc"  # pvc, ebs, efs, local
      size          = "100Gi"
      storage_class = "gp3"
    }
  ]
}
```

**Volume Types:**
- `pvc` - Kubernetes PersistentVolumeClaim
- `ebs` - AWS Elastic Block Store (EC2)
- `efs` - AWS Elastic File System (shared)
- `local` - Ephemeral node-local storage

### Metadata Object

Metadata provides provenance and tracking information for the workspace:

```hcl
output "metadata" {
  value = {
    platform          = "kubernetes"  # kubernetes, ec2-linux, ec2-windows, ec2-gpu
    os                = "linux"       # linux, windows
    arch              = "amd64"       # amd64, arm64
    toolchain_version = "1.2.0"
    base_version      = "3.1.0"
    image_digest      = "sha256:abc123..."
    ami_id            = null          # For EC2 only
    provisioned_at    = timestamp()
  }
}
```

**Platform Types:**
- `kubernetes` - Kubernetes pod-based workspace
- `ec2-linux` - Amazon EC2 Linux instance
- `ec2-windows` - Amazon EC2 Windows instance
- `ec2-gpu` - Amazon EC2 GPU-accelerated instance

---

## Capability Interface

Capabilities define optional features and behaviors that toolchain templates can request and infrastructure bases must implement.

**Capabilities Schema Location:** `modules/coder/template-architecture/contract/capabilities.yaml`

| Capability | Type | Default | Description |
|------------|------|---------|-------------|
| `persistent-home` | bool | `true` | Persist /home/coder across restarts |
| `network-egress` | enum | `https-only` | `none`, `https-only`, `unrestricted` |
| `identity-mode` | enum | `iam` | `oidc`, `iam`, `workload-identity` |
| `gpu-support` | bool | `false` | Request GPU resources |
| `artifact-cache` | bool | `false` | Enable build caching |
| `secrets-injection` | enum | `variables` | `variables`, `vault`, `secrets-manager` |
| `gui-vnc` | bool | `false` | VNC desktop (Linux) |
| `gui-rdp` | bool | `false` | RDP desktop (Windows) |

### Capability Details

#### persistent-home
When enabled, the `/home/coder` directory is persisted across workspace restarts using durable storage (PVC, EBS, or EFS).

**Use Cases:**
- Preserving Git repositories, IDE settings, shell history
- Caching dependencies (npm, pip, Maven)
- Storing local databases or test data

#### network-egress
Controls outbound network access from the workspace.

**Options:**
- `none` - No outbound access (air-gapped)
- `https-only` - Only HTTPS (443) allowed
- `unrestricted` - All outbound ports allowed

#### identity-mode
Determines how the workspace authenticates to cloud services.

**Options:**
- `oidc` - OIDC-based identity federation
- `iam` - AWS IAM Roles for Service Accounts (IRSA)
- `workload-identity` - GCP Workload Identity

#### gpu-support
Requests GPU resources for the workspace. See [Compute Profiles](#compute-profiles) for GPU types.

#### artifact-cache
Enables shared build caching for dependency downloads.

**Implementation:**
- Kubernetes: Shared PVC or S3 bucket
- EC2: EFS mount or S3 bucket

#### secrets-injection
Defines how secrets are provided to the workspace.

**Options:**
- `variables` - Environment variables (for non-sensitive config)
- `vault` - HashiCorp Vault integration
- `secrets-manager` - AWS Secrets Manager

#### gui-vnc / gui-rdp
Enables graphical desktop access via VNC (Linux) or RDP (Windows).

### Platform Capability Support

Not all capabilities are supported on every platform:

| Capability | kubernetes | ec2-linux | ec2-windows | ec2-gpu |
|------------|------------|-----------|-------------|---------|
| persistent-home | ✓ | ✓ | ✓ | ✓ |
| network-egress | ✓ | ✓ | ✓ | ✓ |
| identity-mode | ✓ | ✓ | ✓ | ✓ |
| gpu-support | ✗ | ✗ | ✗ | ✓ |
| artifact-cache | ✓ | ✓ | ✗ | ✓ |
| secrets-injection | ✓ | ✓ | ✓ | ✓ |
| gui-vnc | ✓ | ✓ | ✗ | ✓ |
| gui-rdp | ✗ | ✗ | ✓ | ✗ |

---

## Compute Profiles

Compute profiles provide predefined t-shirt sizes for workspace resources, optimized for common use cases.

| Profile | CPU | Memory | Storage | GPU | Use Case |
|---------|-----|--------|---------|-----|----------|
| `sw-dev-small` | 2 | 4Gi | 20Gi | 0 | Light development |
| `sw-dev-medium` | 4 | 8Gi | 50Gi | 0 | Standard development |
| `sw-dev-large` | 8 | 16Gi | 100Gi | 0 | Heavy development |
| `platform-devsecops` | 4 | 8Gi | 100Gi | 0 | Platform engineering |
| `datasci-standard` | 8 | 32Gi | 500Gi | 0 | Data analysis |
| `datasci-large` | 16 | 64Gi | 1Ti | 1 (T4) | ML training |
| `datasci-xlarge` | 32 | 64Gi | 2Ti | 4 (A100) | Large-scale ML |

### Profile Selection Guidelines

**sw-dev-small:**
- Lightweight IDE usage (VS Code, vim)
- Small codebases (<100 MB)
- Minimal build/test requirements

**sw-dev-medium:**
- Full-featured IDE (IntelliJ, VS Code with extensions)
- Medium codebases (100 MB - 1 GB)
- Standard build/test/debug workflows

**sw-dev-large:**
- Multiple concurrent services
- Large monorepos (>1 GB)
- Memory-intensive builds (JVM, Node.js)

**platform-devsecops:**
- Kubernetes/Terraform development
- Container builds and testing
- CI/CD pipeline development

**datasci-standard:**
- Data exploration with pandas/dask
- Medium datasets (<10 GB)
- CPU-based ML training

**datasci-large:**
- Large dataset processing (10-100 GB)
- GPU-accelerated ML training
- Model fine-tuning

**datasci-xlarge:**
- Very large datasets (>100 GB)
- Distributed training
- Large language model fine-tuning

### GPU Types

| GPU Type | Memory | FP32 TFLOPS | Use Case |
|----------|--------|-------------|----------|
| `nvidia-t4` | 16 GB | 8.1 | Inference, small training |
| `nvidia-a10g` | 24 GB | 31.2 | Medium training, high-throughput inference |
| `nvidia-v100` | 16-32 GB | 15.7 | Large training, research |
| `nvidia-a100` | 40-80 GB | 19.5 | Very large training, multi-GPU distributed |

---

## Capability Constraints

### Mutual Exclusions

The following capabilities cannot be enabled simultaneously:

- `gui-vnc` and `gui-rdp` (platform-specific desktop protocols)

### Implications

Enabling certain capabilities may require or restrict others:

- If `gpu-support` is `true`, then `network-egress` must be `https-only` or `unrestricted` (for driver/CUDA downloads)
- If `gui-vnc` or `gui-rdp` is `true`, then `persistent-home` should be `true` (to preserve desktop state)

---

## Example Terraform Usage

### Complete Template Composition

This example demonstrates how to compose a workspace template using the contract:

```hcl
# 1. Import portable toolchain template
module "toolchain" {
  source = "git::https://github.com/org/toolchain-templates.git//swdev-toolchain?ref=v1.2.0"

  # Toolchain configuration
  language_version = "python-3.11"
  include_tools    = ["docker", "kubectl", "terraform"]
}

# 2. Validate composition compatibility
module "validation" {
  source = "./modules/coder/template-architecture/validation"

  toolchain_capabilities = module.toolchain.capabilities
  base_platform          = "kubernetes"
}

# 3. Deploy infrastructure base with toolchain inputs
module "infra" {
  source = "./modules/coder/template-architecture/bases/base-k8s"

  # Contract inputs
  workspace_name  = data.coder_workspace.me.name
  owner           = data.coder_workspace_owner.me.name
  compute_profile = var.compute_profile
  image_id        = module.toolchain.image_id
  capabilities    = module.toolchain.capabilities

  # Base-specific configuration
  namespace         = "coder-workspaces"
  storage_class     = "gp3-encrypted"
  node_selector     = { "coder.com/nodepool" = "workspace" }
  tolerations       = [
    {
      key      = "coder.com/nodepool"
      operator = "Equal"
      value    = "workspace"
      effect   = "NoSchedule"
    }
  ]

  depends_on = [module.validation]
}

# 4. Pass infrastructure outputs to Coder agent
resource "coder_agent" "main" {
  os             = module.infra.metadata.os
  arch           = module.infra.metadata.arch
  startup_script = module.toolchain.startup_script

  env = merge(
    module.toolchain.environment_variables,
    module.infra.runtime_env
  )

  metadata {
    key   = "toolchain_version"
    value = module.infra.metadata.toolchain_version
  }

  metadata {
    key   = "base_version"
    value = module.infra.metadata.base_version
  }
}
```

### User-Facing Template Parameters

Templates can expose compute profiles to users:

```hcl
data "coder_parameter" "compute_profile" {
  name        = "compute_profile"
  display_name = "Compute Profile"
  description = "Select the resource allocation for your workspace"
  default     = "sw-dev-medium"
  type        = "string"
  mutable     = true

  option {
    name  = "Small (2 CPU, 4 GB)"
    value = "sw-dev-small"
  }

  option {
    name  = "Medium (4 CPU, 8 GB)"
    value = "sw-dev-medium"
  }

  option {
    name  = "Large (8 CPU, 16 GB)"
    value = "sw-dev-large"
  }
}

locals {
  compute_profiles = {
    "sw-dev-small" = {
      cpu     = 2
      memory  = "4Gi"
      storage = "20Gi"
    }
    "sw-dev-medium" = {
      cpu     = 4
      memory  = "8Gi"
      storage = "50Gi"
    }
    "sw-dev-large" = {
      cpu     = 8
      memory  = "16Gi"
      storage = "100Gi"
    }
  }

  selected_profile = local.compute_profiles[data.coder_parameter.compute_profile.value]
}
```

### Capability Declaration in Toolchain Templates

Toolchain templates declare their capability requirements:

```hcl
# toolchain-templates/swdev-python/outputs.tf
output "capabilities" {
  value = {
    persistent-home     = true
    network-egress      = "https-only"
    identity-mode       = "iam"
    gpu-support         = false
    artifact-cache      = true
    secrets-injection   = "secrets-manager"
    gui-vnc            = false
    gui-rdp            = false
  }
}

output "image_id" {
  value = "ghcr.io/org/python-dev:3.11-slim"
}
```

### Capability Implementation in Infrastructure Bases

Infrastructure bases implement the requested capabilities:

```hcl
# modules/coder/template-architecture/bases/base-k8s/main.tf
resource "kubernetes_pod_v1" "workspace" {
  metadata {
    name      = var.workspace_name
    namespace = var.namespace
  }

  spec {
    # Implement persistent-home capability
    dynamic "volume" {
      for_each = var.capabilities.persistent-home ? [1] : []
      content {
        name = "home"
        persistent_volume_claim {
          claim_name = kubernetes_persistent_volume_claim_v1.home[0].metadata[0].name
        }
      }
    }

    container {
      name  = "workspace"
      image = var.image_id

      # Implement network-egress capability
      security_context {
        capabilities {
          drop = var.capabilities.network-egress == "none" ? ["NET_RAW"] : []
        }
      }

      # Implement identity-mode capability (IRSA)
      env {
        name  = "AWS_ROLE_ARN"
        value = var.capabilities.identity-mode == "iam" ? aws_iam_role.workspace[0].arn : ""
      }

      # Implement secrets-injection capability
      dynamic "env" {
        for_each = var.capabilities.secrets-injection == "secrets-manager" ? var.secrets : {}
        content {
          name = env.key
          value_from {
            secret_key_ref {
              name = kubernetes_secret_v1.workspace[0].metadata[0].name
              key  = env.key
            }
          }
        }
      }
    }
  }
}
```

---

## Related Documentation

- **[Module and Provider Reference](./module-reference.md)** - Complete module and provider documentation
- **[Template Development Guide](../guides/template-development.md)** - How to create workspace templates
- **[Architecture Overview](../architecture-overview.md)** - System architecture and design decisions
- **[Deployment Guide](../guides/deployment-guide.md)** - Step-by-step deployment instructions
