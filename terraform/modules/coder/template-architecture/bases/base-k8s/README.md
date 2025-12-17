# Base-K8s Infrastructure Module

Kubernetes pod-based workspace infrastructure module for Coder. This module implements the infrastructure base layer for EKS pod workspaces.

## Overview

This module provisions Kubernetes resources for Coder workspaces including:
- Pod deployment with configurable compute resources
- Persistent volume claim for /home/coder
- Service account with IRSA for AWS API access
- NetworkPolicy for workspace isolation
- Optional KasmVNC sidecar for GUI workspaces

## Requirements Covered

| Requirement | Description | Implementation |
|-------------|-------------|----------------|
| 11.5 | Deploy base-k8s module | This module |
| 11.6 | KasmVNC for GUI workspaces | gui_vnc capability |
| 11.7 | Headless workspaces | Default mode |
| 11.8 | OS options | amazon-linux-2023, ubuntu-22.04/24.04 |
| 11a.1 | Persist /home/coder | PVC with EBS storage |
| 3.1c | Workspace isolation | NetworkPolicy |
| 13.1-13.3 | Auto-start/auto-stop | replica_count variable |

## Supported Capabilities

| Capability | Supported | Notes |
|------------|-----------|-------|
| persistent-home | ✅ | EBS-backed PVC |
| network-egress | ✅ | none, https-only, unrestricted |
| identity-mode | ✅ | iam (IRSA), oidc, workload-identity |
| gpu-support | ❌ | Use base-ec2-gpu module |
| artifact-cache | ✅ | Shared PVC mount |
| secrets-injection | ✅ | variables, secrets-manager |
| gui-vnc | ✅ | KasmVNC sidecar |
| gui-rdp | ❌ | Windows not supported on K8s |

## Usage

```hcl
module "workspace_infra" {
  source = "./modules/coder/template-architecture/bases/base-k8s"

  # Contract inputs
  workspace_name = data.coder_workspace.me.name
  owner          = data.coder_workspace_owner.me.name
  
  compute_profile = {
    cpu     = 4
    memory  = "8Gi"
    storage = "50Gi"
  }
  
  image_id = "codercom/enterprise-base:ubuntu"
  
  capabilities = {
    persistent_home = true
    network_egress  = "https-only"
    identity_mode   = "iam"
    gui_vnc         = false
  }

  toolchain_template = {
    name    = "swdev-toolchain"
    version = "1.2.0"
  }

  # Kubernetes-specific
  namespace              = "coder-ws"
  storage_class          = "gp3-encrypted"
  workspace_iam_role_arn = "arn:aws:iam::123456789012:role/CoderWorkspaceRole"
  coder_agent_token      = coder_agent.main.token
  startup_command        = ["sh", "-c", coder_agent.main.init_script]
}
```

## Inputs

### Contract Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| workspace_name | string | yes | Workspace name |
| owner | string | yes | Workspace owner username |
| compute_profile | object | yes | CPU, memory, storage allocation |
| image_id | string | no | Container image (defaults to OS-based) |
| capabilities | object | no | Requested capabilities |
| toolchain_template | object | yes | Toolchain template info |
| base_module | object | no | Base module info |
| overrides | object | no | Environment variables, labels, annotations |

### Kubernetes-Specific Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| namespace | string | "coder-ws" | Kubernetes namespace |
| storage_class | string | "gp3-encrypted" | Storage class for PVC |
| workspace_iam_role_arn | string | "" | IAM role ARN for IRSA |
| os_type | string | "ubuntu-22.04" | Operating system |
| replica_count | number | 1 | Pod replicas (0 = stopped) |
| coder_agent_token | string | "" | Coder agent token |

## Outputs

### Contract Outputs

| Name | Type | Description |
|------|------|-------------|
| agent_endpoint | string | Coder agent endpoint |
| runtime_env | map(string) | Environment variables |
| volume_mounts | list(object) | Volume mount configuration |
| metadata | object | Provenance and tracking data |

### Kubernetes-Specific Outputs

| Name | Type | Description |
|------|------|-------------|
| deployment_name | string | Kubernetes deployment name |
| namespace | string | Kubernetes namespace |
| service_account_name | string | Service account name |
| pvc_name | string | PVC name (if persistent) |
| vnc_service_name | string | VNC service name (if GUI) |

## Network Policy

The module creates a NetworkPolicy that:
- Allows ingress only from the Coder control plane namespace
- Controls egress based on the `network_egress` capability:
  - `none`: No outbound access (DNS only)
  - `https-only`: HTTPS (443) egress only
  - `unrestricted`: Full outbound access

## Auto-Start/Auto-Stop

Workspace lifecycle is controlled via the `replica_count` variable:
- `1`: Workspace running
- `0`: Workspace stopped

Coder manages this automatically based on auto-start/auto-stop schedules (0700/1800 ET).

## Security

- Pods run as non-root user (UID 1000)
- Privilege escalation disabled
- NetworkPolicy enforces workspace isolation
- IRSA provides least-privilege AWS access
- Encrypted EBS volumes for persistent storage
