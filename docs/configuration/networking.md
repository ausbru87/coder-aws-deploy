# Network Architecture and Configuration

This document provides a deep-dive into VPC networking architecture for Coder AWS deployments.

## Overview

The Coder deployment uses a multi-tier VPC architecture with isolated subnets for different components.

## VPC Structure

```
VPC: 10.0.0.0/16 (65,536 IPs)
├── Public Subnets (3 x /20 = 12,288 IPs)
│   └── NAT Gateways, NLB ENIs
├── Control Plane Subnets (3 x /20 = 12,288 IPs)
│   └── coderd nodes
├── Provisioner Subnets (3 x /20 = 12,288 IPs)
│   └── provisioner nodes
├── Workspace Subnets (3 x /19 = 24,576 IPs)
│   └── workspace nodes (largest allocation for pod IPs)
└── Database Subnets (3 x /24 = 768 IPs)
    └── Aurora PostgreSQL instances
```

## Subnet Sizing

See [Architecture Overview](../getting-started/overview.md) for complete CIDR allocation details.

## Security Groups

- **Control Plane SG**: Allows coderd API traffic (HTTPS)
- **Provisioner SG**: Allows provisioner-to-coderd communication
- **Workspace SG**: Allows workspace egress (filtered), SSH/HTTP/HTTPS
- **Database SG**: Allows PostgreSQL from EKS nodes only
- **NLB SG**: Allows HTTPS (443) and STUN (3478) inbound

## VPC Endpoints

When enabled (`enable_vpc_endpoints = true`), the following VPC endpoints reduce NAT Gateway costs:

- ec2
- ecr.api
- ecr.dkr
- s3
- logs
- sts

## NAT Gateway Architecture

- 1 NAT Gateway per AZ (3 total for SR-HA)
- Each private subnet routes through its AZ's NAT Gateway
- 5 Gbps burst, 45 Gbps sustained capacity per NAT Gateway

## Network Load Balancer

- Cross-zone load balancing enabled
- TLS termination with ACM certificate
- Health checks on `/healthz` endpoint
- STUN protocol support (UDP 3478)

## Related Documentation

- [Architecture Overview](../getting-started/overview.md)
- [Compute Configuration](./compute.md)
- [Variable Reference](./variables.md)
