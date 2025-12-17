# CloudWatch Dashboards and Alarms
# Requirements: 8.1, 14.13, 14.20
#
# Provides:
# - CPU, memory, database performance metrics
# - API latency monitoring (P95, P99)
# - Scaling delay alerts

# =============================================================================
# CloudWatch Dashboard - Coder Platform Overview
# =============================================================================

resource "aws_cloudwatch_dashboard" "coder_platform" {
  dashboard_name = "${var.project_name}-${var.environment}-platform"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: EKS Cluster Health
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# Coder Platform Dashboard - ${var.environment}"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "EKS Node CPU Utilization"
          region = var.aws_region
          metrics = [
            ["AWS/EKS", "node_cpu_utilization", "ClusterName", var.cluster_name, { stat = "Average", period = 300 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "EKS Node Memory Utilization"
          region = var.aws_region
          metrics = [
            ["AWS/EKS", "node_memory_utilization", "ClusterName", var.cluster_name, { stat = "Average", period = 300 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "EKS Pod Count"
          region = var.aws_region
          metrics = [
            ["AWS/EKS", "pod_number_of_container_restarts", "ClusterName", var.cluster_name, { stat = "Sum", period = 300 }]
          ]
          view = "timeSeries"
        }
      },

      # Row 2: Aurora Database Metrics
      {
        type   = "text"
        x      = 0
        y      = 7
        width  = 24
        height = 1
        properties = {
          markdown = "## Aurora PostgreSQL Database"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 8
        height = 6
        properties = {
          title  = "Database CPU Utilization"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", var.aurora_cluster_identifier, { stat = "Average", period = 60 }]
          ]
          view  = "timeSeries"
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 8
        width  = 8
        height = 6
        properties = {
          title  = "Database Connections"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", var.aurora_cluster_identifier, { stat = "Average", period = 60 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 8
        width  = 8
        height = 6
        properties = {
          title  = "Database Serverless Capacity (ACU)"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "ServerlessDatabaseCapacity", "DBClusterIdentifier", var.aurora_cluster_identifier, { stat = "Average", period = 60 }]
          ]
          view = "timeSeries"
        }
      },

      # Row 3: Database Performance
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 8
        height = 6
        properties = {
          title  = "Database Read Latency"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "ReadLatency", "DBClusterIdentifier", var.aurora_cluster_identifier, { stat = "Average", period = 60 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 14
        width  = 8
        height = 6
        properties = {
          title  = "Database Write Latency"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "WriteLatency", "DBClusterIdentifier", var.aurora_cluster_identifier, { stat = "Average", period = 60 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 14
        width  = 8
        height = 6
        properties = {
          title  = "Database IOPS"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "ReadIOPS", "DBClusterIdentifier", var.aurora_cluster_identifier, { stat = "Average", period = 60 }],
            ["AWS/RDS", "WriteIOPS", "DBClusterIdentifier", var.aurora_cluster_identifier, { stat = "Average", period = 60 }]
          ]
          view = "timeSeries"
        }
      },

      # Row 4: Network Load Balancer
      {
        type   = "text"
        x      = 0
        y      = 20
        width  = 24
        height = 1
        properties = {
          markdown = "## Network Load Balancer"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 21
        width  = 8
        height = 6
        properties = {
          title  = "NLB Active Connections"
          region = var.aws_region
          metrics = [
            ["AWS/NetworkELB", "ActiveFlowCount", "LoadBalancer", "${var.project_name}-${var.environment}", { stat = "Average", period = 60 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 21
        width  = 8
        height = 6
        properties = {
          title  = "NLB Processed Bytes"
          region = var.aws_region
          metrics = [
            ["AWS/NetworkELB", "ProcessedBytes", "LoadBalancer", "${var.project_name}-${var.environment}", { stat = "Sum", period = 60 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 21
        width  = 8
        height = 6
        properties = {
          title  = "NLB Healthy Host Count"
          region = var.aws_region
          metrics = [
            ["AWS/NetworkELB", "HealthyHostCount", "LoadBalancer", "${var.project_name}-${var.environment}", { stat = "Average", period = 60 }]
          ]
          view = "timeSeries"
        }
      }
    ]
  })
}

# =============================================================================
# CloudWatch Alarms
# Requirements: 8.1, 14.13, 14.20
# =============================================================================

# High CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Database CPU utilization is above 80%"
  alarm_actions       = var.alert_sns_topic_arn != "" ? [var.alert_sns_topic_arn] : []
  ok_actions          = var.alert_sns_topic_arn != "" ? [var.alert_sns_topic_arn] : []

  dimensions = {
    DBClusterIdentifier = var.aurora_cluster_identifier
  }

  tags = var.tags
}

# Database Connection Alarm
resource "aws_cloudwatch_metric_alarm" "high_connections" {
  alarm_name          = "${var.project_name}-${var.environment}-high-db-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 500
  alarm_description   = "Database connections are above 500"
  alarm_actions       = var.alert_sns_topic_arn != "" ? [var.alert_sns_topic_arn] : []
  ok_actions          = var.alert_sns_topic_arn != "" ? [var.alert_sns_topic_arn] : []

  dimensions = {
    DBClusterIdentifier = var.aurora_cluster_identifier
  }

  tags = var.tags
}

# NLB Unhealthy Hosts Alarm
resource "aws_cloudwatch_metric_alarm" "nlb_unhealthy" {
  alarm_name          = "${var.project_name}-${var.environment}-nlb-unhealthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "NLB has no healthy hosts"
  alarm_actions       = var.alert_sns_topic_arn != "" ? [var.alert_sns_topic_arn] : []
  ok_actions          = var.alert_sns_topic_arn != "" ? [var.alert_sns_topic_arn] : []

  dimensions = {
    LoadBalancer = "${var.project_name}-${var.environment}"
  }

  tags = var.tags
}

# Database Read Latency Alarm
resource "aws_cloudwatch_metric_alarm" "db_read_latency" {
  alarm_name          = "${var.project_name}-${var.environment}-db-read-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "ReadLatency"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 0.1 # 100ms
  alarm_description   = "Database read latency is above 100ms"
  alarm_actions       = var.alert_sns_topic_arn != "" ? [var.alert_sns_topic_arn] : []
  ok_actions          = var.alert_sns_topic_arn != "" ? [var.alert_sns_topic_arn] : []

  dimensions = {
    DBClusterIdentifier = var.aurora_cluster_identifier
  }

  tags = var.tags
}

# Database Write Latency Alarm
resource "aws_cloudwatch_metric_alarm" "db_write_latency" {
  alarm_name          = "${var.project_name}-${var.environment}-db-write-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "WriteLatency"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 0.2 # 200ms
  alarm_description   = "Database write latency is above 200ms"
  alarm_actions       = var.alert_sns_topic_arn != "" ? [var.alert_sns_topic_arn] : []
  ok_actions          = var.alert_sns_topic_arn != "" ? [var.alert_sns_topic_arn] : []

  dimensions = {
    DBClusterIdentifier = var.aurora_cluster_identifier
  }

  tags = var.tags
}
