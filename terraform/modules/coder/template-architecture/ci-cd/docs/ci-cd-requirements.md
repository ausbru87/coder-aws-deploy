# Template Governance CI/CD Requirements

This document defines the platform-agnostic CI/CD requirements for template governance. These requirements can be implemented in any CI/CD system (GitHub Actions, GitLab CI, Jenkins, AWS CodePipeline, etc.).

## Overview

The template governance CI/CD system ensures that all templates (toolchain templates and infrastructure base modules) go through proper validation, security scanning, and approval before deployment.

## Requirements Reference

| Requirement | Description |
|-------------|-------------|
| 11b.1 | Templates stored in Git repositories |
| 11b.2 | Toolchain templates validated via CI/CD |
| 11b.3 | Infrastructure bases validated via CI/CD |
| 11b.4 | Platform owner and security approval for toolchains |
| 11b.5 | Platform owner approval for infrastructure bases |
| 11b.6 | Changes follow same workflow as new templates |
| 11b.7 | All modifications traceable through Git and approvals |
| 11b.8 | Toolchain owners handle CVE updates in toolchain layer |
| 11b.9 | Platform owners handle infrastructure security patches |
| 11f.3 | Validate templates locally before publishing |
| 11f.4 | Publish toolchain templates to central catalog |
| 11e.3 | Maintain upgrade channels (stable, beta, pinned) |

## Pipeline Stages

### Stage 1: Validation

**Purpose:** Ensure templates are syntactically correct and follow standards.

**Required Checks:**
1. **YAML Syntax Validation** - Validate `toolchain.yaml` files
2. **Terraform Validation** - Run `terraform init` and `terraform validate`
3. **Format Check** - Run `terraform fmt -check`
4. **Contract Validation** - Verify templates implement required interfaces
5. **Lint Check** - Run tflint or equivalent

**Trigger:** On every push and pull request

**Exit Criteria:** All validation checks pass

### Stage 2: Security Scanning

**Purpose:** Identify security vulnerabilities and misconfigurations.

**Required Scans:**
1. **Vulnerability Scanning** - Scan for known CVEs (Trivy, Snyk, etc.)
2. **IaC Security Scanning** - Scan Terraform for misconfigurations (tfsec, Checkov, Terrascan)
3. **Secret Scanning** - Detect hardcoded secrets (Gitleaks, TruffleHog)
4. **Container Scanning** - Scan container images if applicable
5. **SBOM Generation** - Generate Software Bill of Materials

**Trigger:** After validation passes

**Exit Criteria:** No critical/high vulnerabilities (configurable threshold)

### Stage 3: Build Artifacts

**Purpose:** Build and package template artifacts.

**Required Actions:**
1. **Container Image Build** - Build container images if Dockerfile exists
2. **Artifact Packaging** - Package template files
3. **SBOM Attachment** - Attach SBOM to artifacts
4. **Digest Pinning** - Record image digests for reproducibility

**Trigger:** After security scanning passes

**Exit Criteria:** All artifacts built successfully

### Stage 4: Approval Gate

**Purpose:** Ensure proper human review before publishing.

**Toolchain Templates:**
- Required Approvers: Platform Owner + Security Representative
- Minimum Approvals: 2

**Infrastructure Base Modules:**
- Required Approvers: Platform Owner
- Minimum Approvals: 1

**CVE/Security Patches:**
- Required Approvers: Security Team
- Minimum Approvals: 1 (expedited process)

**Trigger:** After artifacts are built (on main/release branches only)

**Exit Criteria:** Required approvals received

### Stage 5: Publish

**Purpose:** Publish approved templates to catalog/registry.

**Required Actions:**
1. **Push Container Images** - Push to container registry
2. **Create Git Tag** - Tag release with semantic version
3. **Update Catalog Index** - Update central catalog
4. **Record Provenance** - Record version, commit, approvers

**Trigger:** After approval gate passes

**Exit Criteria:** Templates published successfully

### Stage 6: Deploy (Optional)

**Purpose:** Deploy templates to Coder instance.

**Required Actions:**
1. **Terraform Apply** - Apply template configuration
2. **Verify Deployment** - Confirm templates are available in Coder
3. **Smoke Test** - Create test workspace (optional)

**Trigger:** After publishing (configurable)

**Exit Criteria:** Templates deployed and verified

## Branch Strategy

### Upgrade Channels (Requirement 11e.3)

| Channel | Branch Pattern | Tag Pattern | Description |
|---------|---------------|-------------|-------------|
| `stable` | `main`, `release/*` | `v*.*.*` | Production-ready |
| `beta` | `beta/*` | `v*.*.*-beta.*` | Pre-release testing |
| `pinned` | N/A | Specific `v*.*.*` | Locked version |

### Branch Protection Rules

**Main Branch:**
- Require pull request reviews (2 for toolchains, 1 for infra bases)
- Require status checks to pass
- Require signed commits (recommended)
- No direct pushes

**Release Branches:**
- Same as main branch
- Additional approval from release manager

## Environment Configuration

### Required Secrets

| Secret | Description | Used In |
|--------|-------------|---------|
| `CODER_URL` | Coder deployment URL | Deploy stage |
| `CODER_SESSION_TOKEN` | Coder API token | Deploy stage |
| `CONTAINER_REGISTRY_TOKEN` | Registry authentication | Publish stage |

### Required Environments

| Environment | Purpose | Required Reviewers |
|-------------|---------|-------------------|
| `toolchain-approval` | Toolchain template approval | Platform Owner, Security |
| `infra-base-approval` | Infrastructure base approval | Platform Owner |
| `production` | Production deployment | Platform Owner |

## Validation Scripts

The following scripts should be available in your CI/CD pipeline:

### validate-toolchain.sh

Validates toolchain templates:
- Checks required files exist
- Validates toolchain.yaml structure
- Validates Terraform syntax
- Checks for required outputs
- Ensures no infrastructure-specific code

### validate-infra-base.sh

Validates infrastructure base modules:
- Checks required files exist
- Validates contract inputs/outputs
- Validates Terraform syntax
- Checks provenance fields

### contract-check.sh

Validates contract compliance:
- Validates capability declarations
- Validates compute profile definitions
- Validates version format
- Checks contract input/output structure

## Security Scanning Tools

### Recommended Tools

| Tool | Purpose | License |
|------|---------|---------|
| Trivy | Vulnerability scanning | Apache 2.0 |
| tfsec | Terraform security | MIT |
| Checkov | IaC security | Apache 2.0 |
| Terrascan | IaC security | Apache 2.0 |
| Gitleaks | Secret detection | MIT |
| Syft | SBOM generation | Apache 2.0 |

### Severity Thresholds

| Environment | Block On |
|-------------|----------|
| Production | CRITICAL, HIGH |
| Beta | CRITICAL |
| Development | None (warn only) |

## Audit and Traceability

### Required Audit Records (Requirement 11b.7)

1. **Git History** - All changes tracked in Git
2. **Approval Records** - Who approved, when, for what
3. **Deployment Records** - What was deployed, when, by whom
4. **Scan Results** - Security scan results for each version

### Retention

- Git history: Indefinite
- Approval records: 2 years minimum
- Deployment records: 2 years minimum
- Scan results: 1 year minimum

## CVE Response Process

### Toolchain Layer (Requirement 11b.8)

**Owner:** Toolchain template owners

**Process:**
1. CVE identified in toolchain dependency
2. Toolchain owner creates patch branch
3. Update dependency version
4. Run security scan to verify fix
5. Expedited approval (Security team only)
6. Publish patch version

### Infrastructure Layer (Requirement 11b.9)

**Owner:** Platform owners

**Process:**
1. CVE identified in infrastructure component (AMI, node image, etc.)
2. Platform owner creates patch branch
3. Update infrastructure component
4. Run security scan to verify fix
5. Platform owner approval
6. Publish patch version

## Implementation Checklist

Use this checklist when implementing CI/CD in your platform:

- [ ] Repository structure follows template architecture
- [ ] Validation scripts are executable and tested
- [ ] Security scanning tools are configured
- [ ] Branch protection rules are enabled
- [ ] Approval environments are configured
- [ ] Required secrets are set
- [ ] Upgrade channels are documented
- [ ] CVE response process is documented
- [ ] Audit logging is enabled
- [ ] Team members have appropriate permissions
