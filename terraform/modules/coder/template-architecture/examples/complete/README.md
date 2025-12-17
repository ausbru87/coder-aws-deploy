# Complete Template Architecture Example

This example demonstrates how to use all template architecture modules together to deploy composed templates to Coder.

## Overview

This example:
1. Configures default template pairings (toolchain + infrastructure base)
2. Deploys composed templates via the coderd Terraform provider
3. Configures template ACLs for access control
4. Records provenance for all deployed templates

## Prerequisites

- Coder deployment with coderd provider access
- `CODER_URL` and `CODER_SESSION_TOKEN` environment variables set
- Terraform >= 1.0

## Usage

```bash
# Set environment variables
export CODER_URL="https://coder.example.com"
export CODER_SESSION_TOKEN="your-session-token"

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var="coder_url=${CODER_URL}"

# Apply deployment
terraform apply -var="coder_url=${CODER_URL}"
```

## Deployed Templates

| Template | Toolchain | Infrastructure Base | Description |
|----------|-----------|---------------------|-------------|
| pod-swdev | swdev-toolchain | base-k8s | Pod-based software development |
| ec2-windev-gui | windev-toolchain | base-ec2-windows | Windows EC2 with GUI |
| ec2-datasci | datasci-toolchain | base-ec2-linux | Linux EC2 data science |
| ec2-datasci-gpu | datasci-toolchain | base-ec2-gpu | GPU EC2 data science |

## Outputs

- `pairing_summary`: Summary of configured pairings
- `deployed_templates`: List of deployed template names
- `template_ids`: Map of template names to Coder IDs
- `deployment_provenance`: Provenance records for all templates
