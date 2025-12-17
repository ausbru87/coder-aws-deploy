# Observability Module for Coder Deployment
# Implements logging, monitoring, and alerting infrastructure
#
# Components:
# - Fluent Bit DaemonSet for container log aggregation (Requirements: 3.7, 3.8)
# - CloudWatch Log Groups for Coder audit logs (Requirements: 3.6, 3.8)
# - VPC Flow Logs and CloudTrail (Requirements: 3.5)
# - CloudWatch Dashboards and Alarms (Requirements: 8.1, 14.13, 14.20)
# - Prometheus metrics configuration (Requirements: 8.1a, 8.1b, 8.1c)

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Log group names
  container_logs_group = "/aws/eks/${var.cluster_name}/containers"
  coder_audit_group    = "/aws/eks/${var.cluster_name}/coder-audit"
  fluent_bit_group     = "/aws/eks/${var.cluster_name}/fluent-bit"

  # OIDC provider for IRSA
  oidc_provider = replace(var.cluster_oidc_issuer_url, "https://", "")
}

# =============================================================================
# CloudWatch Log Groups
# Requirements: 3.6, 3.7, 3.8
# =============================================================================

# Container logs from all EKS pods
resource "aws_cloudwatch_log_group" "container_logs" {
  name              = local.container_logs_group
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-container-logs"
    Purpose = "EKS container logs"
  })
}

# Coder audit logs - separate log group for compliance
resource "aws_cloudwatch_log_group" "coder_audit" {
  name              = local.coder_audit_group
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-coder-audit"
    Purpose = "Coder audit logs"
  })
}

# Fluent Bit operational logs
resource "aws_cloudwatch_log_group" "fluent_bit" {
  name              = local.fluent_bit_group
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-fluent-bit"
    Purpose = "Fluent Bit operational logs"
  })
}

# =============================================================================
# IAM Role for Fluent Bit (IRSA)
# =============================================================================

resource "aws_iam_role" "fluent_bit" {
  name = "${var.project_name}-${var.environment}-fluent-bit"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.cluster_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider}:aud" = "sts.amazonaws.com"
          "${local.oidc_provider}:sub" = "system:serviceaccount:amazon-cloudwatch:fluent-bit"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "fluent_bit" {
  name = "${var.project_name}-${var.environment}-fluent-bit-policy"
  role = aws_iam_role.fluent_bit.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.container_logs.arn}:*",
          "${aws_cloudwatch_log_group.coder_audit.arn}:*",
          "${aws_cloudwatch_log_group.fluent_bit.arn}:*"
        ]
      }
    ]
  })
}

# =============================================================================
# Kubernetes Namespace for Observability
# =============================================================================

resource "kubernetes_namespace_v1" "amazon_cloudwatch" {
  metadata {
    name = "amazon-cloudwatch"
    labels = {
      "app.kubernetes.io/name"       = "amazon-cloudwatch"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# =============================================================================
# Fluent Bit DaemonSet via Helm
# Requirements: 3.7, 3.8
# =============================================================================

resource "helm_release" "fluent_bit" {
  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  version    = var.fluent_bit_version
  namespace  = kubernetes_namespace_v1.amazon_cloudwatch.metadata[0].name

  values = [
    yamlencode({
      image = {
        tag = var.fluent_bit_image_tag
      }

      serviceAccount = {
        create = true
        name   = "fluent-bit"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.fluent_bit.arn
        }
      }

      # DaemonSet configuration - runs on all nodes
      tolerations = [
        {
          key      = "coder-control"
          operator = "Exists"
          effect   = "NoSchedule"
        },
        {
          key      = "coder-prov"
          operator = "Exists"
          effect   = "NoSchedule"
        },
        {
          key      = "coder-ws"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      ]

      # Resource limits
      resources = {
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
      }

      # Fluent Bit configuration
      config = {
        service = <<-EOF
          [SERVICE]
              Daemon Off
              Flush 5
              Log_Level info
              Parsers_File /fluent-bit/etc/parsers.conf
              HTTP_Server On
              HTTP_Listen 0.0.0.0
              HTTP_Port 2020
              Health_Check On
        EOF

        inputs = <<-EOF
          [INPUT]
              Name tail
              Path /var/log/containers/*.log
              multiline.parser docker, cri
              Tag kube.*
              Mem_Buf_Limit 50MB
              Skip_Long_Lines On
              Refresh_Interval 10

          [INPUT]
              Name tail
              Path /var/log/containers/*coder*.log
              multiline.parser docker, cri
              Tag coder.*
              Mem_Buf_Limit 50MB
              Skip_Long_Lines On
              Refresh_Interval 5
        EOF

        filters = <<-EOF
          [FILTER]
              Name kubernetes
              Match kube.*
              Merge_Log On
              Keep_Log Off
              K8S-Logging.Parser On
              K8S-Logging.Exclude On
              Labels On
              Annotations Off

          [FILTER]
              Name kubernetes
              Match coder.*
              Merge_Log On
              Keep_Log Off
              K8S-Logging.Parser On
              K8S-Logging.Exclude On
              Labels On
              Annotations Off

          # Filter for Coder audit logs
          [FILTER]
              Name grep
              Match coder.*
              Regex log audit
        EOF

        outputs = <<-EOF
          # General container logs
          [OUTPUT]
              Name cloudwatch_logs
              Match kube.*
              region ${var.aws_region}
              log_group_name ${local.container_logs_group}
              log_stream_prefix eks-
              auto_create_group false
              log_retention_days ${var.log_retention_days}

          # Coder audit logs - separate stream for compliance
          [OUTPUT]
              Name cloudwatch_logs
              Match coder.*
              region ${var.aws_region}
              log_group_name ${local.coder_audit_group}
              log_stream_prefix coder-
              auto_create_group false
              log_retention_days ${var.log_retention_days}
        EOF
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.amazon_cloudwatch,
    aws_cloudwatch_log_group.container_logs,
    aws_cloudwatch_log_group.coder_audit,
    aws_iam_role_policy.fluent_bit
  ]
}
