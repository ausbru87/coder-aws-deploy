# Design Document: Coder Deployment Guide and IaC

## Overview

This design document outlines the technical architecture and implementation approach for a production-ready Coder deployment on Amazon EKS. The solution provides a comprehensive deployment guide with architectural diagrams, Terraform-based IaC using both AWS provider and the coderd provider for declarative Coder configuration, and opinionated configurations for enterprise deployments.

The deployment targets organizations requiring:
- High availability (99.9% uptime) for up to 3000 concurrent workspaces
- Enterprise security with OIDC authentication, RBAC, and encryption
- Cost optimization through time-based scaling and workspace lifecycle management
- Support for both GUI and headless workspaces across multiple operating systems

## Architecture

### High-Level Architecture

```
+------------------------------------------------------------------------------+
|                           AWS Region (us-east-1)                              |
|                                                                               |
|  +------------------------------------------------------------------------+  |
|  |                          VPC (10.0.0.0/16)                             |  |
|  |                                                                        |  |
|  |  +----------------+  +----------------+  +----------------+            |  |
|  |  | Public Subnet  |  | Public Subnet  |  | Public Subnet  |            |  |
|  |  |     AZ-a       |  |     AZ-b       |  |     AZ-c       |            |  |
|  |  |  [NAT GW]      |  |  [NAT GW]      |  |  [NAT GW]      |            |  |
|  |  |  [NLB ENI]     |  |  [NLB ENI]     |  |  [NLB ENI]     |            |  |
|  |  +----------------+  +----------------+  +----------------+            |  |
|  |                                                                        |  |
|  |  +----------------+  +----------------+  +----------------+            |  |
|  |  | Private Subnet |  | Private Subnet |  | Private Subnet |            |  |
|  |  |   (Control)    |  |   (Control)    |  |   (Control)    |            |  |
|  |  | [coderd nodes] | | [coderd nodes] | | [coderd nodes] |            |  |
|  |  +----------------+  +----------------+  +----------------+            |  |
|  |                                                                        |  |
|  |  +----------------+  +----------------+  +----------------+            |  |
|  |  | Private Subnet |  | Private Subnet |  | Private Subnet |            |  |
|  |  | (Provisioner)  |  | (Provisioner)  |  | (Provisioner)  |            |  |
|  |  | [prov nodes]   |  | [prov nodes]   |  | [prov nodes]   |            |  |
|  |  +----------------+  +----------------+  +----------------+            |  |
|  |                                                                        |  |
|  |  +----------------+  +----------------+  +----------------+            |  |
|  |  | Private Subnet |  | Private Subnet |  | Private Subnet |            |  |
|  |  |  (Workspaces)  |  |  (Workspaces)  |  |  (Workspaces)  |            |  |
|  |  | [ws nodes]     |  | [ws nodes]     |  | [ws nodes]     |            |  |
|  |  +----------------+  +----------------+  +----------------+            |  |
|  |                                                                        |  |
|  |  +----------------+  +----------------+  +----------------+            |  |
|  |  |   DB Subnet    |  |   DB Subnet    |  |   DB Subnet    |            |  |
|  |  | [Aurora Writer]|  | [Aurora Reader]|  | [Aurora Reader]|            |  |
|  |  +----------------+  +----------------+  +----------------+            |  |
|  |                                                                        |  |
|  +------------------------------------------------------------------------+  |
|                                                                               |
|  +------------+  +------------+  +------------+  +------------+              |
|  |  Route 53  |  |    ACM     |  | CloudWatch |  |  Secrets   |              |
|  |            |  |            |  |            |  |  Manager   |              |
|  +------------+  +------------+  +------------+  +------------+              |
|                                                                               |
+------------------------------------------------------------------------------+
```

### Network Architecture

The VPC is designed with the following subnet structure:

| Subnet Type | CIDR Range | Purpose |
|-------------|------------|---------|
| Public | 10.0.0.0/20, 10.0.16.0/20, 10.0.32.0/20 | NAT Gateways, NLB ENIs |
| Private (Control) | 10.0.48.0/20, 10.0.64.0/20, 10.0.80.0/20 | coderd nodes |
| Private (Provisioner) | 10.0.96.0/20, 10.0.112.0/20, 10.0.128.0/20 | Provisioner nodes |
| Private (Workspace) | 10.0.144.0/18 (large) | Workspace nodes |
| Database | 10.0.208.0/21, 10.0.216.0/21, 10.0.224.0/21 | Aurora PostgreSQL |

CIDR sizing is calculated based on:
- Maximum 3000 concurrent workspaces
- Average 4 pods per workspace node
- Infrastructure overhead (system pods, controllers)
- Growth buffer of 20%

**Design Rationale - Subnet Separation:** While Coder does not mandate separate subnets for control plane, provisioners, and workspaces, this design uses dedicated subnets for each component type for the following reasons:

1. **Network Isolation** - Enables distinct security group rules and Network ACLs per component, supporting defense-in-depth and Requirement 3.1c (workspace isolation)
2. **Independent Scaling** - Each node group scales within its own CIDR allocation, preventing IP exhaustion in one tier from affecting others
3. **Traffic Visibility** - VPC Flow Logs can be analyzed per subnet for security auditing and troubleshooting
4. **Blast Radius Containment** - Limits lateral movement if a workspace is compromised

All components communicate over the Kubernetes CNI network and through the NLB/coderd API, so subnet separation does not impact Coder functionality.

### EKS Cluster Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                              EKS Cluster                                    │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                      Control Plane (AWS Managed)                       │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐   │
│  │    Node Group:     │  │    Node Group:     │  │    Node Group:     │   │
│  │   coder-control    │  │    coder-prov      │  │     coder-ws       │   │
│  │                    │  │                    │  │                    │   │
│  │  Instance: m5.large│  │  Instance: c5.2xl  │  │  Instance: m5.2xl  │   │
│  │  Min: 2            │  │  Min: 0            │  │  Min: 10           │   │
│  │  Max: 3            │  │  Max: 20           │  │  Max: 200          │   │
│  │  Scaling: Static   │  │  Scaling: Time     │  │  Scaling: Time     │   │
│  │                    │  │                    │  │                    │   │
│  │  Taints:           │  │  Taints:           │  │  Taints:           │   │
│  │  coder-control     │  │  coder-prov        │  │  coder-ws          │   │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘   │
│                                                                             │
│  Namespaces:                                                                │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐           │
│  │   coder    │  │ coder-prov │  │  coder-ws  │  │ kube-system│           │
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘           │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

### Security Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                           Security Boundaries                               │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                            IAM / IRSA                                  │ │
│  │                                                                        │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐        │ │
│  │  │ CoderServerRole │  │ CoderProvRole   │  │ AWSControllers  │        │ │
│  │  │                 │  │                 │  │ Roles           │        │ │
│  │  │ - Secrets       │  │ - EC2           │  │ - ALB           │        │ │
│  │  │ - RDS           │  │ - EKS           │  │ - EBS CSI       │        │ │
│  │  │                 │  │ - IAM PassRole  │  │                 │        │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘        │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                          Security Groups                               │ │
│  │                                                                        │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐        │ │
│  │  │    Node SG      │  │     RDS SG      │  │  VPC Endpoint   │        │ │
│  │  │                 │  │                 │  │       SG        │        │ │
│  │  │ - NLB ingress   │  │ - 5432 from     │  │ - 443 from      │        │ │
│  │  │ - Inter-node    │  │   Node SG       │  │   Node SG       │        │ │
│  │  │ - Egress all    │  │                 │  │                 │        │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘        │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                            Encryption                                  │ │
│  │                                                                        │ │
│  │  - TLS 1.2+ at NLB (ACM certificates)                                 │ │
│  │  - AES-256 encryption at rest (Aurora, EBS)                           │ │
│  │  - AES-128/256-GCM with ECDHE cipher suites                           │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### Infrastructure Components

| Component | AWS Service | Purpose |
|-----------|-------------|---------|
| VPC | Amazon VPC | Network isolation and segmentation |
| EKS | Amazon EKS | Kubernetes cluster management |
| Database | Aurora PostgreSQL Serverless v2 | Coder metadata storage |
| Load Balancer | Network Load Balancer | TLS termination, traffic distribution |
| DNS | Route 53 | Domain management, health checks |
| Certificates | ACM | TLS certificate management |
| Secrets | Secrets Manager | Credential storage |
| Monitoring | CloudWatch, AMP (optional) | Metrics, logs, alerts |
| Storage | EBS via CSI | Workspace persistent volumes |

### Coder Components

| Component | Deployment | Namespace | Node Pool |
|-----------|------------|-----------|-----------|
| coderd | Helm (coder) | coder | coder-control |
| External Provisioners | Helm (coder-provisioner) | coder-prov | coder-prov |
| Workspaces (Pod) | Coder Templates | coder-ws | coder-ws |
| Workspaces (EC2) | Coder Templates | N/A | N/A |
| Observability | Helm | coder | coder-control |

### Template Architecture: Toolchain + Infrastructure Base

The template system uses a two-layer architecture to achieve portability while maintaining instance-specific infrastructure control:

```
┌────────────────────────────────────────────────────────────────────────────┐
│                        Template Composition Model                           │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                  Toolchain Layer (Portable)                          │   │
│  │                                                                      │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐      │   │
│  │  │ swdev-toolchain │  │windev-toolchain │  │datasci-toolchain│      │   │
│  │  │                 │  │                 │  │                 │      │   │
│  │  │ Languages:      │  │ Languages:      │  │ Languages:      │      │   │
│  │  │  Go, Node, Py   │  │  C#, .NET       │  │  Python, R      │      │   │
│  │  │ Tools:          │  │ Tools:          │  │ Tools:          │      │   │
│  │  │  terraform,     │  │  Visual Studio, │  │  Jupyter, CUDA  │      │   │
│  │  │  kubectl, gh    │  │  Git, Azure CLI │  │  PyTorch, TF    │      │   │
│  │  │ Capabilities:   │  │ Capabilities:   │  │ Capabilities:   │      │   │
│  │  │  persistent-    │  │  gui-rdp,       │  │  gpu-optional,  │      │   │
│  │  │  home, https    │  │  persistent-    │  │  persistent-    │      │   │
│  │  │  egress         │  │  home           │  │  home, https    │      │   │
│  │  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘      │   │
│  │           │                    │                    │               │   │
│  └───────────┼────────────────────┼────────────────────┼───────────────┘   │
│              │                    │                    │                   │
│              ▼                    ▼                    ▼                   │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                 Template Contract (Capability Interface)              │ │
│  │                                                                       │ │
│  │  Inputs:  workspace_name, owner, compute_profile, image_id           │ │
│  │  Outputs: agent_endpoint, env_vars, volume_mounts, metadata          │ │
│  │  Capabilities: compute, network, storage, identity, secrets          │ │
│  │                                                                       │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│              │                    │                    │                   │
│              ▼                    ▼                    ▼                   │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │              Infrastructure Base Layer (Instance-Specific)            │ │
│  │                                                                       │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐       │ │
│  │  │    base-k8s     │  │ base-ec2-windows│  │   base-ec2-gpu  │       │ │
│  │  │                 │  │                 │  │                 │       │ │
│  │  │ - Namespace     │  │ - AMI selection │  │ - GPU AMI       │       │ │
│  │  │ - Node pool     │  │ - IAM roles     │  │ - g4dn/g5/p3/p4 │       │ │
│  │  │ - PVC/Storage   │  │ - Security grps │  │ - CUDA drivers  │       │ │
│  │  │ - NetworkPolicy │  │ - EBS volumes   │  │ - IAM roles     │       │ │
│  │  │ - Service acct  │  │ - DCV/WebRDP    │  │ - Security grps │       │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘       │ │
│  │                                                                       │ │
│  │  ┌─────────────────┐                                                  │ │
│  │  │  base-ec2-linux │                                                  │ │
│  │  │                 │                                                  │ │
│  │  │ - Linux AMI     │                                                  │ │
│  │  │ - IAM roles     │                                                  │ │
│  │  │ - Security grps │                                                  │ │
│  │  │ - EBS volumes   │                                                  │ │
│  │  │ - KasmVNC opt   │                                                  │ │
│  │  └─────────────────┘                                                  │ │
│  │                                                                       │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  Composition: Final Template = Toolchain + Base + Overrides                │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

#### Toolchain Template Structure

Each toolchain template contains:

| File | Purpose |
|------|---------|
| `toolchain.yaml` | Declares languages, tools, libraries, versions, and capability requirements |
| `bootstrap/` | Optional devcontainer or initialization scripts |
| `build/` | Optional image/Dockerfile or artifact manifest definitions |
| `tests/` | Lint and capability contract validation tests |

**Example toolchain.yaml:**
```yaml
name: swdev-toolchain
version: 1.2.0
description: Software development workspace

toolchain:
  languages:
    - name: go
      version: "1.23"
    - name: node
      version: "22"
    - name: python
      version: "3.12"
  tools:
    - terraform
    - kubectl
    - gh
    - docker-cli

capabilities:
  required:
    - persistent-home
    - outbound-https
  optional:
    - gui-vnc
  compute:
    profiles: [small, medium, large]
    default: medium
```

#### Infrastructure Base Module Structure

Each infrastructure base module contains:

| Component | Purpose |
|-----------|---------|
| `main.tf` | Core infrastructure provisioning (compute, storage, networking) |
| `variables.tf` | Contract inputs (workspace_name, owner, compute_profile, image_id) |
| `outputs.tf` | Contract outputs (agent_endpoint, env_vars, volume_mounts) |
| `capabilities.tf` | Capability implementations (network policy, identity, storage) |
| `policies/` | OPA/Rego policies for override validation |

#### Template Contract Schema

```yaml
# contract-schema.yaml
contract:
  version: "1.0"
  
  inputs:
    workspace_name: string
    owner: string
    compute_profile:
      cpu: integer
      memory: string  # e.g., "8Gi"
      storage: string # e.g., "100Gi"
    image_id: string  # toolchain image reference
    
  outputs:
    agent_endpoint: string
    runtime_env:
      type: map
      items: string
    volume_mounts:
      type: array
      items:
        path: string
        type: string  # pvc, ebs, efs
    metadata:
      type: map
      
  capabilities:
    persistent-home:
      type: boolean
      default: true
    network-egress:
      type: enum
      values: [none, https-only, unrestricted]
    identity-mode:
      type: enum
      values: [oidc, iam, workload-identity]
    gpu-support:
      type: boolean
      default: false
    artifact-cache:
      type: boolean
      default: false
    secrets-injection:
      type: enum
      values: [variables, vault, secrets-manager]
```

#### Implementation Approach: Terraform Modules + Coder Templates

The two-layer architecture is implemented using a combination of Terraform modules and Coder's native template system:

**Layer 1: Toolchain Templates (Portable)**
- Implemented as **Terraform module sources** containing:
  - `toolchain.yaml`: Declarative manifest (parsed by composition tooling)
  - `variables.tf`: Capability requests as Terraform variables
  - `bootstrap/`: Initialization scripts, devcontainer configs
  - `build/`: Optional Dockerfile or image build definitions
- Published to a **Git repository** (central catalog) with semantic versioning via tags
- Infrastructure-agnostic: No provider-specific resources (no `aws_*`, `kubernetes_*`)

**Layer 2: Infrastructure Base Modules (Instance-Specific)**
- Implemented as **Terraform modules** containing:
  - `main.tf`: Provider-specific resources (EC2, K8s pods, IAM, security groups)
  - `variables.tf`: Contract inputs (workspace_name, owner, compute_profile)
  - `outputs.tf`: Contract outputs (agent_endpoint, env_vars, volume_mounts)
  - `capabilities.tf`: Capability implementations
- Published to an **instance-scoped Git repository** or Terraform registry
- Contains all infrastructure primitives for the specific Coder instance

**Layer 3: Composed Coder Template**
- The final **Coder template** (what users see in Coder UI) is a Terraform configuration that:
  1. Sources the toolchain template module (for toolchain/bootstrap logic)
  2. Sources the infrastructure base module (for compute/networking)
  3. Wires them together via the contract interface
  4. Registers with Coder via `coderd_template` resource

```hcl
# Example: Composed Coder Template (pod-swdev)
# This is what gets deployed to Coder

module "toolchain" {
  source  = "git::https://github.com/org/toolchain-templates.git//swdev-toolchain?ref=v1.2.0"
  
  # Capability requests (passed to infrastructure base)
  compute_profile = var.compute_profile
  capabilities    = ["persistent-home", "outbound-https"]
}

module "infra" {
  source  = "git::https://github.com/org/coder-instance-a/base-modules.git//base-k8s?ref=v3.1.0"
  
  # Contract inputs
  workspace_name  = data.coder_workspace.me.name
  owner           = data.coder_workspace_owner.me.name
  compute_profile = var.compute_profile
  image_id        = module.toolchain.image_id
  
  # Capability implementations
  persistent_home = true
  network_egress  = "https-only"
}

# Coder agent configuration
resource "coder_agent" "main" {
  os   = module.infra.os
  arch = module.infra.arch
  
  startup_script = module.toolchain.bootstrap_script
  env            = module.infra.runtime_env
}
```

**Composition Workflow:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Template Composition Flow                            │
│                                                                              │
│  1. Template Author                    2. Platform Owner                     │
│     ┌─────────────────┐                   ┌─────────────────┐               │
│     │ Toolchain Template │                   │ Infrastructure  │               │
│     │ (Git repo)      │                   │ Base Module     │               │
│     │                 │                   │ (Git repo)      │               │
│     │ swdev-toolchain │                   │                 │               │
│     │ @v1.2.0         │                   │ base-k8s@v3.1.0 │               │
│     └────────┬────────┘                   └────────┬────────┘               │
│              │                                     │                        │
│              └──────────────┬──────────────────────┘                        │
│                             │                                               │
│                             ▼                                               │
│  3. Composition (CI/CD or Admin)                                            │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │ Composed Template (Terraform)                                    │    │
│     │                                                                  │    │
│     │ - Sources toolchain module                                        │    │
│     │ - Sources infrastructure base module                             │    │
│     │ - Validates capability contract                                  │    │
│     │ - Records provenance (versions, digests)                         │    │
│     └────────────────────────────┬────────────────────────────────────┘    │
│                                  │                                          │
│                                  ▼                                          │
│  4. Deployment to Coder                                                     │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │ coderd_template resource                                         │    │
│     │                                                                  │    │
│     │ - Pushes composed template to Coder                              │    │
│     │ - Configures ACLs via coderd_template_acl                        │    │
│     │ - Manages versions via Terraform state                           │    │
│     └─────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Key Design Decisions:**

1. **Why Terraform modules?** Coder templates are already Terraform-based. Using modules for both layers provides:
   - Native composition via `module` blocks
   - Version pinning via Git refs or registry versions
   - Familiar tooling for platform teams

2. **Why separate Git repos?** 
   - Toolchain templates: Central catalog, shared across instances
   - Infrastructure bases: Per-instance, contains environment-specific secrets/configs

3. **Contract enforcement:** Validated at composition time via:
   - Terraform variable validation
   - CI/CD pipeline checks
   - Optional OPA/Sentinel policies

#### Composition and Resolution

When deploying a workspace:

1. **Admin Selection**: Instance admin selects toolchain template + infrastructure base pairing
2. **Contract Validation**: System validates capability requirements are satisfied via Terraform variable validation
3. **Override Application**: Controlled overrides applied (compute profile, optional capabilities)
4. **Resolution Recording**: Composed template records:
   - Toolchain template version (e.g., `swdev-toolchain@1.2.0`)
   - Infrastructure base version (e.g., `base-k8s@3.1.0`)
   - Resolved artifact IDs (image digests, AMI IDs)
5. **Deployment**: Resolved template deployed to Coder via `coderd_template` resource

#### Versioning Strategy

| Layer | Versioning | Update Frequency |
|-------|------------|------------------|
| Toolchain Templates | Semantic versioning via Git tags (e.g., v1.2.0) | As needed for toolchain/CVE updates |
| Infrastructure Bases | Semantic versioning via Git tags (e.g., v3.1.0) | Per instance, platform owner controlled |
| Contract | Major version only (e.g., 1.0) | Rarely, breaking changes only |

**Upgrade Channels:**
- `stable`: Production-ready, fully tested (Git branch or tag)
- `beta`: Pre-release testing (Git branch)
- `pinned`: Locked to specific version (Git tag ref)

### Interface Definitions

#### External Interfaces (Internet-facing via NLB)

| Interface | Protocol | Port | Source | Path | Destination |
|-----------|----------|------|--------|------|-------------|
| User Dashboard/API | HTTPS | 443 | Internet Clients | → NLB | coderd |
| DERP Relay (external) | HTTPS | 443 | External Clients | → NLB | coderd (built-in DERP) |
| STUN | UDP | 3478 | External Clients | → NLB | coderd |
| Workspace Agent (EC2) | HTTPS | 443 | EC2 Workspaces | → NAT GW → Internet → NLB | coderd |
| IDP Auth (outbound) | HTTPS | 443 | coderd | → NAT GW → Internet | IDP |

#### Internal Interfaces (within VPC/EKS)

| Interface | Protocol | Port | Source | Destination |
|-----------|----------|------|--------|-------------|
| Database | PostgreSQL | 5432 | coderd | Aurora |
| Provisioner API | gRPC | 443 | provisioner pods | coderd (K8s Service) |
| Workspace Agent (Pod) | HTTPS | 443 | Pod Workspaces | coderd (K8s Service) |
| DERP Relay (internal) | HTTPS | 443 | Pod Workspaces | coderd (K8s Service) |
| Kubernetes API | HTTPS | 443 | All pods | EKS API (VPC Endpoint) |
| Metrics | HTTP | 2112 | Prometheus | coderd |

**Traffic Flow Notes:**
- **Pod workspaces** communicate with coderd via internal Kubernetes networking (no NAT/NLB needed)
- **EC2 workspaces** egress through NAT Gateway, traverse the internet, and enter via NLB to reach coderd
- **External clients** (IDE extensions, CLI) connect through NLB for both control plane and DERP relay
- **DERP relay** is built into coderd and handles workspace-to-client tunneling when direct P2P fails
- **STUN** enables NAT traversal discovery for direct P2P connections between clients and workspaces

```
Workspace Connectivity Flows:

1. Pod Workspace → coderd (internal):
   [Pod WS] → K8s Service → [coderd pods]

2. EC2 Workspace → coderd (external path):
   [EC2 WS] → NAT GW → Internet → NLB → [coderd pods]

3. External Client → Workspace (via DERP relay):
   [Client] → NLB → [coderd/DERP] ← K8s Service ← [Pod WS]
   [Client] → NLB → [coderd/DERP] ← NLB ← NAT GW ← [EC2 WS]

4. External Client → Workspace (direct P2P after STUN):
   [Client] ←──── P2P (UDP) ────→ [Workspace]
```

## Data Models

### Workspace T-Shirt Sizes

| Size | vCPU | RAM | Storage | Target User |
|------|------|-----|---------|-------------|
| SW Dev Small | 2 | 4GB | 20GB | Light development |
| SW Dev Medium | 4 | 8GB | 50GB | Standard development |
| SW Dev Large | 8 | 16GB | 100GB | Heavy development |
| Platform/DevSecOps | 4 | 8GB | 100GB | Infrastructure work |
| Data Sci Standard | 8 | 32GB | 500GB | Data analysis |
| Data Sci Large | 16 | 64GB | 1TB | ML training (GPU opt) |
| Data Sci XLarge | 32 | 64GB | 2TB | Large ML (1-N GPUs) |

### Capacity Planning Model

| Metric | Peak (0700-1800 ET) | Off-Hours |
|--------|---------------------|-----------|
| Max Workspaces | 3000 | 300 |
| Max Users | ~1000 | ~100 |
| Workspaces/User | 3 | 3 |
| Avg Workspace Size | 4 vCPU, 8GB, 100GB | Same |

### Node Group Sizing

| Node Group | Instance | Min | Max | Scaling | Purpose |
|------------|----------|-----|-----|---------|---------|
| coder-control | m5.large | 2 | 3 | Static | coderd, observability |
| coder-prov | c5.2xlarge | 0 | 20 | Time-based | External provisioners |
| coder-ws | m5.2xlarge | 10 | 200 | Time-based | Pod workspaces (non-GPU) |

**Design Decision - GPU Workspaces:**
GPU workspaces are provisioned as EC2 instances rather than EKS pods for the following reasons:

1. **Cost Optimization** - GPU instances (p3, p4, g4dn, g5) are expensive; keeping them idle in a node group is cost-prohibitive
2. **Dynamic Provisioning** - EC2 allows on-demand GPU instance provisioning without maintaining warm capacity
3. **Availability** - GPU capacity is often constrained; EC2 provides flexibility to use multiple instance types/AZs
4. **Alignment with Requirements** - Requirement 14.7a states "GPU nodes are not pre-warmed"

GPU workspace templates (Data Sci Large/XLarge) will use the `ec2-generic-universal` template with GPU instance types (g4dn, g5, p3, p4d) configured. Provisioning time is up to 5 minutes depending on GPU availability.



## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

Based on the prework analysis, the following correctness properties have been identified:

### Property 1: Infrastructure Provisioning Completeness
*For any* valid IaC configuration, executing the infrastructure provisioning SHALL create all required AWS resources (VPC, subnets, NAT gateways, security groups, EKS cluster, Aurora database, NLB) with the specified configurations.
**Validates: Requirements 2.1, 2.2, 2.3, 2.4**

### Property 2: Quota Pre-flight Validation
*For any* deployment configuration, the pre-flight quota check SHALL pass if and only if all required AWS service quotas are available for the specified capacity.
**Validates: Requirements 2a.4**

### Property 3: Workspace Network Isolation
*For any* workspace template in the deployment, the template SHALL include NetworkPolicy configurations that isolate the workspace from other workspaces.
**Validates: Requirements 3.1c**

### Property 4: Static Control Plane Configuration
*For any* deployed Coder control plane, the coderd deployment SHALL have no Horizontal Pod Autoscaler configured, maintaining a static replica count.
**Validates: Requirements 4.1**

### Property 5: Backup Frequency for RPO
*For any* Aurora cluster configuration, automated backups SHALL be configured with a frequency that supports the 15-minute RPO target.
**Validates: Requirements 8.4**

### Property 6: External Provisioner Configuration
*For any* Coder deployment, the Helm values SHALL set internal provisioners to zero AND external provisioner deployments SHALL exist in the cluster.
**Validates: Requirements 11.1**

### Property 7: Template Auto-Stop Configuration
*For any* workspace template (except designated 24x7 templates), auto-start and auto-stop SHALL be enabled and configured.
**Validates: Requirements 5.9**

### Property 8: HTTPS Enforcement
*For any* externally accessible service endpoint in the deployment, the endpoint SHALL use HTTPS with TLS 1.2 or higher.
**Validates: Requirements 12.7, 12.8**

### Property 9: Admin Workspace Access Restriction
*For any* Coder RBAC configuration, Owner and Admin roles SHALL NOT have permissions to access user workspace contents or data.
**Validates: Requirements 12a.10**

### Property 10: T-Shirt Size Template Availability
*For any* deployed Coder instance, workspace templates SHALL exist for all defined t-shirt sizes (SW Dev S/M/L, Platform/DevSecOps, Data Sci Standard/Large/XLarge).
**Validates: Requirements 14.16**

### Property 11: Declarative Configuration Consistency
*For any* Coder configuration managed via the coderd Terraform provider, the deployed state SHALL match the declared Terraform configuration after apply.
**Validates: Requirements 16.3**

### Property 12: DNS Configuration Completeness
*For any* deployment with a configured base domain, Route 53 SHALL contain A/ALIAS records for both the ACCESS_URL and WILDCARD_ACCESS_URL pointing to the NLB.
**Validates: Requirements 6.4**

### Property 13: Toolchain Template Portability
*For any* valid toolchain template, the template SHALL contain no infrastructure-specific details (subnets, security groups, AMI IDs, node selectors) and SHALL only declare capabilities via the contract interface.
**Validates: Requirements 11c.2, 11g.1**

### Property 14: Template Contract Satisfaction
*For any* toolchain template and infrastructure base module pairing, the composition SHALL succeed if and only if all required capabilities declared in the toolchain template are implemented by the infrastructure base module.
**Validates: Requirements 11c.10, 11d.1**

### Property 15: Template Composition Provenance
*For any* deployed workspace, the resolved template SHALL record the toolchain template version, infrastructure base version, and resolved artifact identifiers (image digests, AMI IDs).
**Validates: Requirements 11d.7**

### Property 16: Infrastructure Base Override Validation
*For any* template composition with overrides, the overrides SHALL be policy-validated and SHALL NOT bypass identity bindings, network policy, or privileged execution controls unless explicitly permitted.
**Validates: Requirements 11c.9, 11g.2, 11g.3**

### Property 17: Toolchain Template Semantic Versioning
*For any* toolchain template, toolchain dependency updates SHALL follow semantic versioning with security/CVE updates as patch versions.
**Validates: Requirements 11d.5, 11b.8**

## Error Handling

### Infrastructure Provisioning Errors

| Error Scenario | Detection | Response |
|----------------|-----------|----------|
| Insufficient quotas | Pre-flight check | Block deployment, list required quota increases |
| VPC CIDR conflict | Terraform plan | Fail with conflict details, suggest alternative CIDR |
| EKS creation timeout | Terraform apply | Retry with exponential backoff, alert on failure |
| Aurora provisioning failure | Terraform apply | Rollback, preserve state for debugging |

### Runtime Errors

| Error Scenario | Detection | Response |
|----------------|-----------|----------|
| Database connection failure | Health check | Automatic reconnection, alert after 3 failures |
| Node group scaling failure | CloudWatch alarm | Alert operations, manual intervention |
| Certificate expiration | ACM monitoring | Auto-renewal (ACM), alert 30 days before |
| Provisioner key expiration | Coder audit logs | Alert 14 days before, rotation procedure |

### Operational Alerts

| Alert | Severity | Response Time | Escalation |
|-------|----------|---------------|------------|
| System down | Critical | 15 min | L1 → L2 (30 min) → L3 (1 hr) |
| Degraded service | High | 1 hr | L1 → L2 (2 hr) |
| Minor impact | Medium | 4 hr | L1 |
| Cosmetic/Enhancement | Low | 1 business day | Best effort |

## Testing Strategy

### Dual Testing Approach

This deployment guide and IaC solution requires both unit testing and property-based testing to ensure correctness:

1. **Unit Tests**: Verify specific configurations, edge cases, and error conditions
2. **Property-Based Tests**: Verify universal properties that should hold across all valid inputs

### Unit Testing

Unit tests will be implemented using:
- **Terraform**: `terraform validate`, `terraform plan` assertions, Terratest
- **Helm**: Helm unittest plugin

Unit test coverage:
- VPC CIDR calculations for various capacity inputs
- Security group rule generation
- IAM policy document generation
- Helm values template rendering
- DNS record configuration

### Property-Based Testing

Property-based tests will be implemented using:
- **Terraform**: Custom test harness with randomized inputs via Terratest
- **Configuration validation**: JSON Schema validation with generated test cases

Property test coverage (minimum 100 iterations per property):

| Property | Test Approach |
|----------|---------------|
| Infrastructure Completeness | Generate random valid configs, verify all resources created |
| Quota Validation | Generate configs with varying capacities, verify quota checks |
| Network Isolation | Generate workspace templates, verify NetworkPolicy presence |
| Static Control Plane | Deploy with various configs, verify no HPA |
| HTTPS Enforcement | Enumerate all endpoints, verify TLS configuration |
| Declarative Config Consistency | Apply Terraform, verify deployed state matches declared config |

### Test Annotations

All property-based tests MUST include annotations linking to the design document:
```
**Feature: coder-deployment-guide, Property 1: Infrastructure Provisioning Completeness**
```

### Scale Testing with Coder Scale Utilities

Performance validation will use Coder's built-in scale testing utilities (`coder scaletest`) to validate capacity and latency requirements.

**Scale Test Commands:**

| Test | Command | Validates |
|------|---------|-----------|
| Workspace Creation | `coder scaletest create-workspaces --count 1000 --template <template>` | Req 14.11 (1000 concurrent ops) |
| Workspace Traffic | `coder scaletest workspace-traffic --bytes-per-tick 1024` | Network throughput |
| Dashboard Load | `coder scaletest dashboard` | Req 14.9, 14.10 (API latency) |

**Scale Test Configuration:**
```yaml
# scaletest-config.yaml
create_workspaces:
  count: 1000
  template: pod-generic-universal
  concurrency: 100
  timeout: 30m
  
workspace_traffic:
  bytes_per_tick: 1024
  tick_interval: 100ms
  duration: 10m

dashboard:
  concurrency: 50
  duration: 5m
```

**Performance Acceptance Criteria:**

| Metric | Target | Measurement |
|--------|--------|-------------|
| Workspace provisioning (pod) | < 2 min | `coder scaletest create-workspaces` P95 |
| Workspace provisioning (EC2) | < 5 min | `coder scaletest create-workspaces` P95 |
| API response (P95) | < 500ms | `coder scaletest dashboard` |
| API response (P99) | < 1s | `coder scaletest dashboard` |
| Concurrent provisioning | 1000 ops | `coder scaletest create-workspaces --count 1000` |

**Design Rationale:** Using Coder's official scale utilities ensures consistent, reproducible performance testing aligned with Coder's validated architecture benchmarks.

### Validation Procedures

#### Pre-Deployment Validation
1. Terraform syntax validation (`terraform validate`)
2. Quota pre-flight checks
3. DNS zone ownership verification
4. Certificate availability check
5. Coder Premium license verification

#### Post-Deployment Validation
1. EKS cluster health check
2. Aurora connectivity test
3. Coder API health endpoint
4. Workspace creation smoke test (pod and EC2)
5. Authentication flow test (OIDC + MFA)
6. External auth test (Git provider)
7. Group sync verification
8. API latency baseline (P95 < 500ms, P99 < 1s)

#### Scale Validation (Pre-Production)
1. Run `coder scaletest create-workspaces` with target capacity (1000+ workspaces)
2. Run `coder scaletest dashboard` to validate API latency under load
3. Run `coder scaletest workspace-traffic` to validate network throughput
4. Verify provisioning times meet targets (pod < 2min, EC2 < 5min)
5. Monitor CloudWatch metrics during scale tests for resource utilization

## Deliverables

### Documentation
1. **Deployment Guide** (coder.com/docs)
   - Architecture overview with 6 diagrams
   - Prerequisites and quota requirements
   - Step-by-step deployment procedures
   - Operational runbooks
   - Troubleshooting guide

2. **IaC Repository Documentation**
   - README with quick start
   - Configuration reference
   - Example configurations
   - Upgrade procedures

### Infrastructure as Code

1. **Terraform Repository**
   - Modular structure (vpc, eks, aurora, coder)
   - S3 backend configuration
   - Production tfvars file
   - CI/CD pipeline templates
   - coderd provider configuration for Coder management (Day 1/2 operations)

### Helm Values Files
1. `coder-values.yaml` - Production coderd configuration
2. `coder-provisioner-values.yaml` - External provisioner configuration
3. `observability-values.yaml` - Coder observability stack

### Toolchain Templates (Portable)

| Toolchain Template | Description | Capabilities Required |
|-----------------|-------------|----------------------|
| `swdev-toolchain` | Software development workspace | persistent-home, outbound-https, gui-vnc (optional) |
| `windev-toolchain` | Windows development workspace | persistent-home, gui-rdp |
| `datasci-toolchain` | Data science and ML workspace | persistent-home, outbound-https, gpu-support (optional) |

**Toolchain Template Features:**

1. **swdev-toolchain** - Software development
   - Languages: Go 1.23, Node 22, Python 3.12
   - Tools: terraform, kubectl, gh, docker-cli
   - Libraries: Internal SDKs (configurable)
   - Compute profiles: SW Dev Small/Medium/Large, Platform/DevSecOps
   - Capabilities: persistent-home, outbound-https, gui-vnc (optional)

2. **windev-toolchain** - Windows development
   - Languages: C#, .NET 8
   - Tools: Visual Studio 2022, Git, Azure CLI, PowerShell
   - Compute profiles: SW Dev Medium/Large
   - Capabilities: persistent-home, gui-rdp

3. **datasci-toolchain** - Data science and ML
   - Languages: Python 3.12, R 4.x
   - Tools: Jupyter Lab, CUDA toolkit
   - Libraries: PyTorch, TensorFlow, scikit-learn, pandas
   - Compute profiles: Data Sci Standard/Large/XLarge
   - Capabilities: persistent-home, outbound-https, gpu-support (optional)

### Infrastructure Base Modules (Instance-Specific)

| Base Module | Platform | Description |
|-------------|----------|-------------|
| `base-k8s` | EKS Pod | Kubernetes pod-based workspace infrastructure |
| `base-ec2-linux` | EC2 | Linux EC2 workspace infrastructure |
| `base-ec2-windows` | EC2 | Windows EC2 workspace infrastructure with DCV/WebRDP |
| `base-ec2-gpu` | EC2 | GPU-enabled EC2 workspace infrastructure |

**Infrastructure Base Module Features:**

1. **base-k8s** - Kubernetes pod workspaces
   - Namespace: coder-ws
   - Node selector: coder-ws node pool
   - Storage: EBS-backed PVC for /home/coder
   - Network: NetworkPolicy for workspace isolation
   - Identity: Kubernetes service account with IRSA
   - GUI: KasmVNC sidecar (when gui-vnc capability requested)
   - OS options: Amazon Linux 2023, Ubuntu 22.04/24.04

2. **base-ec2-linux** - Linux EC2 workspaces
   - AMI: Amazon Linux 2023, Ubuntu 22.04/24.04 (hardened)
   - IAM: Instance role with least-privilege permissions
   - Security groups: Workspace isolation rules
   - Storage: EBS gp3 for /home/coder persistence
   - GUI: KasmVNC (when gui-vnc capability requested)

3. **base-ec2-windows** - Windows EC2 workspaces
   - AMI: Windows Server 2022 (hardened)
   - Remote desktop: NICE DCV (recommended) or WebRDP
   - IAM: Instance role with least-privilege permissions
   - Security groups: Workspace isolation rules
   - Storage: EBS gp3 for user data persistence

4. **base-ec2-gpu** - GPU EC2 workspaces
   - AMI: CUDA-enabled Amazon Linux 2023 or Ubuntu 22.04
   - Instance types: g4dn (inference), g5 (training), p3/p4d (large-scale ML)
   - CUDA: Pre-installed drivers and toolkit
   - IAM: Instance role with least-privilege permissions
   - Note: GPU nodes not pre-warmed, provisioning up to 5 min

### Template Composition Examples

| Use Case | Toolchain Template | Infrastructure Base | Result |
|----------|-----------------|---------------------|--------|
| Pod-based SW dev | swdev-toolchain@1.2.0 | base-k8s@3.1.0 | pod-swdev workspace |
| EC2 Linux SW dev | swdev-toolchain@1.2.0 | base-ec2-linux@2.0.0 | ec2-swdev workspace |
| Windows dev | windev-toolchain@1.0.0 | base-ec2-windows@2.1.0 | ec2-windev-gui workspace |
| Data science (CPU) | datasci-toolchain@1.1.0 | base-ec2-linux@2.0.0 | ec2-datasci workspace |
| Data science (GPU) | datasci-toolchain@1.1.0 | base-ec2-gpu@1.5.0 | ec2-datasci-gpu workspace |

## References

### Coder Documentation
- [Coder Installation](https://coder.com/docs/install)
- [External Provisioners](https://coder.com/docs/admin/provisioners)
- [High Availability](https://coder.com/docs/admin/networking/high-availability)
- [Validated Architectures](https://coder.com/docs/admin/infrastructure/validated-architectures)
- [Scale Testing Utility](https://coder.com/docs/admin/infrastructure/scale-utility)
- [Networking](https://coder.com/docs/admin/networking)
- [Security Best Practices](https://coder.com/docs/tutorials/best-practices/security-best-practices)
- [OIDC Authentication](https://coder.com/docs/admin/users/oidc-auth)
- [External Authentication](https://coder.com/docs/admin/external-auth)
- [Quotas](https://coder.com/docs/admin/users/quotas)
- [Licensing](https://coder.com/docs/admin/licensing)
- [Template Registry](https://registry.coder.com)
- [Template Development](https://coder.com/docs/templates)
- [Workspace Parameters](https://coder.com/docs/templates/parameters)

### AWS Documentation
- [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Amazon Aurora User Guide](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/)
- [Amazon VPC User Guide](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Amazon EBS CSI Driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)
- [IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/)
- [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/)
