# Coder AWS Deployment Documentation

Welcome to the Coder AWS deployment documentation. This guide provides comprehensive information for deploying and operating Coder on Amazon Web Services.

## Quick Links

- **New to Coder?** → Start with [Architecture Overview](./getting-started/overview.md)
- **Ready to deploy?** → [Quick Start Guide](./getting-started/quickstart.md)
- **Choosing a pattern?** → [Pattern Selection Guide](./getting-started/choosing-a-pattern.md)
- **Need help?** → [Troubleshooting](./operations/troubleshooting.md) | [FAQ](./reference/faq.md)

## Documentation Structure

This documentation is organized by user journey and operational phases:

```
Getting Started → Deployment Patterns → Configuration → Operations → Reference
```

## 📚 Getting Started

Start here if you're new to Coder AWS deployments or need to understand the architecture.

| Document | Description | Time to Read |
|----------|-------------|--------------|
| [Architecture Overview](./getting-started/overview.md) | Infrastructure components, network architecture, data flow | 15 min |
| [Choosing a Pattern](./getting-started/choosing-a-pattern.md) | Decision guide for SR-HA vs SR-Simple | 10 min |
| [Prerequisites](./getting-started/prerequisites.md) | Required tools, AWS quotas, licenses, IDP configuration | 10 min |
| [Quick Start](./getting-started/quickstart.md) | Deploy SR-HA in 60 minutes | 60 min |

**Typical journey:** Overview → Prerequisites → Choosing a Pattern → Quick Start

## 🎯 Deployment Patterns

Choose your deployment pattern based on team size, availability requirements, and budget.

### SR-HA (Single Region High Availability) ✅ Production-Ready (v1.0)

**Best for:** Production workloads, 100-500 users, ~$3,000/month

| Document | Description |
|----------|-------------|
| [SR-HA Overview](./deployment-patterns/sr-ha/overview.md) | Pattern characteristics, architecture, cost breakdown |
| [SR-HA Deployment Guide](./deployment-patterns/sr-ha/deployment.md) | Step-by-step deployment (phases 1-5) |
| [Time-Based Scaling](./deployment-patterns/sr-ha/time-based-scaling.md) | Auto-scaling configuration (06:45-18:15 ET) |
| [Capacity Planning](./deployment-patterns/sr-ha/capacity-planning.md) | Performance targets, scale testing procedures |
| [SR-HA Operations](./deployment-patterns/sr-ha/operations.md) | Day 2 operations, incident response, runbooks |

### SR-Simple (Single Region Simple) 🚧 Planned (v2.0)

**Best for:** Development/testing, <20 users, ~$600/month

| Document | Description |
|----------|-------------|
| [SR-Simple Overview](./deployment-patterns/sr-simple/overview.md) | Single-AZ deployment, cost optimization |
| [SR-Simple Deployment](./deployment-patterns/sr-simple/deployment.md) | 30-minute deployment guide |
| [When to Use SR-Simple](./deployment-patterns/sr-simple/when-to-use.md) | Use case guidance and decision framework |

## ⚙️ Configuration

Detailed configuration references for infrastructure components and feature flags.

### Core Configuration

| Document | Description |
|----------|-------------|
| [Feature Flags](./configuration/feature-flags.md) | `deployment_features` object explained |
| [Variables Reference](./configuration/variables.md) | Complete Terraform variable reference |
| [Networking](./configuration/networking.md) | VPC, subnets, security groups, NAT Gateway |
| [Compute](./configuration/compute.md) | EKS cluster, node groups, time-based scaling |
| [Database](./configuration/database.md) | Aurora Serverless v2, capacity, backups |
| [Observability](./configuration/observability.md) | CloudWatch logs, metrics, alerts, Container Insights |

### Authentication & Access Control

| Document | Description |
|----------|-------------|
| [Authentication](./configuration/authentication.md) | OIDC/SAML setup (GitHub, Google, Okta, Azure AD) |
| [RBAC Configuration](./configuration/rbac.md) | Role definitions, permission matrix, workspace access |

## 🔧 Operations

Operational guides for Day 0 (deployment), Day 1 (configuration), and Day 2 (ongoing operations).

### Deployment Operations (Day 0)

| Document | Description |
|----------|-------------|
| [Day 0: Deployment](./operations/day0-deployment.md) | Phases 1-5: Infrastructure deployment, verification |

### Configuration Operations (Day 1)

| Document | Description |
|----------|-------------|
| [Day 1: Configuration](./operations/day1-configuration.md) | Phases 6-8: First admin user, OIDC, templates, smoke tests |

### Ongoing Operations (Day 2)

| Document | Description |
|----------|-------------|
| [Day 2: Operations](./operations/day2-operations.md) | Platform restore, scaling, monthly backup testing |
| [Scaling Procedures](./operations/scaling.md) | Manual scaling, scale testing, monitoring |
| [Upgrades](./operations/upgrades.md) | Coder version, EKS cluster, template, infrastructure upgrades |
| [Troubleshooting](./operations/troubleshooting.md) | Common errors, debug commands, log collection |

### Security Operations

| Document | Description |
|----------|-------------|
| [Provisioner Key Rotation](./operations/provisioner-key-rotation.md) | Key rotation procedures, expiration alerts |
| [Token Management](./operations/token-management.md) | CI/CD service account tokens, lifecycle management |

## 📖 Reference

Technical reference documentation for architecture decisions, AWS services, costs, and templates.

### Architecture & Design

| Document | Description |
|----------|-------------|
| [Architecture Decisions (ADRs)](./reference/architecture-decisions.md) | Key architectural decisions and rationale |
| [AWS Services Used](./reference/aws-services.md) | Complete list of AWS services, quotas, IAM permissions |
| [Cost Estimation](./reference/cost-estimation.md) | Detailed cost breakdowns by pattern, optimization strategies |
| [FAQ](./reference/faq.md) | Frequently asked questions |

### Module & Template Reference

| Document | Description |
|----------|-------------|
| [Module Reference](./reference/module-reference.md) | AWS and Coderd provider modules |
| [Template Contract](./reference/template-contract.md) | Workspace template interface specification |
| [Compliance Controls](./reference/compliance-controls.md) | Security controls, SoD, compliance checklist |

## 🎓 Common User Journeys

### Journey 1: New Production Deployment (SR-HA)

```
1. Read Architecture Overview (15 min)
2. Check Prerequisites (10 min)
3. Review SR-HA Overview (10 min)
4. Follow Quick Start Guide (60 min)
5. Complete Day 1 Configuration (30 min)
6. Bookmark Day 2 Operations for ongoing management
```

**Total time:** ~2 hours  
**Cost:** ~$3,000/month

### Journey 2: Development Environment (SR-Simple)

```
1. Read Choosing a Pattern (10 min)
2. Read SR-Simple Overview (10 min)
3. Check Prerequisites (10 min)
4. Follow SR-Simple Deployment (30 min) [Coming in v2.0]
```

**Total time:** ~1 hour  
**Cost:** ~$600/month

## 🔍 Finding What You Need

### By Role

**Platform Operators / SREs:**
- [Day 2 Operations](./operations/day2-operations.md)
- [Troubleshooting](./operations/troubleshooting.md)
- [Scaling Procedures](./operations/scaling.md)
- [Upgrades](./operations/upgrades.md)

**Infrastructure Engineers:**
- [Architecture Overview](./getting-started/overview.md)
- [Networking](./configuration/networking.md)
- [Compute](./configuration/compute.md)
- [Database](./configuration/database.md)

**Security Engineers:**
- [Compliance Controls](./reference/compliance-controls.md)
- [Authentication](./configuration/authentication.md)
- [RBAC Configuration](./configuration/rbac.md)

**Finance / Budget Owners:**
- [Cost Estimation](./reference/cost-estimation.md)
- [Choosing a Pattern](./getting-started/choosing-a-pattern.md) (includes cost comparison)

### By Problem

**"Workspaces are slow to provision"**
→ [Troubleshooting: Workspace Provisioning Slow](./operations/troubleshooting.md#workspace-provisioning-slow)

**"How do I reduce costs?"**
→ [Cost Optimization Strategies](./reference/cost-estimation.md#cost-optimization-strategies)

**"I need to scale for an event"**
→ [Scaling Procedures](./operations/scaling.md#manual-scaling)

**"Database is running out of connections"**
→ [Troubleshooting: Database Connection Exhaustion](./deployment-patterns/sr-ha/operations.md#database-connection-exhaustion)

**"I need to upgrade Coder"**
→ [Upgrade Procedures: Coder Version](./operations/upgrades.md#coder-version-upgrade)

## 🗺️ Roadmap

### v1.0 (Current) - SR-HA Pattern ✅

- ✅ Single Region High Availability deployment
- ✅ Time-based auto-scaling
- ✅ Spot instance support
- ✅ Aurora Serverless v2
- ✅ Feature flag architecture
- ✅ Comprehensive documentation

### v2.0 (Planned) 🚧

- 🚧 SR-Simple pattern (dev/test)
- 🚧 Karpenter auto-scaling (replace time-based)
- 🚧 Terraform Registry publication

### Future Considerations

- Support for existing VPC/Aurora
- ARM64 node support (Graviton instances)
- Multi-cloud abstractions (Azure, GCP)
- Workspace auto-suspend policies
- Cost anomaly detection

## 🤝 Contributing

Contributions welcome! To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

**Good contributions:**
- Bug fixes
- Documentation improvements
- New deployment pattern examples
- Performance optimizations

**Coordinate first (via GitHub issue) for:**
- New features
- Breaking changes
- Architecture changes

## 📞 Getting Help

### Self-Service

1. Check [FAQ](./reference/faq.md)
2. Search [Troubleshooting Guide](./operations/troubleshooting.md)
3. Review [Architecture Decisions](./reference/architecture-decisions.md)

### Community Support

- **GitHub Issues:** Report bugs or request features
- **Coder Discord:** Community support and discussions
- **Coder Docs:** Official Coder documentation at https://coder.com/docs

### Enterprise Support

Contact Coder sales for:
- Production support SLAs
- Architecture consulting
- Custom feature development
- Training and onboarding

## 📄 License

[Add license information here]

## 🏷️ Version

**Documentation Version:** 1.0.0  
**Last Updated:** 2025-01-15  
**Coder Version Tested:** 2.13.0  
**Terraform Version Required:** >= 1.9.0  
**AWS Provider Version:** >= 5.0.0
