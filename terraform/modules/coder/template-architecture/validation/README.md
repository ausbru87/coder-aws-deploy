# Template Contract Validation Module

This module validates that toolchain template capability requirements are satisfied by the selected infrastructure base module, and enforces override policies.

## Overview

The validation module performs two types of validation:

1. **Contract Validation**: Ensures all required capabilities declared by the toolchain template are supported by the infrastructure base module
2. **Override Policy Validation**: Ensures requested overrides comply with security policies

## Requirements Covered

- **11c.10**: Validate toolchain template capability requirements are satisfied by infrastructure base
- **11g.3**: Policy-validate overrides to prevent arbitrary passthrough

## Usage

### Basic Usage

```hcl
module "contract_validation" {
  source = "./modules/coder/template-architecture/validation"

  toolchain_capabilities = {
    required = ["persistent-home", "network-egress", "identity-mode"]
    optional = ["gui-vnc", "artifact-cache"]
  }

  base_platform = "kubernetes"
}
```

### With Override Policy

```hcl
module "contract_validation" {
  source = "./modules/coder/template-architecture/validation"

  toolchain_capabilities = {
    required = ["persistent-home", "gpu-support"]
    optional = ["gui-vnc"]
  }

  base_platform = "ec2-gpu"

  requested_overrides = {
    compute_profile = {
      cpu    = 16
      memory = "64Gi"
    }
    environment_variables = {
      "CUSTOM_VAR" = "value"
    }
  }

  override_policy = {
    allow_compute_override    = true
    allow_env_override        = true
    allow_network_override    = false  # Security control
    allow_identity_override   = false  # Security control
    allow_privileged          = false  # Security control
    blocked_env_prefixes      = ["AWS_", "CODER_AGENT_", "SECRET_"]
  }
}
```

### In Template Composition

```hcl
# Validate before provisioning
module "validation" {
  source = "./modules/coder/template-architecture/validation"

  toolchain_capabilities = module.toolchain.capabilities
  base_platform          = "kubernetes"
  
  requested_overrides = var.user_overrides
  override_policy     = local.security_policy
}

# Only proceed if validation passes
module "infra" {
  source = "./modules/coder/template-architecture/bases/base-k8s"
  
  # ... configuration ...
  
  depends_on = [module.validation]
}
```

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `toolchain_capabilities` | object | Yes | Capabilities declared by toolchain template |
| `base_platform` | string | Yes | Infrastructure base platform type |
| `base_supported_capabilities` | list(string) | No | Override platform default capabilities |
| `requested_overrides` | object | No | Overrides requested during composition |
| `override_policy` | object | No | Policy controlling permitted overrides |

### toolchain_capabilities

```hcl
toolchain_capabilities = {
  required = list(string)  # Capabilities that MUST be supported
  optional = list(string)  # Capabilities that MAY be used if available
}
```

Valid capabilities:
- `persistent-home`
- `network-egress`
- `identity-mode`
- `gpu-support`
- `artifact-cache`
- `secrets-injection`
- `gui-vnc`
- `gui-rdp`

### base_platform

Valid values:
- `kubernetes` - EKS pod-based workspaces
- `ec2-linux` - Linux EC2 workspaces
- `ec2-windows` - Windows EC2 workspaces
- `ec2-gpu` - GPU-enabled EC2 workspaces

### override_policy

```hcl
override_policy = {
  allow_compute_override    = bool          # Allow compute profile changes
  allow_env_override        = bool          # Allow environment variables
  allow_label_override      = bool          # Allow label changes
  allow_annotation_override = bool          # Allow annotation changes
  allow_network_override    = bool          # Allow network policy changes (security)
  allow_identity_override   = bool          # Allow identity binding changes (security)
  allow_privileged          = bool          # Allow privileged execution (security)
  allow_mount_override      = bool          # Allow mount permission changes (security)
  blocked_env_prefixes      = list(string)  # Environment variable prefixes to block
  blocked_labels            = list(string)  # Label prefixes to block
}
```

## Outputs

| Name | Type | Description |
|------|------|-------------|
| `validation_passed` | bool | Whether all validations passed |
| `missing_capabilities` | list(string) | Required capabilities not supported |
| `available_optional_capabilities` | list(string) | Optional capabilities that are available |
| `override_violations` | list(string) | Override policy violations |
| `effective_capabilities` | object | Effective capabilities after validation |
| `validation_summary` | object | Complete validation summary |
| `capability_validations` | map(bool) | Per-capability validation results |
| `capability_constraint_violations` | list(string) | Constraint violations |

## Platform Capability Matrix

| Capability | Kubernetes | EC2 Linux | EC2 Windows | EC2 GPU |
|------------|:----------:|:---------:|:-----------:|:-------:|
| persistent-home | ✅ | ✅ | ✅ | ✅ |
| network-egress | ✅ | ✅ | ✅ | ✅ |
| identity-mode | ✅ | ✅ | ✅ | ✅ |
| gpu-support | ❌ | ❌ | ❌ | ✅ |
| artifact-cache | ✅ | ✅ | ❌ | ✅ |
| secrets-injection | ✅ | ✅ | ✅ | ✅ |
| gui-vnc | ✅ | ✅ | ❌ | ✅ |
| gui-rdp | ❌ | ❌ | ✅ | ❌ |

## Validation Behavior

### Contract Validation

The module checks that all required capabilities are supported by the target platform:

```
Required: [persistent-home, gpu-support]
Platform: kubernetes
Supported: [persistent-home, network-egress, identity-mode, ...]

Result: FAIL - gpu-support not supported on kubernetes
```

### Override Policy Validation

The module enforces security policies on overrides:

```
Requested Override: network_policy = "allow-all"
Policy: allow_network_override = false

Result: FAIL - Network policy override not permitted - security control
```

### Capability Constraints

The module enforces capability constraints:

```
Required: [gui-vnc, gui-rdp]

Result: FAIL - gui-vnc and gui-rdp are mutually exclusive
```

## Error Messages

The module provides clear error messages when validation fails:

- `Contract validation failed: Infrastructure base 'kubernetes' does not support required capabilities: gpu-support`
- `Override policy validation failed: Network policy override not permitted - security control`
- `Capability 'gui-vnc' is mutually exclusive with 'gui-rdp'`

## Security Considerations

The following overrides are blocked by default for security:

1. **Network Policy Override** - Prevents bypassing network isolation
2. **Identity Binding Override** - Prevents privilege escalation
3. **Privileged Execution** - Prevents container escape
4. **Mount Permissions Override** - Prevents unauthorized filesystem access

These can only be enabled by explicitly setting the corresponding policy flag to `true`.

