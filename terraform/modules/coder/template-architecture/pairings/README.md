# Default Template Pairings

This module defines the default pairings between toolchain templates and infrastructure base modules.

## Overview

Template pairings specify which toolchain templates are compatible with which infrastructure base modules, and define the default combinations used to create Coder templates.

## Requirements Covered

| Requirement | Description | Implementation |
|-------------|-------------|----------------|
| 11c.8 | Instance administrators select toolchain + base pairings | `pairings.tf` |

## Default Pairings

| Pairing Name | Toolchain | Infrastructure Base | Result |
|--------------|-----------|---------------------|--------|
| `pod-swdev` | swdev-toolchain | base-k8s | Pod-based software development |
| `ec2-windev-gui` | windev-toolchain | base-ec2-windows | Windows EC2 with GUI |
| `ec2-datasci` | datasci-toolchain | base-ec2-linux | Linux EC2 data science |
| `ec2-datasci-gpu` | datasci-toolchain | base-ec2-gpu | GPU EC2 data science |

## Usage

```hcl
module "pairings" {
  source = "./modules/coder/template-architecture/pairings"

  # Enable specific pairings
  enabled_pairings = ["pod-swdev", "ec2-windev-gui", "ec2-datasci", "ec2-datasci-gpu"]

  # Version configuration
  toolchain_versions = {
    "swdev-toolchain"   = "1.0.0"
    "windev-toolchain"  = "1.0.0"
    "datasci-toolchain" = "1.0.0"
  }

  base_versions = {
    "base-k8s"         = "1.0.0"
    "base-ec2-linux"   = "1.0.0"
    "base-ec2-windows" = "1.0.0"
    "base-ec2-gpu"     = "1.0.0"
  }
}

# Access pairing configurations
output "pairing_configs" {
  value = module.pairings.pairing_configs
}
```

## Outputs

| Name | Description |
|------|-------------|
| `pairing_configs` | Map of pairing name to full configuration |
| `enabled_pairings` | List of enabled pairing names |
| `pairing_metadata` | Metadata for each pairing (versions, capabilities) |
