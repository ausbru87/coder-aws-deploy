# Terraform Examples

This directory contains example configurations demonstrating various aspects of the Coder deployment.

## Examples

### coderd-provider/

Demonstrates how to use the coderd Terraform provider for Day 1/2 Coder configuration management.

**Features:**
- Provider configuration with authentication
- Group management for IDP sync
- Provisioner key management
- Template deployment with ACLs

**Usage:**
```bash
cd coderd-provider
export CODER_SESSION_TOKEN="your-admin-token"
terraform init
terraform plan
terraform apply
```

### template-pairings/

Demonstrates how to compose toolchain templates with infrastructure base modules to create runnable Coder templates.

**Features:**
- Toolchain + Infrastructure Base composition
- Contract validation
- Provenance tracking
- Multiple pairing examples:
  - `swdev-toolchain` + `base-k8s` → Pod software development
  - `windev-toolchain` + `base-ec2-windows` → Windows development with GUI
  - `datasci-toolchain` + `base-ec2-gpu` → Data science with GPU

**Usage:**
```bash
cd template-pairings
terraform init
terraform plan -var="compute_profile_name=sw-dev-medium"
```

## Environment Configuration Examples

### environments/prod-example.tfvars

A comprehensive production configuration example with detailed comments explaining all available options.

**Usage:**
```bash
# Copy and customize
cp environments/prod-example.tfvars environments/my-deployment.tfvars

# Edit with your values
vim environments/my-deployment.tfvars

# Deploy
terraform plan -var-file=environments/my-deployment.tfvars
terraform apply -var-file=environments/my-deployment.tfvars
```

## Template Architecture

The two-layer template architecture separates workspace definitions into:

1. **Toolchain Layer (Portable)**: Declares what a workspace should be
   - Languages, tools, dependencies
   - Capability requirements
   - Bootstrap scripts

2. **Infrastructure Base Layer (Instance-Specific)**: Defines how workspaces run
   - Compute resources (K8s pods, EC2 instances)
   - Networking (security groups, NetworkPolicy)
   - Storage (PVC, EBS volumes)
   - Identity (IRSA, instance profiles)

### Default Pairings

| Composed Template | Toolchain | Infrastructure Base |
|-------------------|-----------|---------------------|
| pod-swdev | swdev-toolchain | base-k8s |
| ec2-windev-gui | windev-toolchain | base-ec2-windows |
| ec2-datasci | datasci-toolchain | base-ec2-linux |
| ec2-datasci-gpu | datasci-toolchain | base-ec2-gpu |

## Related Documentation

- [Main README](../README.md) - Quick start and overview
- [Configuration Reference](../docs/configuration-reference.md) - All configuration options
- [Template Architecture](../modules/coder/template-architecture/README.md) - Detailed template docs
- [Deployment Guide](../docs/deployment-guide.md) - Step-by-step deployment
