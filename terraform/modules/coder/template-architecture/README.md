# Template Architecture

This directory contains the two-layer template architecture implementation for Coder workspaces, consisting of portable toolchain templates and instance-specific infrastructure base modules.

## Overview

The template architecture separates workspace definitions into two layers:

1. **Toolchain Layer (Portable)**: Declares what a workspace should be (languages, tools, dependencies, capabilities) without specifying how it runs
2. **Infrastructure Base Layer (Instance-Specific)**: Defines how workspaces run in a given Coder instance (compute, networking, storage, identity)

This separation enables:
- Toolchain templates to be portable across Coder instances
- Infrastructure concerns to remain instance-owned
- Policy enforcement at the capability level
- Predictable composition and validation

## Directory Structure

```
template-architecture/
├── README.md                    # This file
├── contract/                    # Contract schema definitions
│   ├── README.md               # Contract documentation
│   ├── contract-schema.yaml    # Complete contract schema
│   ├── capabilities.yaml       # Capability definitions
│   ├── variables.tf            # Terraform variable definitions
│   └── outputs.tf              # Terraform output definitions
├── validation/                  # Contract validation module
│   ├── README.md               # Validation documentation
│   ├── main.tf                 # Validation logic
│   ├── capability_check.tf     # Capability checking functions
│   └── versions.tf             # Terraform version requirements
├── composition/                 # Template composition module
│   ├── README.md               # Composition documentation
│   ├── main.tf                 # Composition logic
│   ├── variables.tf            # Composition inputs
│   ├── outputs.tf              # Provenance and composed config
│   └── versions.tf             # Terraform version requirements
├── pairings/                    # Default template pairings
│   ├── README.md               # Pairings documentation
│   ├── main.tf                 # Pairing definitions
│   ├── variables.tf            # Pairing configuration
│   ├── outputs.tf              # Pairing outputs
│   └── versions.tf             # Terraform version requirements
├── deployment/                  # Template deployment via coderd
│   ├── README.md               # Deployment documentation
│   ├── main.tf                 # coderd_template resources
│   ├── variables.tf            # Deployment configuration
│   ├── outputs.tf              # Deployment outputs
│   └── versions.tf             # Terraform version requirements
├── ci-cd/                       # CI/CD pipeline configurations
│   ├── README.md               # CI/CD overview
│   ├── github-actions/         # GitHub Actions workflow examples
│   │   ├── toolchain-ci.yml    # Toolchain template CI
│   │   ├── infra-base-ci.yml   # Infrastructure base CI
│   │   └── security-scan.yml   # Security scanning workflow
│   ├── scripts/                # Validation scripts
│   │   ├── validate-toolchain.sh
│   │   ├── validate-infra-base.sh
│   │   └── contract-check.sh
│   └── docs/                   # Platform-agnostic documentation
│       ├── ci-cd-requirements.md
│       ├── approval-gates.md
│       └── upgrade-channels.md
├── toolchains/                  # Toolchain templates (portable)
│   ├── swdev-toolchain/        # Software development toolchain
│   ├── windev-toolchain/       # Windows development toolchain
│   └── datasci-toolchain/      # Data science toolchain
└── bases/                       # Infrastructure base modules (instance-specific)
    ├── base-k8s/               # Kubernetes pod workspaces (EKS)
    │   ├── main.tf             # Pod deployment, PVC, NetworkPolicy
    │   ├── variables.tf        # Contract inputs
    │   ├── outputs.tf          # Contract outputs
    │   └── README.md           # Module documentation
    ├── base-ec2-linux/         # Linux EC2 workspaces
    │   ├── main.tf             # EC2 instance, EBS, security groups
    │   ├── variables.tf        # Contract inputs
    │   ├── outputs.tf          # Contract outputs
    │   └── README.md           # Module documentation
    ├── base-ec2-windows/       # Windows EC2 workspaces (DCV/WebRDP)
    │   ├── main.tf             # Windows EC2, NICE DCV setup
    │   ├── variables.tf        # Contract inputs
    │   ├── outputs.tf          # Contract outputs
    │   └── README.md           # Module documentation
    └── base-ec2-gpu/           # GPU EC2 workspaces (g4dn, g5, p3, p4d)
        ├── main.tf             # GPU EC2, Deep Learning AMI
        ├── variables.tf        # Contract inputs
        ├── outputs.tf          # Contract outputs
        └── README.md           # Module documentation
```

## Requirements Covered

| Requirement | Description | Implementation |
|-------------|-------------|----------------|
| 11c.1 | Two-layer architecture | contract/, toolchains/, bases/ |
| 11c.2 | Toolchain templates declare capabilities | toolchains/*/toolchain.yaml |
| 11c.7 | Compose templates as Toolchain + Base + Overrides | composition/ |
| 11c.8 | Instance administrators select pairings | pairings/ |
| 11c.10 | Validate capability requirements | validation/ |
| 11d.1 | Minimal, stable contract interface | contract/contract-schema.yaml |
| 11d.2 | Toolchain template inputs | contract/variables.tf |
| 11d.3 | Infrastructure base outputs | contract/outputs.tf |
| 11d.4 | Infrastructure base inputs | contract/variables.tf |
| 11d.7 | Record composition provenance | composition/outputs.tf |
| 11g.1 | Capability-only infrastructure access | contract/capabilities.yaml |
| 11g.3 | Policy-validated overrides | validation/ |
| 12b.3 | Configure template access permissions | deployment/ ACL blocks |
| 16.3 | Use coderd_template for declarative management | deployment/ |

## Template Contract

The contract defines the interface between toolchain templates and infrastructure bases:

### Contract Inputs (Infrastructure Base Accepts)

| Input | Type | Description |
|-------|------|-------------|
| `workspace_name` | string | Workspace name |
| `owner` | string | Workspace owner username |
| `compute_profile` | object | CPU, memory, storage, GPU |
| `image_id` | string | Toolchain image reference |
| `capabilities` | object | Requested capabilities |

### Contract Outputs (Infrastructure Base Provides)

| Output | Type | Description |
|--------|------|-------------|
| `agent_endpoint` | string | Coder agent endpoint |
| `runtime_env` | map(string) | Environment variables |
| `volume_mounts` | list(object) | Volume mount configuration |
| `metadata` | object | Provenance and tracking data |

### Capabilities

| Capability | Description | Default |
|------------|-------------|---------|
| `persistent-home` | Persist /home/coder | true |
| `network-egress` | Outbound network policy | https-only |
| `identity-mode` | Cloud authentication | iam |
| `gpu-support` | GPU resources | false |
| `artifact-cache` | Build caching | false |
| `secrets-injection` | Secret delivery | variables |
| `gui-vnc` | VNC desktop (Linux) | false |
| `gui-rdp` | RDP desktop (Windows) | false |

## Composition Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Template Composition Flow                            │
│                                                                              │
│  1. Toolchain Template              2. Infrastructure Base                   │
│     ┌─────────────────┐                ┌─────────────────┐                  │
│     │ swdev-toolchain │                │    base-k8s     │                  │
│     │ @v1.2.0         │                │    @v3.1.0      │                  │
│     └────────┬────────┘                └────────┬────────┘                  │
│              │                                  │                           │
│              └──────────────┬───────────────────┘                           │
│                             │                                               │
│                             ▼                                               │
│  3. Validation                                                              │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │ module "validation" {                                            │    │
│     │   source = "./validation"                                        │    │
│     │   toolchain_capabilities = module.toolchain.capabilities         │    │
│     │   base_platform = "kubernetes"                                   │    │
│     │ }                                                                │    │
│     └────────────────────────┬────────────────────────────────────────┘    │
│                              │                                              │
│                              ▼                                              │
│  4. Composed Template                                                       │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │ Coder Template: pod-swdev                                        │    │
│     │ - Toolchain: swdev-toolchain@v1.2.0                              │    │
│     │ - Base: base-k8s@v3.1.0                                          │    │
│     │ - Provenance recorded in metadata                                │    │
│     └─────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Usage Example

### Composing a Template

```hcl
# 1. Source the toolchain template
module "toolchain" {
  source = "git::https://github.com/org/toolchain-templates.git//swdev-toolchain?ref=v1.2.0"
}

# 2. Validate the composition
module "validation" {
  source = "./modules/coder/template-architecture/validation"

  toolchain_capabilities = module.toolchain.capabilities
  base_platform          = "kubernetes"
  
  override_policy = {
    allow_network_override  = false
    allow_identity_override = false
  }
}

# 3. Source the infrastructure base
module "infra" {
  source = "./modules/coder/template-architecture/bases/base-k8s"

  workspace_name  = data.coder_workspace.me.name
  owner           = data.coder_workspace_owner.me.name
  compute_profile = var.compute_profile
  image_id        = module.toolchain.image_id
  capabilities    = module.toolchain.capabilities

  toolchain_template = {
    name    = "swdev-toolchain"
    version = "1.2.0"
  }
  base_module = {
    name    = "base-k8s"
    version = "3.1.0"
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

## Security

### Override Policy

The validation module enforces security policies on overrides:

- **Network Policy**: Cannot be overridden by default
- **Identity Binding**: Cannot be overridden by default
- **Privileged Execution**: Blocked by default
- **Mount Permissions**: Cannot be overridden by default

### Capability Guardrails

Toolchain templates can only access infrastructure through capabilities:
- No direct subnet/security group declarations
- No direct AMI/node selector specifications
- All infrastructure primitives controlled by base modules

## Composition Module

The composition module (`composition/`) implements the logic to combine toolchain templates with infrastructure base modules:

```hcl
module "composed_template" {
  source = "./modules/coder/template-architecture/composition"

  toolchain_name    = "swdev-toolchain"
  toolchain_version = "1.0.0"
  base_name         = "base-k8s"
  base_version      = "1.0.0"

  workspace_name       = data.coder_workspace.me.name
  owner                = data.coder_workspace_owner.me.name
  compute_profile_name = "sw-dev-medium"
}

# Access provenance record
output "provenance" {
  value = module.composed_template.provenance
}
```

## Next Steps

After the contract, validation, and composition modules are in place:

1. **Task 22**: Create toolchain templates (swdev, windev, datasci) ✓
2. **Task 23**: Create infrastructure base modules (base-k8s, base-ec2-*) ✓
3. **Task 24**: Implement template composition and resolution ✓
4. **Task 25**: Implement template governance CI/CD

