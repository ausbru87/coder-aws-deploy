# Observability Module Outputs

# =============================================================================
# CloudWatch Log Groups
# =============================================================================

output "container_logs_group_name" {
  description = "Name of the CloudWatch Log Group for container logs"
  value       = aws_cloudwatch_log_group.container_logs.name
}

output "container_logs_group_arn" {
  description = "ARN of the CloudWatch Log Group for container logs"
  value       = aws_cloudwatch_log_group.container_logs.arn
}

output "coder_audit_logs_group_name" {
  description = "Name of the CloudWatch Log Group for Coder audit logs"
  value       = aws_cloudwatch_log_group.coder_audit.name
}

output "coder_audit_logs_group_arn" {
  description = "ARN of the CloudWatch Log Group for Coder audit logs"
  value       = aws_cloudwatch_log_group.coder_audit.arn
}

output "fluent_bit_logs_group_name" {
  description = "Name of the CloudWatch Log Group for Fluent Bit operational logs"
  value       = aws_cloudwatch_log_group.fluent_bit.name
}

# =============================================================================
# CloudTrail
# =============================================================================

output "cloudtrail_name" {
  description = "Name of the CloudTrail trail"
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].name : null
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket for CloudTrail logs"
  value       = var.enable_cloudtrail && var.cloudtrail_s3_bucket_name == "" ? aws_s3_bucket.cloudtrail[0].id : var.cloudtrail_s3_bucket_name
}

output "cloudtrail_log_group_name" {
  description = "CloudWatch Log Group for CloudTrail"
  value       = var.enable_cloudtrail ? aws_cloudwatch_log_group.cloudtrail[0].name : null
}

# =============================================================================
# Fluent Bit
# =============================================================================

output "fluent_bit_role_arn" {
  description = "ARN of the Fluent Bit IAM role"
  value       = aws_iam_role.fluent_bit.arn
}

output "fluent_bit_helm_release_name" {
  description = "Name of the Fluent Bit Helm release"
  value       = helm_release.fluent_bit.name
}

output "fluent_bit_namespace" {
  description = "Kubernetes namespace for Fluent Bit"
  value       = kubernetes_namespace_v1.amazon_cloudwatch.metadata[0].name
}

# =============================================================================
# CloudWatch Dashboard
# =============================================================================

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.coder_platform.dashboard_name
}

output "dashboard_arn" {
  description = "ARN of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.coder_platform.dashboard_arn
}

# =============================================================================
# CloudWatch Alarms
# =============================================================================

output "alarm_high_cpu_arn" {
  description = "ARN of the high CPU alarm"
  value       = aws_cloudwatch_metric_alarm.high_cpu.arn
}

output "alarm_high_connections_arn" {
  description = "ARN of the high database connections alarm"
  value       = aws_cloudwatch_metric_alarm.high_connections.arn
}

output "alarm_nlb_unhealthy_arn" {
  description = "ARN of the NLB unhealthy hosts alarm"
  value       = aws_cloudwatch_metric_alarm.nlb_unhealthy.arn
}

output "alarm_db_read_latency_arn" {
  description = "ARN of the database read latency alarm"
  value       = aws_cloudwatch_metric_alarm.db_read_latency.arn
}

output "alarm_db_write_latency_arn" {
  description = "ARN of the database write latency alarm"
  value       = aws_cloudwatch_metric_alarm.db_write_latency.arn
}

# =============================================================================
# Log Retention
# =============================================================================

output "log_retention_days" {
  description = "Configured log retention period in days"
  value       = var.log_retention_days
}
