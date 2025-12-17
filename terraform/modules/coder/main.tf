# Coder Module for Helm Deployments
# Deploys coderd, external provisioners, and configures Coder via coderd provider

locals {
  access_url          = "https://${var.coder_subdomain}.${var.base_domain}"
  wildcard_access_url = "https://*.${var.coder_subdomain}.${var.base_domain}"
}

# =============================================================================
# Kubernetes Namespaces
# =============================================================================
resource "kubernetes_namespace_v1" "coder" {
  metadata {
    name = "coder"
    labels = {
      "app.kubernetes.io/name"       = "coder"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_namespace_v1" "coder_prov" {
  metadata {
    name = "coder-prov"
    labels = {
      "app.kubernetes.io/name"       = "coder-provisioner"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_namespace_v1" "coder_ws" {
  metadata {
    name = "coder-ws"
    labels = {
      "app.kubernetes.io/name"       = "coder-workspaces"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# =============================================================================
# Coder Helm Release (coderd)
# =============================================================================
resource "helm_release" "coder" {
  name       = "coder"
  repository = "https://helm.coder.com/v2"
  chart      = "coder"
  version    = var.coder_version
  namespace  = kubernetes_namespace_v1.coder.metadata[0].name

  values = [
    templatefile("${path.module}/values/coder-values.yaml.tpl", {
      # Access URLs
      access_url          = local.access_url
      wildcard_access_url = local.wildcard_access_url

      # Replica and image configuration
      replicas        = var.coderd_replicas
      coder_image_tag = var.coder_image_tag

      # OIDC Authentication (Requirements: 12.1, 12c.1-12c.10)
      oidc_issuer_url            = var.oidc_issuer_url
      oidc_client_id             = var.oidc_client_id
      oidc_email_domain          = var.oidc_email_domain
      oidc_group_field           = var.oidc_group_field
      oidc_group_regex_filter    = var.oidc_group_regex_filter
      oidc_group_mapping         = var.oidc_group_mapping
      oidc_ignore_email_verified = var.oidc_ignore_email_verified

      # Session Management (Requirement 12e.1)
      session_duration      = var.session_duration
      disable_password_auth = var.disable_password_auth

      # External Authentication (Requirements: 12.5, 12g.1, 12g.5, 12g.6)
      external_auth_provider     = var.external_auth_provider
      external_auth_id           = var.external_auth_id
      external_auth_client_id    = var.external_auth_client_id
      external_auth_scopes       = var.external_auth_scopes
      external_auth_display_name = var.external_auth_display_name

      # Workspace Quotas (Requirement 14.15)
      max_workspaces_per_user = var.max_workspaces_per_user

      # Workspace Lifecycle (Requirements: 5.9, 13.1, 13.2)
      default_quiet_hours_schedule = var.default_quiet_hours_schedule

      # DERP/Networking (Requirement 3.1a)
      derp_stun_addresses   = var.derp_stun_addresses
      derp_force_websockets = var.derp_force_websockets

      # Logging
      verbose_logging = var.verbose_logging

      # Experiments
      experiments = var.experiments

      # Resource Limits (Requirement 6.2)
      coderd_cpu_request    = var.coderd_cpu_request
      coderd_memory_request = var.coderd_memory_request
      coderd_cpu_limit      = var.coderd_cpu_limit
      coderd_memory_limit   = var.coderd_memory_limit

      # IAM Role (Requirement 2.5)
      service_account_role_arn = var.coder_server_role_arn
    })
  ]

  set = [
    {
      name  = "coder.env[0].valueFrom.secretKeyRef.name"
      value = kubernetes_secret_v1.coder_db.metadata[0].name
    }
  ]

  depends_on = [
    kubernetes_namespace_v1.coder,
    kubernetes_secret_v1.coder_db,
    kubernetes_secret_v1.coder_oidc,
  ]
}

# =============================================================================
# Coder Provisioner Helm Release
# =============================================================================
resource "helm_release" "coder_provisioner" {
  name       = "coder-provisioner"
  repository = "https://helm.coder.com/v2"
  chart      = "coder-provisioner"
  version    = var.coder_version
  namespace  = kubernetes_namespace_v1.coder_prov.metadata[0].name

  values = [
    templatefile("${path.module}/values/coder-provisioner-values.yaml.tpl", {
      # Coder connection
      coder_url       = local.access_url
      coder_image_tag = var.coder_image_tag

      # Replica configuration
      provisioner_replicas = var.provisioner_replicas

      # Provisioner key authentication (Requirement 12f.1)
      provisioner_key_secret_name = var.provisioner_key_secret_name

      # Provisioner tags for isolation (Requirement 12f.4)
      provisioner_tags = var.provisioner_tags

      # Polling configuration
      poll_interval = var.provisioner_poll_interval
      poll_jitter   = var.provisioner_poll_jitter

      # Logging (Requirement 12f.6)
      verbose_logging       = var.verbose_logging
      log_human             = var.provisioner_log_human
      provisioner_log_level = var.provisioner_log_level
      log_json              = var.provisioner_log_json

      # Resource limits
      provisioner_cpu_request    = var.provisioner_cpu_request
      provisioner_memory_request = var.provisioner_memory_request
      provisioner_cpu_limit      = var.provisioner_cpu_limit
      provisioner_memory_limit   = var.provisioner_memory_limit

      # IAM Role (Requirement 2.5)
      service_account_role_arn = var.coder_prov_role_arn
    })
  ]

  depends_on = [
    helm_release.coder,
    kubernetes_namespace_v1.coder_prov,
  ]
}

# =============================================================================
# Kubernetes Secrets
# =============================================================================
resource "kubernetes_secret_v1" "coder_db" {
  metadata {
    name      = "coder-db-credentials"
    namespace = kubernetes_namespace_v1.coder.metadata[0].name
  }

  data = {
    DB_USER     = "coder_admin"
    DB_PASSWORD = data.aws_secretsmanager_secret_version.db.secret_string
  }
}

resource "kubernetes_secret_v1" "coder_oidc" {
  metadata {
    name      = "coder-oidc-credentials"
    namespace = kubernetes_namespace_v1.coder.metadata[0].name
  }

  data = {
    CODER_OIDC_CLIENT_SECRET = data.aws_secretsmanager_secret_version.oidc.secret_string
  }
}

resource "kubernetes_secret_v1" "coder_external_auth" {
  count = var.external_auth_client_secret_arn != "" ? 1 : 0

  metadata {
    name      = "coder-external-auth-credentials"
    namespace = kubernetes_namespace_v1.coder.metadata[0].name
  }

  data = {
    CODER_EXTERNAL_AUTH_0_CLIENT_SECRET = data.aws_secretsmanager_secret_version.external_auth[0].secret_string
  }
}

# =============================================================================
# Data Sources for Secrets
# =============================================================================
data "aws_secretsmanager_secret_version" "db" {
  secret_id = var.database_secret_arn
}

data "aws_secretsmanager_secret_version" "oidc" {
  secret_id = var.oidc_client_secret_arn
}

data "aws_secretsmanager_secret_version" "external_auth" {
  count     = var.external_auth_client_secret_arn != "" ? 1 : 0
  secret_id = var.external_auth_client_secret_arn
}

# =============================================================================
# NLB Data Source for DNS Configuration
# =============================================================================

# Look up the NLB created by the AWS Load Balancer Controller
# This provides the DNS name and zone ID needed for Route 53 ALIAS records
data "aws_lb" "coder_nlb" {
  tags = {
    "elbv2.k8s.aws/cluster"    = var.cluster_name
    "service.k8s.aws/resource" = "LoadBalancer"
    "service.k8s.aws/stack"    = "${kubernetes_namespace_v1.coder.metadata[0].name}/coder-nlb"
  }

  depends_on = [kubernetes_service_v1.coder_nlb]
}

# =============================================================================
# Network Load Balancer Service
# =============================================================================
#
# Requirements: 2.4, 12.7, 12.8, 12.8a
#
# This NLB configuration provides:
# - TLS termination with ACM certificate
# - TLS 1.2 minimum with TLS 1.3 preferred (ELBSecurityPolicy-TLS13-1-2-2021-06)
# - AES-128-GCM and AES-256-GCM with ECDHE cipher suites per Fortune 2000 standards
# - HTTPS enforcement (port 443)
# - STUN UDP support (port 3478) for NAT traversal and direct P2P connections
# - Cross-zone load balancing for high availability
# - Health checks for coderd pods
#
# TLS Policy: ELBSecurityPolicy-TLS13-1-2-2021-06
# This policy enforces:
# - TLS 1.2 and TLS 1.3 only (no TLS 1.0/1.1)
# - ECDHE key exchange (forward secrecy)
# - AES-GCM cipher suites (AES-128-GCM, AES-256-GCM)
# - SHA-256 or SHA-384 for message authentication
#
# Supported cipher suites:
# - TLS_AES_128_GCM_SHA256 (TLS 1.3)
# - TLS_AES_256_GCM_SHA384 (TLS 1.3)
# - TLS_CHACHA20_POLY1305_SHA256 (TLS 1.3)
# - ECDHE-ECDSA-AES128-GCM-SHA256 (TLS 1.2)
# - ECDHE-RSA-AES128-GCM-SHA256 (TLS 1.2)
# - ECDHE-ECDSA-AES256-GCM-SHA384 (TLS 1.2)
# - ECDHE-RSA-AES256-GCM-SHA384 (TLS 1.2)

resource "kubernetes_service_v1" "coder_nlb" {
  metadata {
    name      = "coder-nlb"
    namespace = kubernetes_namespace_v1.coder.metadata[0].name
    annotations = {
      # Load balancer type and target configuration
      "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"

      # TLS configuration - Requirements: 12.7, 12.8, 12.8a
      # ACM certificate for TLS termination
      "service.beta.kubernetes.io/aws-load-balancer-ssl-cert" = var.acm_certificate_arn
      # Apply TLS to HTTPS port only (STUN uses UDP, no TLS)
      "service.beta.kubernetes.io/aws-load-balancer-ssl-ports" = "443"
      # TLS 1.2+ with TLS 1.3 preferred, AES-GCM with ECDHE cipher suites
      # This policy meets Fortune 2000 security standards per Requirement 12.8a
      "service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy" = var.nlb_ssl_policy

      # Cross-zone load balancing for high availability
      "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = tostring(var.nlb_cross_zone_enabled)

      # Health check configuration
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol"            = "HTTP"
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-port"                = "8080"
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-path"                = "/healthz"
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval"            = tostring(var.nlb_health_check_interval)
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout"             = tostring(var.nlb_health_check_timeout)
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold"   = tostring(var.nlb_healthy_threshold)
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold" = tostring(var.nlb_unhealthy_threshold)

      # Target group attributes
      "service.beta.kubernetes.io/aws-load-balancer-target-group-attributes" = "deregistration_delay.timeout_seconds=${var.nlb_deregistration_delay},stickiness.enabled=false"

      # Resource tagging for identification
      "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags" = "Project=${var.project_name},Environment=${var.environment},ManagedBy=terraform"
    }
  }

  spec {
    type                    = "LoadBalancer"
    external_traffic_policy = "Local"

    selector = {
      "app.kubernetes.io/name"     = "coder"
      "app.kubernetes.io/instance" = "coder"
    }

    # HTTPS port - TLS terminated at NLB, forwarded to coderd on 8080
    # Requirements: 12.7 (HTTPS everywhere)
    port {
      name        = "https"
      port        = 443
      target_port = 8080
      protocol    = "TCP"
    }

    # STUN UDP port for NAT traversal and direct P2P connections
    # Requirements: Design document - Interface Definitions
    # STUN enables clients and workspaces to discover NAT mappings
    # for establishing direct peer-to-peer connections
    dynamic "port" {
      for_each = var.enable_stun ? [1] : []
      content {
        name        = "stun"
        port        = 3478
        target_port = 3478
        protocol    = "UDP"
      }
    }
  }

  depends_on = [helm_release.coder]
}

# =============================================================================
# Observability Configuration
# Requirements: 8.1a, 8.1b, 8.1c, 15.2a
# =============================================================================

# ConfigMap containing observability configuration
# This is used by Prometheus Operator and Grafana for Coder metrics
resource "kubernetes_config_map_v1" "coder_observability" {
  count = var.enable_prometheus_metrics ? 1 : 0

  metadata {
    name      = "coder-observability-config"
    namespace = kubernetes_namespace_v1.coder.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "coder"
      "app.kubernetes.io/component"  = "observability"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "observability-values.yaml" = templatefile("${path.module}/values/observability-values.yaml.tpl", {
      # Prometheus configuration
      enable_prometheus      = var.enable_prometheus_metrics
      enable_service_monitor = var.enable_service_monitor
      prometheus_namespace   = var.prometheus_namespace
      scrape_interval        = var.scrape_interval
      scrape_timeout         = var.scrape_timeout
      collect_agent_stats    = var.collect_agent_stats
      collect_db_metrics     = var.collect_db_metrics

      # AMP integration (Requirement 8.1b)
      enable_amp_integration = var.enable_amp_integration
      amp_remote_write_url   = var.amp_remote_write_url
      aws_region             = var.aws_region

      # CloudWatch Container Insights (Requirement 8.1b)
      enable_container_insights = var.enable_container_insights
      environment               = var.environment

      # Grafana dashboards (Requirement 8.1c)
      enable_grafana_dashboards = var.enable_grafana_dashboards

      # Alerting (Requirements 14.13, 14.20)
      enable_alerting = var.enable_alerting
    })
  }
}

# ServiceMonitor for Prometheus Operator
# This tells Prometheus to scrape Coder metrics on port 2112
resource "kubernetes_manifest" "coder_service_monitor" {
  count = var.enable_service_monitor ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "coder"
      namespace = var.prometheus_namespace
      labels = {
        "app.kubernetes.io/name"       = "coder"
        "app.kubernetes.io/component"  = "metrics"
        "app.kubernetes.io/managed-by" = "terraform"
        release                        = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name"     = "coder"
          "app.kubernetes.io/instance" = "coder"
        }
      }
      namespaceSelector = {
        matchNames = [kubernetes_namespace_v1.coder.metadata[0].name]
      }
      endpoints = [
        {
          port     = "metrics"
          interval = var.scrape_interval
          path     = "/metrics"
        }
      ]
    }
  }

  depends_on = [helm_release.coder]
}

# PrometheusRule for alerting
# Requirements: 14.13 (API latency monitoring), 14.20 (scaling delay alerts)
resource "kubernetes_manifest" "coder_prometheus_rules" {
  count = var.enable_alerting && var.enable_service_monitor ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "coder-alerts"
      namespace = var.prometheus_namespace
      labels = {
        "app.kubernetes.io/name"       = "coder"
        "app.kubernetes.io/component"  = "alerting"
        "app.kubernetes.io/managed-by" = "terraform"
        release                        = "prometheus"
      }
    }
    spec = {
      groups = [
        {
          name = "coder.rules"
          rules = [
            # API Latency P95 Alert (Requirement 14.9)
            {
              alert = "CoderAPILatencyP95High"
              expr  = "histogram_quantile(0.95, sum(rate(coderd_api_request_latencies_seconds_bucket[5m])) by (le)) > 0.5"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Coder API P95 latency exceeds 500ms threshold"
                description = "P95 API latency is {{ $value }}s"
              }
            },
            # API Latency P99 Alert (Requirement 14.10)
            {
              alert = "CoderAPILatencyP99Critical"
              expr  = "histogram_quantile(0.99, sum(rate(coderd_api_request_latencies_seconds_bucket[5m])) by (le)) > 1"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Coder API P99 latency exceeds 1s threshold"
                description = "P99 API latency is {{ $value }}s"
              }
            },
            # Pod Workspace Provisioning Alert (Requirement 14.6)
            {
              alert = "CoderPodWorkspaceProvisioningSlow"
              expr  = "histogram_quantile(0.95, sum(rate(coderd_workspace_build_duration_seconds_bucket{template=~\"pod-.*\"}[1h])) by (le)) > 120"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Pod workspace provisioning exceeds 2 minute threshold"
                description = "P95 pod workspace provisioning time is {{ $value }}s"
              }
            },
            # EC2 Workspace Provisioning Alert (Requirement 14.7)
            {
              alert = "CoderEC2WorkspaceProvisioningSlow"
              expr  = "histogram_quantile(0.95, sum(rate(coderd_workspace_build_duration_seconds_bucket{template=~\"ec2-.*\"}[1h])) by (le)) > 300"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "EC2 workspace provisioning exceeds 5 minute threshold"
                description = "P95 EC2 workspace provisioning time is {{ $value }}s"
              }
            },
            # Scaling Delay Alert (Requirement 14.20)
            {
              alert = "CoderScalingDelayed"
              expr  = "increase(coderd_workspace_builds_total{status=\"pending\"}[5m]) > 10"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Workspace scaling may be delayed"
                description = "High number of pending workspace builds"
              }
            },
            # No Active Provisioners Alert
            {
              alert = "CoderNoActiveProvisioners"
              expr  = "sum(up{job=\"coder-provisioner\"}) == 0"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "No active Coder provisioners"
                description = "All Coder provisioners are down"
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.coder]
}

# Grafana Dashboard ConfigMap
# Requirement 8.1c: Pre-configured Grafana dashboards
resource "kubernetes_config_map_v1" "coder_grafana_dashboards" {
  count = var.enable_grafana_dashboards ? 1 : 0

  metadata {
    name      = "coder-dashboards"
    namespace = var.prometheus_namespace
    labels = {
      "app.kubernetes.io/name"       = "coder"
      "app.kubernetes.io/component"  = "grafana-dashboards"
      "app.kubernetes.io/managed-by" = "terraform"
      grafana_dashboard              = "1"
    }
  }

  data = {
    "coder-overview.json" = jsonencode({
      title         = "Coder Platform Overview"
      uid           = "coder-overview"
      tags          = ["coder", "overview"]
      timezone      = "browser"
      refresh       = "30s"
      schemaVersion = 38
      panels = [
        {
          title   = "Active Workspaces"
          type    = "stat"
          gridPos = { h = 4, w = 6, x = 0, y = 0 }
          targets = [{ expr = "sum(coderd_workspaces_current{status=\"running\"})" }]
        },
        {
          title   = "API Latency P95"
          type    = "gauge"
          gridPos = { h = 4, w = 6, x = 6, y = 0 }
          targets = [{ expr = "histogram_quantile(0.95, sum(rate(coderd_api_request_latencies_seconds_bucket[5m])) by (le))" }]
          fieldConfig = {
            defaults = {
              unit = "s"
              thresholds = {
                steps = [
                  { color = "green", value = null },
                  { color = "yellow", value = 0.3 },
                  { color = "red", value = 0.5 }
                ]
              }
            }
          }
        },
        {
          title   = "API Latency P99"
          type    = "gauge"
          gridPos = { h = 4, w = 6, x = 12, y = 0 }
          targets = [{ expr = "histogram_quantile(0.99, sum(rate(coderd_api_request_latencies_seconds_bucket[5m])) by (le))" }]
          fieldConfig = {
            defaults = {
              unit = "s"
              thresholds = {
                steps = [
                  { color = "green", value = null },
                  { color = "yellow", value = 0.5 },
                  { color = "red", value = 1 }
                ]
              }
            }
          }
        },
        {
          title   = "Workspace Builds"
          type    = "timeseries"
          gridPos = { h = 8, w = 12, x = 0, y = 4 }
          targets = [{ expr = "sum(rate(coderd_workspace_builds_total[5m])) by (status)", legendFormat = "{{status}}" }]
        },
        {
          title   = "Provisioner Jobs"
          type    = "timeseries"
          gridPos = { h = 8, w = 12, x = 12, y = 4 }
          targets = [{ expr = "sum(coderd_provisioner_jobs_current) by (status)", legendFormat = "{{status}}" }]
        }
      ]
    })
  }
}


# =============================================================================
# Service Account Token Management
# Requirements: 12d.3, 12d.6, 12d.7, 12d.8, 12d.9
# =============================================================================
#
# This section manages the infrastructure for CI/CD service account tokens:
# - Secrets Manager secret for secure token storage (12d.8)
# - IAM policy for CI/CD systems to access the token
# - CloudWatch alarm for token expiration monitoring (12d.6)
#
# Note: The actual Coder API token must be created via Coder CLI and stored
# in the Secrets Manager secret. See terraform/docs/service-account-token-management.md
# for detailed procedures.
#
# Token Requirements:
# - 90-day expiration (12d.6)
# - Template Admin scope only (12d.7)
# - Immediate revocation on compromise (12d.9)

# Secrets Manager secret for CI/CD service account token
resource "aws_secretsmanager_secret" "cicd_token" {
  count = var.enable_cicd_service_account ? 1 : 0

  name        = var.cicd_token_secret_name
  description = "Coder service account token for CI/CD template deployment (Requirement 12d.8)"

  # Enable recovery window for accidental deletion protection
  recovery_window_in_days = 7

  tags = merge(var.tags, {
    Purpose         = "cicd-template-deployment"
    Environment     = var.environment
    TokenUser       = var.cicd_service_account_name
    ExpirationDays  = tostring(var.cicd_token_expiration_days)
    ManagedBy       = "terraform"
    SecurityControl = "12d.8"
  })
}

# Initial placeholder value for the secret
# The actual token must be created via Coder CLI and stored here
resource "aws_secretsmanager_secret_version" "cicd_token" {
  count = var.enable_cicd_service_account ? 1 : 0

  secret_id = aws_secretsmanager_secret.cicd_token[0].id
  secret_string = jsonencode({
    token           = "PLACEHOLDER_REPLACE_WITH_ACTUAL_TOKEN"
    created_date    = timestamp()
    expiration_days = var.cicd_token_expiration_days
    user            = var.cicd_service_account_name
    scope           = "template-admin"
    notes           = "Create token via: coder tokens create --user ${var.cicd_service_account_name} --lifetime ${var.cicd_token_expiration_days * 24}h"
  })

  lifecycle {
    # Ignore changes to secret_string as it will be updated manually
    ignore_changes = [secret_string]
  }
}

# IAM policy for CI/CD systems to access the token
resource "aws_iam_policy" "cicd_token_access" {
  count = var.enable_cicd_service_account ? 1 : 0

  name        = "${var.project_name}-${var.environment}-coder-cicd-token-access"
  description = "Allow CI/CD systems to access Coder service account token (Requirement 12d.8)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGetCoderCICDToken"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.cicd_token[0].arn
      }
    ]
  })

  tags = merge(var.tags, {
    Purpose         = "cicd-token-access"
    SecurityControl = "12d.8"
  })
}

# CloudWatch metric for tracking token age
# This enables monitoring and alerting for token expiration
resource "aws_cloudwatch_metric_alarm" "cicd_token_expiration" {
  count = var.enable_cicd_service_account && var.security_alert_sns_topic_arn != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-coder-cicd-token-expiring"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ServiceAccountTokenDaysUntilExpiration"
  namespace           = "Coder/Security"
  period              = 86400 # 24 hours
  statistic           = "Minimum"
  threshold           = var.cicd_token_rotation_warning_days
  alarm_description   = "Coder CI/CD service account token is expiring within ${var.cicd_token_rotation_warning_days} days (Requirement 12d.6)"
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.security_alert_sns_topic_arn]
  ok_actions    = [var.security_alert_sns_topic_arn]

  dimensions = {
    TokenUser   = var.cicd_service_account_name
    Environment = var.environment
  }

  tags = merge(var.tags, {
    Purpose         = "token-expiration-monitoring"
    SecurityControl = "12d.6"
  })
}

# =============================================================================
# Service Account Token Outputs
# =============================================================================

