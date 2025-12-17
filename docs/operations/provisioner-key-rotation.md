# Provisioner Key Management

This document details the provisioner key management procedures for the Coder platform, including key rotation, expiration monitoring, revocation procedures, and provisioner scoping.

## Table of Contents

1. [Overview](#overview)
2. [Key Rotation Schedule](#key-rotation-schedule)
3. [Expiration Alerts](#expiration-alerts)
4. [Key Revocation Procedure](#key-revocation-procedure)
5. [Provisioner Scoping](#provisioner-scoping)
6. [Access Logging](#access-logging)
7. [Terraform Configuration](#terraform-configuration)
8. [Operational Runbooks](#operational-runbooks)

---

## Overview

**Requirements:** 12f.1, 12f.2, 12f.3, 12f.4, 12f.5, 12f.6

External provisioners authenticate to Coder using provisioner keys. These keys must be:
- Rotated every 90 days (Requirement 12f.2)
- Monitored for expiration with 14-day advance alerts
- Immediately revocable in case of compromise (Requirement 12f.3)
- Scoped to specific organizations or templates using tags (Requirement 12f.4, 12f.5)
- Logged for audit purposes (Requirement 12f.6)

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Provisioner Key Flow                                  │
│                                                                              │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                │
│  │   Terraform  │────▶│    Coder     │────▶│  Kubernetes  │                │
│  │   (coderd    │     │   Control    │     │    Secret    │                │
│  │   provider)  │     │    Plane     │     │              │                │
│  └──────────────┘     └──────────────┘     └──────────────┘                │
│         │                    │                    │                         │
│         │                    │                    ▼                         │
│         │                    │           ┌──────────────┐                  │
│         │                    │           │  Provisioner │                  │
│         │                    │           │     Pods     │                  │
│         │                    │           └──────────────┘                  │
│         │                    │                    │                         │
│         │                    ▼                    │                         │
│         │           ┌──────────────┐              │                         │
│         │           │  Audit Logs  │◀─────────────┘                         │
│         │           │ (CloudWatch) │                                        │
│         │           └──────────────┘                                        │
│         │                    │                                              │
│         ▼                    ▼                                              │
│  ┌──────────────┐     ┌──────────────┐                                     │
│  │   Secrets    │     │  CloudWatch  │                                     │
│  │   Manager    │     │    Alarms    │                                     │
│  └──────────────┘     └──────────────┘                                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Rotation Schedule

**Requirement:** 12f.2 - Keys SHALL be rotated every 90 days

### Rotation Timeline

| Day | Action | Responsible |
|-----|--------|-------------|
| Day 0 | Key created | Platform Engineer |
| Day 76 | 14-day warning alert | Automated |
| Day 83 | 7-day warning alert | Automated |
| Day 88 | 2-day critical alert | Automated |
| Day 90 | Key rotation required | Platform Engineer |

### Rotation Procedure

#### Step 1: Create New Provisioner Key

```bash
# Using Coder CLI
coder provisioner keys create new-external-provisioner-key \
  --org default \
  --tag scope=organization \
  --tag environment=production

# Or using Terraform (recommended)
# Update terraform/modules/coder/coderd_provider.tf
```

#### Step 2: Update Kubernetes Secret

```bash
# Get the new key value
NEW_KEY=$(coder provisioner keys show new-external-provisioner-key --org default -o json | jq -r '.key')

# Update the Kubernetes secret
kubectl create secret generic coder-provisioner-key-new \
  --namespace coder-prov \
  --from-literal=key="${NEW_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### Step 3: Update Provisioner Deployment

```bash
# Update the provisioner deployment to use the new secret
kubectl set env deployment/coder-provisioner \
  --namespace coder-prov \
  CODER_PROVISIONER_KEY_SECRET_NAME=coder-provisioner-key-new

# Wait for rollout
kubectl rollout status deployment/coder-provisioner -n coder-prov
```

#### Step 4: Verify New Key is Working

```bash
# Check provisioner logs
kubectl logs -l app=coder-provisioner -n coder-prov --tail=50

# Verify provisioner is connected
coder provisioner list --org default

# Test workspace provisioning
coder create test-workspace --template pod-swdev --yes
coder delete test-workspace --yes
```

#### Step 5: Revoke Old Key

```bash
# Delete the old provisioner key
coder provisioner keys delete external-provisioner-key --org default --yes

# Remove old Kubernetes secret
kubectl delete secret coder-provisioner-key -n coder-prov
```

#### Step 6: Update Terraform State

```hcl
# Update terraform/modules/coder/coderd_provider.tf
resource "coderd_provisioner_key" "external" {
  count = var.enable_coderd_provider ? 1 : 0

  organization_id = data.coderd_organization.default[0].id
  name            = "external-provisioner-key-v2"  # Increment version

  tags = var.provisioner_key_tags
}
```

```bash
# Apply Terraform changes
terraform apply -target=module.coder.coderd_provisioner_key.external
```

---

## Expiration Alerts

### CloudWatch Alarm Configuration

The following CloudWatch alarms monitor provisioner key expiration:


#### 14-Day Warning Alert

```yaml
# CloudWatch Alarm - Provisioner Key Expiration Warning (14 days)
AlarmName: coder-provisioner-key-expiration-warning
AlarmDescription: Provisioner key expires in 14 days or less
MetricName: ProvisionerKeyDaysUntilExpiration
Namespace: Coder/Security
Statistic: Minimum
Period: 86400  # 24 hours
EvaluationPeriods: 1
Threshold: 14
ComparisonOperator: LessThanOrEqualToThreshold
AlarmActions:
  - arn:aws:sns:us-east-1:ACCOUNT_ID:coder-platform-alerts
TreatMissingData: breaching
```

#### 7-Day Warning Alert

```yaml
# CloudWatch Alarm - Provisioner Key Expiration Warning (7 days)
AlarmName: coder-provisioner-key-expiration-warning-7day
AlarmDescription: Provisioner key expires in 7 days or less
MetricName: ProvisionerKeyDaysUntilExpiration
Namespace: Coder/Security
Statistic: Minimum
Period: 86400  # 24 hours
EvaluationPeriods: 1
Threshold: 7
ComparisonOperator: LessThanOrEqualToThreshold
AlarmActions:
  - arn:aws:sns:us-east-1:ACCOUNT_ID:coder-platform-alerts-urgent
TreatMissingData: breaching
```

#### 2-Day Critical Alert

```yaml
# CloudWatch Alarm - Provisioner Key Expiration Critical (2 days)
AlarmName: coder-provisioner-key-expiration-critical
AlarmDescription: CRITICAL - Provisioner key expires in 2 days or less
MetricName: ProvisionerKeyDaysUntilExpiration
Namespace: Coder/Security
Statistic: Minimum
Period: 3600  # 1 hour
EvaluationPeriods: 1
Threshold: 2
ComparisonOperator: LessThanOrEqualToThreshold
AlarmActions:
  - arn:aws:sns:us-east-1:ACCOUNT_ID:coder-platform-alerts-critical
TreatMissingData: breaching
```

### Prometheus Alert Rules

```yaml
# Prometheus alerting rules for provisioner key expiration
groups:
  - name: coder-provisioner-key-alerts
    rules:
      - alert: ProvisionerKeyExpiring14Days
        expr: coder_provisioner_key_days_until_expiration <= 14
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "Provisioner key expires in {{ $value }} days"
          description: "Provisioner key '{{ $labels.key_name }}' expires in {{ $value }} days. Rotate the key before expiration."
          runbook_url: "https://docs.internal/coder/provisioner-key-rotation"

      - alert: ProvisionerKeyExpiring7Days
        expr: coder_provisioner_key_days_until_expiration <= 7
        for: 1h
        labels:
          severity: high
        annotations:
          summary: "URGENT - Provisioner key expires in {{ $value }} days"
          description: "Provisioner key '{{ $labels.key_name }}' expires in {{ $value }} days. Immediate rotation required."
          runbook_url: "https://docs.internal/coder/provisioner-key-rotation"

      - alert: ProvisionerKeyExpiring2Days
        expr: coder_provisioner_key_days_until_expiration <= 2
        for: 15m
        labels:
          severity: critical
        annotations:
          summary: "CRITICAL - Provisioner key expires in {{ $value }} days"
          description: "Provisioner key '{{ $labels.key_name }}' expires in {{ $value }} days. Service disruption imminent if not rotated."
          runbook_url: "https://docs.internal/coder/provisioner-key-rotation"
```

### Custom Metric Publishing Script

Create a script to publish key expiration metrics:

```bash
#!/bin/bash
# publish-key-expiration-metric.sh
# Run via cron job daily: 0 6 * * * /opt/coder/scripts/publish-key-expiration-metric.sh

set -euo pipefail

# Configuration
CODER_URL="${CODER_URL:-https://coder.example.com}"
AWS_REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="Coder/Security"

# Get provisioner keys and their creation dates
keys=$(coder provisioner keys list --org default -o json)

# Calculate days until expiration (90-day rotation policy)
ROTATION_DAYS=90

echo "$keys" | jq -c '.[]' | while read -r key; do
  key_name=$(echo "$key" | jq -r '.name')
  created_at=$(echo "$key" | jq -r '.created_at')
  
  # Calculate days since creation
  created_epoch=$(date -d "$created_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$created_at" +%s)
  current_epoch=$(date +%s)
  days_since_creation=$(( (current_epoch - created_epoch) / 86400 ))
  days_until_expiration=$(( ROTATION_DAYS - days_since_creation ))
  
  # Ensure non-negative
  if [ "$days_until_expiration" -lt 0 ]; then
    days_until_expiration=0
  fi
  
  # Publish to CloudWatch
  aws cloudwatch put-metric-data \
    --region "$AWS_REGION" \
    --namespace "$NAMESPACE" \
    --metric-name "ProvisionerKeyDaysUntilExpiration" \
    --dimensions "KeyName=$key_name" \
    --value "$days_until_expiration" \
    --unit "Count"
  
  echo "Published metric for key '$key_name': $days_until_expiration days until expiration"
done
```

---

## Key Revocation Procedure

**Requirement:** 12f.3 - WHEN key compromise occurs THEN immediate key revocation and provisioner reprovisioning SHALL be triggered

### Emergency Revocation Runbook

**Severity:** Critical  
**Response Time:** Immediate (within 15 minutes)

#### Step 1: Immediate Key Revocation

```bash
# IMMEDIATELY revoke the compromised key
coder provisioner keys delete <compromised-key-name> --org default --yes

# Verify key is deleted
coder provisioner keys list --org default
```

#### Step 2: Stop Affected Provisioners

```bash
# Scale down provisioner deployment to prevent unauthorized access
kubectl scale deployment coder-provisioner --replicas=0 -n coder-prov

# Verify no provisioner pods are running
kubectl get pods -n coder-prov -l app=coder-provisioner
```

#### Step 3: Create New Provisioner Key

```bash
# Create a new provisioner key with updated name
coder provisioner keys create emergency-provisioner-key-$(date +%Y%m%d) \
  --org default \
  --tag scope=organization \
  --tag environment=production

# Get the new key
NEW_KEY=$(coder provisioner keys show emergency-provisioner-key-$(date +%Y%m%d) --org default -o json | jq -r '.key')
```

#### Step 4: Update Kubernetes Secret

```bash
# Delete old secret
kubectl delete secret coder-provisioner-key -n coder-prov --ignore-not-found

# Create new secret with emergency key
kubectl create secret generic coder-provisioner-key \
  --namespace coder-prov \
  --from-literal=key="${NEW_KEY}"
```

#### Step 5: Reprovision Provisioners

```bash
# Scale up provisioner deployment
kubectl scale deployment coder-provisioner --replicas=3 -n coder-prov

# Wait for rollout
kubectl rollout status deployment/coder-provisioner -n coder-prov --timeout=300s

# Verify provisioners are connected
coder provisioner list --org default
```

#### Step 6: Audit and Investigation

```bash
# Check audit logs for unauthorized activity
# CloudWatch Logs Insights query:
fields @timestamp, @message, action, user.email, resource.type
| filter @logGroup like /coder-audit/
| filter resource.type = "provisioner_key" or action like /workspace/
| sort @timestamp desc
| limit 1000

# Export logs for security team
aws logs filter-log-events \
  --log-group-name "/coder/audit" \
  --start-time $(date -d "24 hours ago" +%s000) \
  --end-time $(date +%s000) \
  --filter-pattern "provisioner" \
  > provisioner-audit-$(date +%Y%m%d).json
```

#### Step 7: Post-Incident Actions

- [ ] Document the incident in the incident management system
- [ ] Notify security team and stakeholders
- [ ] Update Terraform configuration with new key name
- [ ] Review and update access controls if needed
- [ ] Schedule post-incident review meeting
- [ ] Update rotation schedule based on new key creation date

### Revocation Checklist

| Step | Action | Completed | Time |
|------|--------|-----------|------|
| 1 | Revoke compromised key | [ ] | |
| 2 | Stop provisioner pods | [ ] | |
| 3 | Create new key | [ ] | |
| 4 | Update Kubernetes secret | [ ] | |
| 5 | Restart provisioners | [ ] | |
| 6 | Verify connectivity | [ ] | |
| 7 | Audit log review | [ ] | |
| 8 | Incident documentation | [ ] | |
| 9 | Stakeholder notification | [ ] | |
| 10 | Terraform state update | [ ] | |

---

## Provisioner Scoping

**Requirements:** 12f.4, 12f.5 - Provisioners MAY be dedicated to specific organizations or templates using provisioner tags

### Tag-Based Isolation

Provisioner keys can be scoped using tags to control which templates and organizations they can provision:


### Tag Schema

| Tag Key | Description | Example Values |
|---------|-------------|----------------|
| `scope` | Provisioner scope level | `organization`, `template`, `global` |
| `environment` | Target environment | `production`, `staging`, `development` |
| `org` | Organization restriction | `default`, `team-a`, `team-b` |
| `template` | Template restriction | `pod-swdev`, `ec2-windev-gui`, `ec2-datasci` |

### Scoping Examples

#### Organization-Scoped Provisioner

```hcl
# Provisioner key scoped to a specific organization
resource "coderd_provisioner_key" "org_team_a" {
  organization_id = data.coderd_organization.team_a.id
  name            = "team-a-provisioner-key"

  tags = {
    scope       = "organization"
    org         = "team-a"
    environment = "production"
  }
}
```

#### Template-Scoped Provisioner

```hcl
# Provisioner key scoped to specific templates
resource "coderd_provisioner_key" "gpu_workloads" {
  organization_id = data.coderd_organization.default.id
  name            = "gpu-provisioner-key"

  tags = {
    scope    = "template"
    template = "ec2-datasci"
    gpu      = "true"
  }
}
```

#### Environment-Scoped Provisioner

```hcl
# Provisioner key for production environment only
resource "coderd_provisioner_key" "production" {
  organization_id = data.coderd_organization.default.id
  name            = "production-provisioner-key"

  tags = {
    scope       = "organization"
    environment = "production"
  }
}

# Provisioner key for development/staging
resource "coderd_provisioner_key" "non_production" {
  organization_id = data.coderd_organization.default.id
  name            = "non-production-provisioner-key"

  tags = {
    scope       = "organization"
    environment = "non-production"
  }
}
```

### Template Tag Matching

Templates must include matching tags to be provisioned by scoped provisioners:

```hcl
# In workspace template (Terraform)
resource "coder_agent" "main" {
  # ... agent configuration
}

# Template metadata with provisioner tags
data "coder_provisioner" "me" {
  # This template requires a provisioner with matching tags
}

# Template tags (in template metadata)
# provisioner_tags = {
#   scope       = "template"
#   template    = "ec2-datasci"
#   environment = "production"
# }
```

### Multi-Provisioner Architecture

For large deployments, consider multiple provisioner pools:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Multi-Provisioner Architecture                           │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                        Coder Control Plane                               ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                    │                                         │
│           ┌────────────────────────┼────────────────────────┐               │
│           │                        │                        │               │
│           ▼                        ▼                        ▼               │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐       │
│  │   Provisioner   │     │   Provisioner   │     │   Provisioner   │       │
│  │   Pool: General │     │   Pool: GPU     │     │   Pool: Windows │       │
│  │                 │     │                 │     │                 │       │
│  │ Tags:           │     │ Tags:           │     │ Tags:           │       │
│  │ - scope=org     │     │ - scope=template│     │ - scope=template│       │
│  │ - env=prod      │     │ - template=     │     │ - template=     │       │
│  │                 │     │   ec2-datasci   │     │   ec2-windev-gui│       │
│  │                 │     │ - gpu=true      │     │ - os=windows    │       │
│  └─────────────────┘     └─────────────────┘     └─────────────────┘       │
│           │                        │                        │               │
│           ▼                        ▼                        ▼               │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐       │
│  │  Pod Workspaces │     │ GPU Workspaces  │     │Windows Workspaces│       │
│  │  (pod-swdev)    │     │ (ec2-datasci)   │     │(ec2-windev-gui) │       │
│  └─────────────────┘     └─────────────────┘     └─────────────────┘       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Access Logging

**Requirement:** 12f.6 - Provisioner access logs SHALL identify which templates were provisioned

### Audit Log Configuration

Coder automatically logs all provisioner activity. Ensure audit logs are forwarded to CloudWatch:

```yaml
# Helm values for audit logging
coder:
  env:
    - name: CODER_AUDIT_LOGGING
      value: "true"
    - name: CODER_VERBOSE
      value: "true"
```

### Log Fields

Provisioner audit logs include the following fields:

| Field | Description | Example |
|-------|-------------|---------|
| `timestamp` | Event timestamp | `2024-01-15T10:30:00Z` |
| `action` | Action performed | `workspace.create`, `workspace.delete` |
| `provisioner_key` | Key used for provisioning | `external-provisioner-key` |
| `template_name` | Template being provisioned | `pod-swdev` |
| `template_version` | Template version | `v1.2.3` |
| `workspace_name` | Workspace name | `user-workspace-1` |
| `workspace_owner` | Workspace owner | `user@example.com` |
| `organization` | Organization | `default` |
| `status` | Provisioning status | `success`, `failed` |
| `duration_ms` | Provisioning duration | `45000` |
| `provisioner_id` | Provisioner instance ID | `prov-abc123` |

### CloudWatch Insights Queries

#### Provisioning Activity by Template

```sql
fields @timestamp, template_name, action, workspace_owner, status, duration_ms
| filter @logGroup like /coder-audit/
| filter action like /workspace\.(create|start|stop|delete)/
| stats count(*) as operations, 
        avg(duration_ms) as avg_duration,
        max(duration_ms) as max_duration
  by template_name, action
| sort operations desc
```

#### Provisioner Key Usage

```sql
fields @timestamp, provisioner_key, template_name, action, status
| filter @logGroup like /coder-audit/
| filter provisioner_key != ""
| stats count(*) as operations by provisioner_key, template_name
| sort operations desc
```

#### Failed Provisioning Events

```sql
fields @timestamp, template_name, workspace_name, workspace_owner, status, error_message
| filter @logGroup like /coder-audit/
| filter status = "failed"
| sort @timestamp desc
| limit 100
```

#### Provisioner Activity Timeline

```sql
fields @timestamp, provisioner_key, action, template_name, workspace_name
| filter @logGroup like /coder-audit/
| filter action like /workspace/
| sort @timestamp desc
| limit 500
```

### Prometheus Metrics

Monitor provisioner activity via Prometheus metrics:

```yaml
# Key provisioner metrics
- coderd_provisionerd_jobs_total{status="succeeded|failed"}
- coderd_provisionerd_job_duration_seconds
- coderd_workspace_builds_total{template_name, status}
- coderd_workspace_build_duration_seconds{template_name}
```

### Grafana Dashboard Panels

Create dashboard panels for provisioner monitoring:

```json
{
  "panels": [
    {
      "title": "Provisioning Operations by Template",
      "type": "piechart",
      "targets": [
        {
          "expr": "sum(increase(coderd_workspace_builds_total[24h])) by (template_name)"
        }
      ]
    },
    {
      "title": "Provisioning Success Rate",
      "type": "gauge",
      "targets": [
        {
          "expr": "sum(rate(coderd_workspace_builds_total{status=\"succeeded\"}[1h])) / sum(rate(coderd_workspace_builds_total[1h])) * 100"
        }
      ]
    },
    {
      "title": "Average Provisioning Duration by Template",
      "type": "bargauge",
      "targets": [
        {
          "expr": "avg(coderd_workspace_build_duration_seconds) by (template_name)"
        }
      ]
    }
  ]
}
```

---

## Terraform Configuration

### Variables

Add the following variables to your Terraform configuration:

```hcl
# terraform/modules/coder/variables.tf

variable "provisioner_key_rotation_days" {
  description = "Number of days between provisioner key rotations (Requirement 12f.2)"
  type        = number
  default     = 90

  validation {
    condition     = var.provisioner_key_rotation_days >= 30 && var.provisioner_key_rotation_days <= 365
    error_message = "Provisioner key rotation must be between 30 and 365 days."
  }
}

variable "provisioner_key_expiration_warning_days" {
  description = "Days before expiration to trigger warning alert"
  type        = number
  default     = 14
}

variable "provisioner_key_tags" {
  description = "Tags for provisioner key scoping (Requirement 12f.4)"
  type        = map(string)
  default = {
    scope       = "organization"
    environment = "production"
  }
}

variable "enable_provisioner_key_monitoring" {
  description = "Enable CloudWatch alarms for provisioner key expiration"
  type        = bool
  default     = true
}
```

### Provisioner Key Resource

```hcl
# terraform/modules/coder/coderd_provider.tf

resource "coderd_provisioner_key" "external" {
  count = var.enable_coderd_provider ? 1 : 0

  organization_id = data.coderd_organization.default[0].id
  name            = "external-provisioner-key"

  # Tags for provisioner scoping (Requirement 12f.4, 12f.5)
  tags = var.provisioner_key_tags
}

# Store provisioner key in Kubernetes secret
resource "kubernetes_secret_v1" "provisioner_key" {
  count = var.enable_coderd_provider ? 1 : 0

  metadata {
    name      = var.provisioner_key_secret_name
    namespace = kubernetes_namespace_v1.coder_prov.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "coder-provisioner"
      "app.kubernetes.io/component"  = "authentication"
      "app.kubernetes.io/managed-by" = "terraform"
    }
    annotations = {
      # Track key creation for rotation monitoring
      "coder.com/key-created"        = timestamp()
      "coder.com/rotation-due"       = timeadd(timestamp(), "${var.provisioner_key_rotation_days * 24}h")
      "coder.com/rotation-policy"    = "${var.provisioner_key_rotation_days} days"
    }
  }

  data = {
    key = coderd_provisioner_key.external[0].key
  }

  type = "Opaque"
}
```

### CloudWatch Alarms

```hcl
# terraform/modules/observability/provisioner_key_alarms.tf

resource "aws_cloudwatch_metric_alarm" "provisioner_key_expiration_warning" {
  count = var.enable_provisioner_key_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-provisioner-key-expiration-warning"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ProvisionerKeyDaysUntilExpiration"
  namespace           = "Coder/Security"
  period              = 86400  # 24 hours
  statistic           = "Minimum"
  threshold           = var.provisioner_key_expiration_warning_days
  alarm_description   = "Provisioner key expires in ${var.provisioner_key_expiration_warning_days} days or less"
  treat_missing_data  = "breaching"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  dimensions = {
    KeyName = "external-provisioner-key"
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "provisioner_key_expiration_critical" {
  count = var.enable_provisioner_key_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-provisioner-key-expiration-critical"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ProvisionerKeyDaysUntilExpiration"
  namespace           = "Coder/Security"
  period              = 3600  # 1 hour
  statistic           = "Minimum"
  threshold           = 2
  alarm_description   = "CRITICAL - Provisioner key expires in 2 days or less"
  treat_missing_data  = "breaching"

  alarm_actions = [var.sns_critical_topic_arn]
  ok_actions    = [var.sns_critical_topic_arn]

  dimensions = {
    KeyName = "external-provisioner-key"
  }

  tags = var.tags
}
```

---

## Operational Runbooks

### Scheduled Key Rotation Runbook

**Frequency:** Every 90 days  
**Duration:** ~30 minutes  
**Risk Level:** Low (when following procedure)

#### Pre-Rotation Checklist

- [ ] Verify current key expiration date
- [ ] Ensure no active provisioning jobs
- [ ] Notify stakeholders of planned rotation
- [ ] Verify access to Coder CLI and kubectl
- [ ] Review recent provisioner logs for issues

#### Rotation Steps

1. **Create new key** (5 min)
   ```bash
   coder provisioner keys create external-provisioner-key-$(date +%Y%m%d) \
     --org default \
     --tag scope=organization \
     --tag environment=production
   ```

2. **Update Kubernetes secret** (5 min)
   ```bash
   NEW_KEY=$(coder provisioner keys show external-provisioner-key-$(date +%Y%m%d) --org default -o json | jq -r '.key')
   kubectl create secret generic coder-provisioner-key-new \
     --namespace coder-prov \
     --from-literal=key="${NEW_KEY}" \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

3. **Rolling update provisioners** (10 min)
   ```bash
   kubectl rollout restart deployment/coder-provisioner -n coder-prov
   kubectl rollout status deployment/coder-provisioner -n coder-prov
   ```

4. **Verify connectivity** (5 min)
   ```bash
   coder provisioner list --org default
   # Test workspace creation
   ```

5. **Revoke old key** (5 min)
   ```bash
   coder provisioner keys delete <old-key-name> --org default --yes
   ```

#### Post-Rotation Checklist

- [ ] Verify all provisioners connected
- [ ] Test workspace provisioning
- [ ] Update Terraform configuration
- [ ] Update rotation calendar
- [ ] Document rotation in change log

---

## References

- [Coder External Provisioners](https://coder.com/docs/admin/provisioners)
- [Coder Provisioner Keys](https://coder.com/docs/admin/provisioners#provisioner-keys)
- [Coder Audit Logging](https://coder.com/docs/admin/audit-logs)
- [NIST SP 800-57 Key Management](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final)
- [CIS Controls v8 - Control 3: Data Protection](https://www.cisecurity.org/controls/data-protection)


---

## Appendix A: CloudWatch Logs Insights Queries for Provisioner Auditing

### Query: All Provisioning Activity (Last 24 Hours)

```sql
fields @timestamp, @message
| parse @message /template_name=(?<template>[^\s,]+)/
| parse @message /workspace_name=(?<workspace>[^\s,]+)/
| parse @message /owner=(?<owner>[^\s,]+)/
| parse @message /status=(?<status>[^\s,]+)/
| parse @message /provisioner_key=(?<key>[^\s,]+)/
| filter @logGroup like /coder/
| filter @message like /workspace.*build/
| sort @timestamp desc
| limit 1000
```

### Query: Provisioning by Template (Summary)

```sql
fields @timestamp, @message
| parse @message /template_name=(?<template>[^\s,]+)/
| parse @message /status=(?<status>[^\s,]+)/
| filter @logGroup like /coder/
| filter @message like /workspace.*build/
| stats count(*) as operations by template, status
| sort operations desc
```

### Query: Failed Provisioning Events

```sql
fields @timestamp, @message
| parse @message /template_name=(?<template>[^\s,]+)/
| parse @message /workspace_name=(?<workspace>[^\s,]+)/
| parse @message /owner=(?<owner>[^\s,]+)/
| parse @message /error=(?<error>[^\n]+)/
| filter @logGroup like /coder/
| filter @message like /status=failed/ or @message like /error/
| sort @timestamp desc
| limit 100
```

### Query: Provisioner Key Usage

```sql
fields @timestamp, @message
| parse @message /provisioner_key=(?<key>[^\s,]+)/
| parse @message /template_name=(?<template>[^\s,]+)/
| filter @logGroup like /coder/
| filter @message like /provisioner_key/
| stats count(*) as operations by key, template
| sort operations desc
```

### Query: Provisioning Duration Analysis

```sql
fields @timestamp, @message
| parse @message /template_name=(?<template>[^\s,]+)/
| parse @message /duration_ms=(?<duration>\d+)/
| filter @logGroup like /coder/
| filter @message like /workspace.*build.*completed/
| stats avg(duration) as avg_ms, max(duration) as max_ms, min(duration) as min_ms, count(*) as count by template
| sort avg_ms desc
```

---

## Appendix B: Compliance Checklist

Use this checklist to verify provisioner key management controls are properly implemented:

### Key Rotation (12f.2)
- [ ] 90-day rotation schedule documented
- [ ] 14-day expiration alerts configured
- [ ] 7-day expiration alerts configured
- [ ] 2-day critical alerts configured
- [ ] Rotation procedure documented and tested
- [ ] Terraform state updated after rotation

### Key Revocation (12f.3)
- [ ] Emergency revocation procedure documented
- [ ] Revocation tested in non-production
- [ ] Incident response team trained
- [ ] Post-incident review process defined

### Provisioner Scoping (12f.4, 12f.5)
- [ ] Tag schema defined
- [ ] Organization-scoped keys configured (if needed)
- [ ] Template-scoped keys configured (if needed)
- [ ] Template tags match provisioner tags
- [ ] Multi-provisioner architecture documented (if applicable)

### Access Logging (12f.6)
- [ ] Audit logging enabled in Coder
- [ ] Logs forwarded to CloudWatch
- [ ] 90-day retention configured
- [ ] CloudWatch Insights queries documented
- [ ] Grafana dashboards configured (if applicable)
- [ ] Prometheus metrics exported

### Monitoring
- [ ] CloudWatch alarms configured
- [ ] SNS topics for alerts created
- [ ] Alert escalation procedures documented
- [ ] Dashboard for key monitoring created
- [ ] Metric publishing script deployed

---

## Appendix C: Troubleshooting

### Provisioner Not Connecting

1. **Check provisioner key validity:**
   ```bash
   coder provisioner keys list --org default
   ```

2. **Check Kubernetes secret:**
   ```bash
   kubectl get secret coder-provisioner-key -n coder-prov -o yaml
   ```

3. **Check provisioner logs:**
   ```bash
   kubectl logs -l app=coder-provisioner -n coder-prov --tail=100
   ```

4. **Verify network connectivity:**
   ```bash
   kubectl exec -it deploy/coder-provisioner -n coder-prov -- curl -v https://coder.example.com/api/v2/buildinfo
   ```

### Key Rotation Failures

1. **Verify new key was created:**
   ```bash
   coder provisioner keys list --org default
   ```

2. **Check secret update:**
   ```bash
   kubectl describe secret coder-provisioner-key -n coder-prov
   ```

3. **Force pod restart:**
   ```bash
   kubectl rollout restart deployment/coder-provisioner -n coder-prov
   ```

### Missing Audit Logs

1. **Verify Fluent Bit is running:**
   ```bash
   kubectl get pods -n amazon-cloudwatch -l app.kubernetes.io/name=fluent-bit
   ```

2. **Check Fluent Bit logs:**
   ```bash
   kubectl logs -l app.kubernetes.io/name=fluent-bit -n amazon-cloudwatch --tail=50
   ```

3. **Verify CloudWatch log group exists:**
   ```bash
   aws logs describe-log-groups --log-group-name-prefix /aws/eks/
   ```
