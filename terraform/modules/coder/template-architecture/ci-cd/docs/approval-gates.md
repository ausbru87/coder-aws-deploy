# Approval Gates

This document describes the approval gate configuration for template governance.

## Overview

Approval gates ensure that templates are reviewed and approved by appropriate stakeholders before deployment. This provides governance, security oversight, and change control.

## Requirements Reference

| Requirement | Description |
|-------------|-------------|
| 11b.4 | Platform owner and security approval for new toolchain templates |
| 11b.5 | Platform owner approval for new infrastructure base modules |
| 12b.4 | Approval required from Template Admin before publication |

## Approval Matrix

### Toolchain Templates

| Action | Required Approvers | Minimum Approvals |
|--------|-------------------|-------------------|
| New template | Platform Owner + Security | 2 |
| Feature update | Platform Owner + Security | 2 |
| Bug fix | Platform Owner | 1 |
| Security patch | Security Team | 1 (expedited) |
| Deprecation | Platform Owner | 1 |

### Infrastructure Base Modules

| Action | Required Approvers | Minimum Approvals |
|--------|-------------------|-------------------|
| New module | Platform Owner | 1 |
| Feature update | Platform Owner | 1 |
| Bug fix | Platform Owner | 1 |
| Security patch | Platform Owner | 1 (expedited) |
| Breaking change | Platform Owner + Security | 2 |

### Template Deployment

| Action | Required Approvers | Minimum Approvals |
|--------|-------------------|-------------------|
| Deploy to staging | Template Admin | 1 |
| Deploy to production | Platform Owner | 1 |
| Emergency deployment | Platform Owner | 1 (with post-review) |

## Approver Roles

### Platform Owner

**Responsibilities:**
- Overall template architecture decisions
- Infrastructure base module approval
- Production deployment approval
- Breaking change approval

**Required Skills:**
- Deep understanding of Coder platform
- Infrastructure and security knowledge
- Template architecture expertise

### Security Representative

**Responsibilities:**
- Security review of toolchain templates
- Vulnerability assessment
- Security patch approval
- Compliance verification

**Required Skills:**
- Security expertise
- Vulnerability assessment
- Compliance knowledge

### Template Admin

**Responsibilities:**
- Template content review
- Staging deployment approval
- Template lifecycle management

**Required Skills:**
- Template development experience
- Coder platform knowledge

## GitHub Actions Configuration

### Environment Setup

Create environments in GitHub repository settings:

```yaml
# Repository Settings > Environments

# Environment: toolchain-approval
# Required reviewers:
#   - @platform-owner
#   - @security-team
# Wait timer: 0 minutes
# Deployment branches: main, release/*

# Environment: infra-base-approval
# Required reviewers:
#   - @platform-owner
# Wait timer: 0 minutes
# Deployment branches: main, release/*

# Environment: production
# Required reviewers:
#   - @platform-owner
# Wait timer: 0 minutes
# Deployment branches: main
```

### Workflow Configuration

```yaml
# In your workflow file
jobs:
  approval:
    name: Approval Gate
    runs-on: ubuntu-latest
    environment:
      name: toolchain-approval  # or infra-base-approval
    steps:
      - name: Approval Checkpoint
        run: |
          echo "Approved by: ${{ github.actor }}"
          echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

## GitLab CI Configuration

### Environment Setup

```yaml
# .gitlab-ci.yml

stages:
  - validate
  - security
  - build
  - approval
  - publish
  - deploy

approval:
  stage: approval
  script:
    - echo "Awaiting approval..."
  environment:
    name: toolchain-approval
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
    - if: $CI_COMMIT_BRANCH =~ /^release\//
      when: manual
```

### Protected Environments

Configure in GitLab project settings:
- Settings > CI/CD > Protected environments
- Add `toolchain-approval` and `infra-base-approval`
- Configure required approvers

## Jenkins Configuration

### Approval Stage

```groovy
// Jenkinsfile

pipeline {
    agent any
    
    stages {
        stage('Validate') {
            steps {
                sh './scripts/validate-toolchain.sh'
            }
        }
        
        stage('Security Scan') {
            steps {
                sh './scripts/security-scan.sh'
            }
        }
        
        stage('Approval') {
            when {
                anyOf {
                    branch 'main'
                    branch 'release/*'
                }
            }
            steps {
                script {
                    def approvers = ['platform-owner', 'security-team']
                    input message: 'Approve deployment?',
                          submitter: approvers.join(','),
                          submitterParameter: 'APPROVER'
                    
                    echo "Approved by: ${env.APPROVER}"
                }
            }
        }
        
        stage('Publish') {
            steps {
                sh './scripts/publish.sh'
            }
        }
    }
}
```

## AWS CodePipeline Configuration

### Approval Action

```json
{
  "name": "ToolchainApproval",
  "actions": [
    {
      "name": "ManualApproval",
      "actionTypeId": {
        "category": "Approval",
        "owner": "AWS",
        "provider": "Manual",
        "version": "1"
      },
      "configuration": {
        "NotificationArn": "arn:aws:sns:us-east-1:123456789:template-approvals",
        "CustomData": "Please review and approve the toolchain template changes."
      },
      "runOrder": 1
    }
  ]
}
```

### SNS Notification

Configure SNS topic to notify approvers:
- Create SNS topic for approvals
- Subscribe platform owners and security team
- Configure email/Slack notifications

## Approval Workflow

### Standard Approval Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Submit    │───▶│   Review    │───▶│   Approve   │───▶│   Deploy    │
│   Changes   │    │   Request   │    │   or Reject │    │   Changes   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                         │                   │
                         │                   │
                         ▼                   ▼
                   ┌─────────────┐    ┌─────────────┐
                   │  Automated  │    │   Manual    │
                   │   Checks    │    │   Review    │
                   └─────────────┘    └─────────────┘
```

### Expedited Approval Flow (Security Patches)

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Security  │───▶│   Security  │───▶│   Deploy    │
│   Patch     │    │   Approval  │    │   Patch     │
└─────────────┘    └─────────────┘    └─────────────┘
                         │
                         ▼
                   ┌─────────────┐
                   │ Post-Review │
                   │ by Platform │
                   │   Owner     │
                   └─────────────┘
```

## Approval Checklist

### For Approvers

Before approving, verify:

- [ ] All automated checks passed
- [ ] Security scan shows no critical/high issues
- [ ] Changes are documented in PR/MR description
- [ ] Breaking changes are clearly marked
- [ ] Version bump follows semantic versioning
- [ ] Changelog is updated
- [ ] Tests are included for new functionality
- [ ] Documentation is updated

### For Security Review

Additional checks for security approval:

- [ ] No hardcoded secrets
- [ ] No overly permissive IAM policies
- [ ] Network policies are appropriate
- [ ] Container images use approved base images
- [ ] Dependencies are from approved sources
- [ ] SBOM is generated and attached

## Audit Trail

### Required Records

For each approval, record:

1. **Approver identity** - Who approved
2. **Timestamp** - When approved
3. **Commit/Version** - What was approved
4. **Approval type** - Standard, expedited, emergency
5. **Comments** - Any notes from approver

### Storage

Store approval records in:
- Git commit messages
- CI/CD system logs
- Audit log system (CloudWatch, Splunk, etc.)

### Retention

- Approval records: 2 years minimum
- Audit logs: Per compliance requirements

## Emergency Procedures

### Emergency Deployment

For critical security issues requiring immediate deployment:

1. Security team member creates emergency PR
2. Single security approval (expedited)
3. Deploy immediately
4. Post-deployment review by platform owner within 24 hours
5. Document in incident report

### Rollback Without Approval

In case of production issues:

1. Platform owner can rollback without approval
2. Document reason for rollback
3. Create incident report
4. Review in next team meeting
