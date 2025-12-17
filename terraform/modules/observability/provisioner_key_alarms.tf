# Provisioner Key Monitoring Alarms
# Implements expiration monitoring and alerting for provisioner keys
#
# Requirements:
# - 12f.2: Keys SHALL be rotated every 90 days
# - 12f.3: Immediate key revocation on compromise
#
# This module creates CloudWatch alarms that monitor provisioner key expiration
# based on custom metrics published by the key expiration monitoring script.

# =============================================================================
# SNS Topics for Provisioner Key Alerts
# =============================================================================

resource "aws_sns_topic" "provisioner_key_alerts" {
  count = var.enable_provisioner_key_monitoring ? 1 : 0

  name = "${var.project_name}-${var.environment}-provisioner-key-alerts"

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-provisioner-key-alerts"
    Purpose = "Provisioner key expiration alerts"
  })
}

resource "aws_sns_topic" "provisioner_key_critical" {
  count = var.enable_provisioner_key_monitoring ? 1 : 0

  name = "${var.project_name}-${var.environment}-provisioner-key-critical"

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-provisioner-key-critical"
    Purpose = "Critical provisioner key alerts"
  })
}

# =============================================================================
# CloudWatch Alarms for Provisioner Key Expiration
# Requirement 12f.2: 90-day rotation with 14-day advance warning
# =============================================================================

# 14-day warning alarm
resource "aws_cloudwatch_metric_alarm" "provisioner_key_expiration_14day" {
  count = var.enable_provisioner_key_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-provisioner-key-expiration-14day"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ProvisionerKeyDaysUntilExpiration"
  namespace           = "Coder/Security"
  period              = 86400 # 24 hours
  statistic           = "Minimum"
  threshold           = var.provisioner_key_warning_days
  alarm_description   = "Provisioner key expires in ${var.provisioner_key_warning_days} days or less. Schedule key rotation."
  treat_missing_data  = "breaching"

  alarm_actions = var.alert_sns_topic_arn != "" ? [var.alert_sns_topic_arn] : (
    var.enable_provisioner_key_monitoring ? [aws_sns_topic.provisioner_key_alerts[0].arn] : []
  )
  ok_actions = var.alert_sns_topic_arn != "" ? [var.alert_sns_topic_arn] : (
    var.enable_provisioner_key_monitoring ? [aws_sns_topic.provisioner_key_alerts[0].arn] : []
  )

  dimensions = {
    KeyName = var.provisioner_key_name
  }

  tags = merge(var.tags, {
    Name     = "${var.project_name}-${var.environment}-provisioner-key-expiration-14day"
    Severity = "warning"
  })
}

# 7-day warning alarm
resource "aws_cloudwatch_metric_alarm" "provisioner_key_expiration_7day" {
  count = var.enable_provisioner_key_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-provisioner-key-expiration-7day"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ProvisionerKeyDaysUntilExpiration"
  namespace           = "Coder/Security"
  period              = 86400 # 24 hours
  statistic           = "Minimum"
  threshold           = 7
  alarm_description   = "URGENT: Provisioner key expires in 7 days or less. Immediate rotation required."
  treat_missing_data  = "breaching"

  alarm_actions = var.alert_sns_topic_arn != "" ? [var.alert_sns_topic_arn] : (
    var.enable_provisioner_key_monitoring ? [aws_sns_topic.provisioner_key_alerts[0].arn] : []
  )
  ok_actions = var.alert_sns_topic_arn != "" ? [var.alert_sns_topic_arn] : (
    var.enable_provisioner_key_monitoring ? [aws_sns_topic.provisioner_key_alerts[0].arn] : []
  )

  dimensions = {
    KeyName = var.provisioner_key_name
  }

  tags = merge(var.tags, {
    Name     = "${var.project_name}-${var.environment}-provisioner-key-expiration-7day"
    Severity = "high"
  })
}

# 2-day critical alarm
resource "aws_cloudwatch_metric_alarm" "provisioner_key_expiration_critical" {
  count = var.enable_provisioner_key_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-provisioner-key-expiration-critical"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ProvisionerKeyDaysUntilExpiration"
  namespace           = "Coder/Security"
  period              = 3600 # 1 hour - more frequent checks when critical
  statistic           = "Minimum"
  threshold           = 2
  alarm_description   = "CRITICAL: Provisioner key expires in 2 days or less. Service disruption imminent if not rotated."
  treat_missing_data  = "breaching"

  alarm_actions = var.enable_provisioner_key_monitoring ? [aws_sns_topic.provisioner_key_critical[0].arn] : []
  ok_actions    = var.enable_provisioner_key_monitoring ? [aws_sns_topic.provisioner_key_critical[0].arn] : []

  dimensions = {
    KeyName = var.provisioner_key_name
  }

  tags = merge(var.tags, {
    Name     = "${var.project_name}-${var.environment}-provisioner-key-expiration-critical"
    Severity = "critical"
  })
}

# =============================================================================
# Provisioner Health Monitoring
# =============================================================================

# Alarm for provisioner disconnection
resource "aws_cloudwatch_metric_alarm" "provisioner_disconnected" {
  count = var.enable_provisioner_key_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-provisioner-disconnected"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "ProvisionerConnectedCount"
  namespace           = "Coder/Provisioners"
  period              = 300 # 5 minutes
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "No provisioners connected. Check provisioner key validity and pod health."
  treat_missing_data  = "breaching"

  alarm_actions = var.enable_provisioner_key_monitoring ? [aws_sns_topic.provisioner_key_critical[0].arn] : []
  ok_actions    = var.enable_provisioner_key_monitoring ? [aws_sns_topic.provisioner_key_critical[0].arn] : []

  tags = merge(var.tags, {
    Name     = "${var.project_name}-${var.environment}-provisioner-disconnected"
    Severity = "critical"
  })
}

# =============================================================================
# CloudWatch Dashboard for Provisioner Key Monitoring
# =============================================================================

resource "aws_cloudwatch_dashboard" "provisioner_key_monitoring" {
  count = var.enable_provisioner_key_monitoring ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-provisioner-key-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Provisioner Key Days Until Expiration"
          region = var.aws_region
          metrics = [
            ["Coder/Security", "ProvisionerKeyDaysUntilExpiration", "KeyName", var.provisioner_key_name]
          ]
          view    = "timeSeries"
          stacked = false
          period  = 86400
          stat    = "Minimum"
          annotations = {
            horizontal = [
              {
                label = "14-day warning"
                value = 14
                color = "#ff7f0e"
              },
              {
                label = "7-day warning"
                value = 7
                color = "#d62728"
              },
              {
                label = "Critical"
                value = 2
                color = "#9467bd"
              }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Connected Provisioners"
          region = var.aws_region
          metrics = [
            ["Coder/Provisioners", "ProvisionerConnectedCount"]
          ]
          view    = "timeSeries"
          stacked = false
          period  = 300
          stat    = "Average"
        }
      },
      {
        type   = "alarm"
        x      = 0
        y      = 6
        width  = 24
        height = 3
        properties = {
          title = "Provisioner Key Alarms"
          alarms = var.enable_provisioner_key_monitoring ? [
            aws_cloudwatch_metric_alarm.provisioner_key_expiration_14day[0].arn,
            aws_cloudwatch_metric_alarm.provisioner_key_expiration_7day[0].arn,
            aws_cloudwatch_metric_alarm.provisioner_key_expiration_critical[0].arn,
            aws_cloudwatch_metric_alarm.provisioner_disconnected[0].arn
          ] : []
        }
      },
      {
        type   = "text"
        x      = 0
        y      = 9
        width  = 24
        height = 3
        properties = {
          markdown = <<-EOF
            ## Provisioner Key Management
            
            **Rotation Policy:** Keys must be rotated every 90 days (Requirement 12f.2)
            
            **Alert Thresholds:**
            - 🟡 **14 days:** Schedule rotation
            - 🟠 **7 days:** Urgent - rotate immediately
            - 🔴 **2 days:** Critical - service disruption imminent
            
            **Runbook:** [Provisioner Key Rotation Procedure](https://docs.internal/coder/provisioner-key-rotation)
          EOF
        }
      }
    ]
  })
}

# =============================================================================
# Outputs
# =============================================================================

output "provisioner_key_alerts_topic_arn" {
  description = "SNS topic ARN for provisioner key alerts"
  value       = var.enable_provisioner_key_monitoring ? aws_sns_topic.provisioner_key_alerts[0].arn : null
}

output "provisioner_key_critical_topic_arn" {
  description = "SNS topic ARN for critical provisioner key alerts"
  value       = var.enable_provisioner_key_monitoring ? aws_sns_topic.provisioner_key_critical[0].arn : null
}

output "provisioner_key_dashboard_name" {
  description = "CloudWatch dashboard name for provisioner key monitoring"
  value       = var.enable_provisioner_key_monitoring ? aws_cloudwatch_dashboard.provisioner_key_monitoring[0].dashboard_name : null
}
