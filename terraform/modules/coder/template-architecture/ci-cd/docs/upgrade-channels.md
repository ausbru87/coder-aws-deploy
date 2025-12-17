# Upgrade Channels

This document describes the upgrade channel strategy for template management.

## Overview

Upgrade channels provide a mechanism for managing template versions across different stability levels. This allows organizations to:
- Test new features in beta before production
- Pin specific versions for stability
- Gradually roll out updates

## Requirements Reference

| Requirement | Description |
|-------------|-------------|
| 11e.3 | Maintain upgrade channels (stable, beta, pinned) for infrastructure base modules |
| 11d.5 | Toolchain templates use semantic versioning |
| 11d.6 | Infrastructure bases versioned separately from toolchains |

## Channel Definitions

### Stable Channel

**Purpose:** Production-ready templates that have been fully tested and approved.

**Characteristics:**
- Fully tested and validated
- Security scanned with no critical/high issues
- Approved by platform owner and security (for toolchains)
- Recommended for production workspaces

**Branch/Tag Pattern:**
- Branch: `main` or `release/*`
- Tags: `v1.0.0`, `v1.1.0`, `v2.0.0`

**Update Frequency:**
- Major versions: Quarterly or as needed
- Minor versions: Monthly
- Patch versions: As needed for security fixes

### Beta Channel

**Purpose:** Pre-release templates for testing new features before production.

**Characteristics:**
- Feature-complete but may have minor issues
- Security scanned
- Approved by platform owner
- Recommended for testing/staging workspaces

**Branch/Tag Pattern:**
- Branch: `beta/*`
- Tags: `v1.1.0-beta.1`, `v1.1.0-beta.2`

**Update Frequency:**
- As features are ready for testing
- Typically 1-2 weeks before stable release

### Pinned Channel

**Purpose:** Lock to a specific version for maximum stability.

**Characteristics:**
- Specific version that won't change
- No automatic updates
- User must explicitly update
- Recommended for critical workspaces requiring stability

**Tag Pattern:**
- Specific tag reference: `v1.0.0`, `v1.0.1`

**Update Frequency:**
- Never (user must manually update)

## Version Format

### Semantic Versioning

All templates follow semantic versioning (SemVer):

```
MAJOR.MINOR.PATCH[-PRERELEASE]

Examples:
- 1.0.0       (stable)
- 1.1.0       (stable, new features)
- 1.1.1       (stable, bug fix)
- 2.0.0       (stable, breaking changes)
- 1.2.0-beta.1 (beta)
- 1.2.0-rc.1   (release candidate)
```

### Version Bumping Rules

| Change Type | Version Bump | Example |
|-------------|--------------|---------|
| Breaking change | MAJOR | 1.0.0 → 2.0.0 |
| New feature (backward compatible) | MINOR | 1.0.0 → 1.1.0 |
| Bug fix | PATCH | 1.0.0 → 1.0.1 |
| Security fix | PATCH | 1.0.0 → 1.0.1 |
| Pre-release | PRERELEASE | 1.1.0-beta.1 |

### Breaking Changes

The following are considered breaking changes requiring a MAJOR version bump:

**Toolchain Templates:**
- Removing a required capability
- Changing compute profile definitions
- Removing supported languages/tools
- Changing bootstrap script interface

**Infrastructure Base Modules:**
- Changing contract input structure
- Changing contract output structure
- Removing capability implementations
- Changing identity/network policy defaults

## Channel Selection

### Workspace Configuration

Users select channels when creating workspaces:

```hcl
# Stable channel (default)
module "toolchain" {
  source = "git::https://github.com/org/toolchains.git//swdev-toolchain?ref=v1.0.0"
}

# Beta channel
module "toolchain" {
  source = "git::https://github.com/org/toolchains.git//swdev-toolchain?ref=v1.1.0-beta.1"
}

# Pinned to specific version
module "toolchain" {
  source = "git::https://github.com/org/toolchains.git//swdev-toolchain?ref=v1.0.0"
}
```

### Template Configuration

Administrators configure default channels per template:

```yaml
# Template pairing configuration
pairings:
  pod-swdev:
    toolchain:
      name: swdev-toolchain
      channel: stable  # or beta, pinned
      version: "1.0.0" # only for pinned
    base:
      name: base-k8s
      channel: stable
      version: "1.0.0"
```

## Upgrade Process

### Automatic Upgrades (Stable/Beta)

For stable and beta channels, upgrades can be automatic:

1. New version is published to channel
2. CI/CD detects new version
3. Terraform plan shows changes
4. Approval gate (if configured)
5. Terraform apply updates templates

### Manual Upgrades (Pinned)

For pinned versions, upgrades are manual:

1. Administrator reviews new version
2. Updates version reference in configuration
3. Creates pull request
4. Approval and merge
5. Terraform apply updates templates

## Rollback Process

### Quick Rollback

If issues are discovered after upgrade:

1. Revert to previous version tag
2. Create hotfix branch if needed
3. Apply previous version

```bash
# Rollback to previous version
git checkout v1.0.0
terraform apply
```

### Rollback with Data Migration

If data migration is involved:

1. Stop affected workspaces
2. Backup workspace data
3. Revert to previous version
4. Restore workspace data if needed
5. Restart workspaces

## Channel Promotion

### Beta to Stable

Process for promoting beta to stable:

1. Beta version tested for minimum 1 week
2. No critical issues reported
3. Security scan passes
4. Platform owner approval
5. Create release branch from beta
6. Tag as stable version
7. Update stable channel reference

### Hotfix Process

For critical security fixes:

1. Create hotfix branch from stable
2. Apply fix
3. Security scan
4. Expedited approval (security team)
5. Tag as patch version
6. Merge to main and beta branches

## Monitoring and Alerts

### Version Tracking

Track which versions are deployed:

```bash
# Query deployed versions
terraform output template_versions

# Example output
{
  "pod-swdev" = "1.0.0"
  "ec2-windev-gui" = "1.0.0"
  "ec2-datasci" = "1.1.0-beta.1"
}
```

### Upgrade Alerts

Configure alerts for:
- New stable versions available
- Beta versions ready for testing
- Security patches available
- Version deprecation notices

## Best Practices

1. **Use stable for production** - Always use stable channel for production workspaces
2. **Test in beta first** - Test new features in beta before promoting to stable
3. **Pin critical workspaces** - Use pinned versions for workspaces requiring maximum stability
4. **Regular updates** - Update pinned versions regularly to get security fixes
5. **Document changes** - Maintain changelog for each version
6. **Communicate upgrades** - Notify users before major upgrades
7. **Gradual rollout** - Roll out upgrades gradually, starting with non-critical workspaces
