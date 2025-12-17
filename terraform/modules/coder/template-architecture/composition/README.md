# Template Composition Module

This module implements the template composition logic that combines toolchain templates with infrastructure base modules to produce deployable Coder templates.

## Overview

The composition module:
1. Sources a toolchain template (portable layer)
2. Sources an infrastructure base module (instance-specific layer)
3. Validates capability requirements via the validation module
4. Records provenance information (versions, artifact IDs)
5. Produces a composed template ready for deployment

## Requirements Covered

| Requirement | Description | Implementation |
|-------------|-------------|----------------|
| 11c.7 | Compose templates as Toolchain + Base + Overrides | `main.tf` composition logic |
| 11d.7 | Record provenance (versions, artifact IDs) | `outputs.tf` metadata |
| 16.3 | Integrate with coderd provider | `coderd_template` resource |

## Usage

```hcl
module "composed_template" {
  source = "./modules/coder/template-architecture/composition"

  # Template pairing
  toolchain_name    = "swdev-toolchain"
  toolchain_version = "1.0.0"
  base_name         = "base-k8s"
  base_version      = "1.0.0"

  # Workspace context (from Coder data sources)
  workspace_name = data.coder_workspace.me.name
  owner          = data.coder_workspace_owner.me.name

  # Compute profile selection
  compute_profile_name = "sw-dev-medium"

  # Optional overrides
  overrides = {
    environment_variables = {
      CUSTOM_VAR = "value"
    }
  }

  # Override policy (security controls)
  override_policy = {
    allow_network_override  = false
    allow_identity_override = false
  }
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `toolchain_name` | Name of the toolchain template | `string` | Yes |
| `toolchain_version` | Version of the toolchain template | `string` | Yes |
| `base_name` | Name of the infrastructure base module | `string` | Yes |
| `base_version` | Version of the infrastructure base module | `string` | Yes |
| `workspace_name` | Workspace name from Coder | `string` | Yes |
| `owner` | Workspace owner from Coder | `string` | Yes |
| `compute_profile_name` | T-shirt size name | `string` | Yes |
| `overrides` | Controlled overrides | `object` | No |
| `override_policy` | Security policy for overrides | `object` | No |

## Outputs

| Name | Description |
|------|-------------|
| `provenance` | Complete provenance record |
| `composed_config` | Composed template configuration |
| `validation_result` | Validation status and details |
| `agent_config` | Coder agent configuration |

## Provenance Record

The composition module records provenance information per Requirement 11d.7:

```json
{
  "toolchain": {
    "name": "swdev-toolchain",
    "version": "1.0.0",
    "source": "git::https://github.com/org/toolchains.git//swdev-toolchain?ref=v1.0.0"
  },
  "base": {
    "name": "base-k8s",
    "version": "1.0.0",
    "source": "./modules/coder/template-architecture/bases/base-k8s"
  },
  "artifacts": {
    "image_digest": "sha256:abc123...",
    "ami_id": null
  },
  "composed_at": "2024-01-15T10:30:00Z",
  "composed_by": "terraform"
}
```

## Security

The composition module enforces security controls via the override policy:

- **Network Policy**: Cannot be overridden by default
- **Identity Binding**: Cannot be overridden by default
- **Privileged Execution**: Blocked by default
- **Mount Permissions**: Cannot be overridden by default

See the validation module for detailed policy enforcement.
