# Compute Architecture and Configuration

This document covers EKS cluster configuration, node groups, and auto-scaling for Coder deployments.

## EKS Cluster

- **Version:** 1.31
- **Control Plane:** Managed by AWS (multi-AZ)
- **Networking:** VPC CNI with custom networking
- **Authentication:** IAM + OIDC

## Node Groups

### Control Node Group (coderd)

- **Instance Type:** m5.large (2 vCPU, 8 GB RAM)
- **Min/Max Size:** 2-3 (SR-HA), 1-2 (SR-Simple)
- **Node Type:** On-demand only
- **Purpose:** Runs coderd replicas

### Provisioner Node Group

- **Instance Type:** c5.2xlarge (8 vCPU, 16 GB RAM)
- **Min/Max Size:** 0-20
- **Node Type:** On-demand
- **Purpose:** Workspace provisioning operations
- **Scaling:** Time-based (if enabled) + manual

### Workspace Node Group

- **Instance Type:** m5.2xlarge (8 vCPU, 32 GB RAM)
- **Min/Max Size:** 10-200
- **Node Type:** Spot (with on-demand fallback)
- **Purpose:** Runs workspace pods
- **Scaling:** Time-based (if enabled) + Karpenter

## Time-Based Scaling

When `time_based_scaling = true`:

- **Scale Up:** 06:45 ET (Monday-Friday)
- **Scale Down:** 18:15 ET (Monday-Friday)
- **Desired Peak Counts:**
  - Provisioner nodes: 5
  - Workspace nodes: 50

See [SR-HA Time-Based Scaling](../deployment-patterns/sr-ha/time-based-scaling.md) for configuration details.

## Karpenter Auto-Scaling (Future)

Future versions will use Karpenter for dynamic workspace node provisioning.

## Related Documentation

- [Architecture Overview](../getting-started/overview.md)
- [Networking](./networking.md)
- [SR-HA Capacity Planning](../deployment-patterns/sr-ha/capacity-planning.md)
