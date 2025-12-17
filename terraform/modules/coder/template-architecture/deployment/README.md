# Template Deployment Module

This module deploys composed templates to Coder using the coderd Terraform provider.

## Overview

The deployment module:
1. Takes pairing configurations from the pairings module
2. Creates `coderd_template` resources for each enabled pairing
3. Configures template ACLs via the `acl` block
4. Manages template versions through Terraform state

## Requirements Covered

| Requirement | Description | Implementation |
|-------------|-------------|----------------|
| 16.3 | Use coderd_template resource for declarative template management | `main.tf` |
| 12b.3 | Configure template access permissions via coderd_template_acl | `main.tf` ACL blocks |

## Usage

```hcl
module "template_deployment" {
  source = "./modules/coder/template-architecture/deployment"

  # Enable deployment
  enable_deployment = true

  # Organization context
  organization_id = data.coderd_organization.default.id

  # Pairing configurations from pairings module
  pairing_configs = module.pairings.pairing_configs

  # Group IDs for ACL configuration
  developers_group_id      = coderd_group.developers.id
  platform_admins_group_id = coderd_group.platform_admins.id
  template_owners_group_id = coderd_group.template_owners.id

  # Template directory base path
  template_directory_base = "${path.module}/templates"

  # Version for all templates
  template_version = "1.0.0"
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `enable_deployment` | Enable template deployment | `bool` | No |
| `organization_id` | Coder organization ID | `string` | Yes |
| `pairing_configs` | Pairing configurations from pairings module | `map(object)` | Yes |
| `developers_group_id` | Developers group ID for ACL | `string` | Yes |
| `platform_admins_group_id` | Platform admins group ID for ACL | `string` | Yes |
| `template_owners_group_id` | Template owners group ID for ACL | `string` | Yes |
| `template_directory_base` | Base path for template directories | `string` | Yes |
| `template_version` | Version string for templates | `string` | No |

## Outputs

| Name | Description |
|------|-------------|
| `template_ids` | Map of template names to IDs |
| `template_versions` | Map of template names to versions |
| `deployment_summary` | Summary of deployed templates |

## ACL Configuration

Template access is configured based on the pairing type:

| Template | Developers | Platform Admins | Template Owners |
|----------|------------|-----------------|-----------------|
| pod-swdev | use | use | admin |
| ec2-windev-gui | use | - | admin |
| ec2-datasci | - | - | admin |
| ec2-datasci-gpu | - | - | admin |

Note: Data science templates have restricted access per Requirement 14.17.
