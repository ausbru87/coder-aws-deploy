# Template Governance CI/CD

This directory contains CI/CD pipeline configurations and documentation for template governance.

## Overview

The template governance CI/CD system ensures that:
- Toolchain templates are validated, tested, and approved before publishing
- Infrastructure base modules are validated and approved before deployment
- Security scanning is performed on all template artifacts
- Approval gates enforce proper governance

## Requirements Covered

| Requirement | Description | Implementation |
|-------------|-------------|----------------|
| 11b.1 | Templates stored in Git repositories | Repository structure |
| 11b.2 | Toolchain templates validated via CI/CD | `toolchain-ci.yml` |
| 11b.3 | Infrastructure bases validated via CI/CD | `infra-base-ci.yml` |
| 11b.4 | Platform owner and security approval for toolchains | Approval gates |
| 11b.5 | Platform owner approval for infrastructure bases | Approval gates |
| 11f.3 | Validate templates locally before publishing | Lint and contract checks |
| 11f.4 | Publish toolchain templates to central catalog | Publishing workflow |
| 11e.3 | Upgrade channels (stable, beta, pinned) | Branch/tag strategy |
| 12b.1-12b.7 | Template access control and lifecycle | Documentation |

## Directory Structure

```
ci-cd/
├── README.md                           # This file
├── docs/
│   ├── ci-cd-requirements.md          # Platform-agnostic CI/CD requirements
│   ├── approval-gates.md              # Approval gate configuration
│   └── upgrade-channels.md            # Upgrade channel management
├── github-actions/                     # GitHub Actions examples
│   ├── toolchain-ci.yml               # Toolchain template CI workflow
│   ├── infra-base-ci.yml              # Infrastructure base CI workflow
│   ├── template-publish.yml           # Template publishing workflow
│   └── security-scan.yml              # Security scanning workflow
└── scripts/
    ├── validate-toolchain.sh          # Toolchain validation script
    ├── validate-infra-base.sh         # Infrastructure base validation script
    ├── contract-check.sh              # Contract validation script
    └── security-scan.sh               # Security scanning script
```

## Quick Start

### For GitHub Actions

1. Copy the workflow files from `github-actions/` to your repository's `.github/workflows/` directory
2. Configure the required secrets (see workflow files for details)
3. Set up branch protection rules with required approvals
4. Configure environments for approval gates

### For Other CI/CD Platforms

See `docs/ci-cd-requirements.md` for platform-agnostic requirements that can be implemented in any CI/CD system.

## Workflow Overview

### Toolchain Template Pipeline

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Commit    │───▶│   Validate  │───▶│  Security   │───▶│  Approval   │
│   Push      │    │   & Lint    │    │    Scan     │    │    Gate     │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                │
                                                                ▼
                   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
                   │   Deploy    │◀───│   Publish   │◀───│   Build     │
                   │  to Coder   │    │  to Catalog │    │  Artifacts  │
                   └─────────────┘    └─────────────┘    └─────────────┘
```

### Infrastructure Base Pipeline

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Commit    │───▶│  Terraform  │───▶│  Security   │───▶│  Platform   │
│   Push      │    │  Validate   │    │    Scan     │    │   Owner     │
└─────────────┘    └─────────────┘    └─────────────┘    │  Approval   │
                                                         └─────────────┘
                                                                │
                                                                ▼
                                      ┌─────────────┐    ┌─────────────┐
                                      │   Deploy    │◀───│   Publish   │
                                      │  to Coder   │    │  to Registry│
                                      └─────────────┘    └─────────────┘
```

## Approval Gates

| Template Type | Required Approvers | Approval Count |
|---------------|-------------------|----------------|
| Toolchain Templates | Platform Owner + Security | 2 |
| Infrastructure Bases | Platform Owner | 1 |
| CVE/Security Patches | Security Team | 1 (expedited) |

## Upgrade Channels

| Channel | Branch/Tag Pattern | Description |
|---------|-------------------|-------------|
| `stable` | `main` or `release/*` | Production-ready, fully tested |
| `beta` | `beta/*` | Pre-release testing |
| `pinned` | `v*.*.*` tags | Locked to specific version |
