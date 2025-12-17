# Aurora Module Outputs
# Requirements: 2.3, 3.2, 8.2, 8.4, 8.5, 8.7, 12.9

# =============================================================================
# Cluster Connection Information
# =============================================================================

output "cluster_endpoint" {
  description = "Aurora cluster writer endpoint (use for read-write operations)"
  value       = aws_rds_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint (use for read-only operations)"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "cluster_port" {
  description = "Aurora cluster port (default: 5432)"
  value       = aws_rds_cluster.main.port
}

output "database_name" {
  description = "Name of the database"
  value       = aws_rds_cluster.main.database_name
}

# =============================================================================
# Cluster Identification
# =============================================================================

output "cluster_id" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.main.id
}

output "cluster_arn" {
  description = "Aurora cluster ARN"
  value       = aws_rds_cluster.main.arn
}

output "cluster_resource_id" {
  description = "Aurora cluster resource ID (used for IAM authentication)"
  value       = aws_rds_cluster.main.cluster_resource_id
}

# =============================================================================
# Authentication and Secrets
# =============================================================================

output "master_secret_arn" {
  description = "ARN of the Secrets Manager secret containing master credentials"
  value       = aws_secretsmanager_secret.master.arn
}

output "master_secret_name" {
  description = "Name of the Secrets Manager secret containing master credentials"
  value       = aws_secretsmanager_secret.master.name
}

output "iam_auth_enabled" {
  description = "Whether IAM database authentication is enabled"
  value       = aws_rds_cluster.main.iam_database_authentication_enabled
}

# =============================================================================
# Security
# =============================================================================

output "security_group_id" {
  description = "Security group ID for Aurora"
  value       = aws_security_group.aurora.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption at rest"
  value       = aws_kms_key.aurora.arn
}

output "kms_key_id" {
  description = "ID of the KMS key used for encryption at rest"
  value       = aws_kms_key.aurora.key_id
}

# =============================================================================
# Backup and Recovery
# =============================================================================

output "backup_retention_period" {
  description = "Number of days backups are retained"
  value       = aws_rds_cluster.main.backup_retention_period
}

output "backup_vault_arn" {
  description = "ARN of the AWS Backup vault (if cross-region backup is enabled)"
  value       = var.enable_cross_region_backup ? aws_backup_vault.primary[0].arn : null
}

output "backup_plan_arn" {
  description = "ARN of the AWS Backup plan (if cross-region backup is enabled)"
  value       = var.enable_cross_region_backup ? aws_backup_plan.aurora[0].arn : null
}

# =============================================================================
# Connection String Helpers
# =============================================================================

output "connection_string_template" {
  description = "PostgreSQL connection string template (replace PASSWORD with actual password)"
  value       = "postgresql://${aws_rds_cluster.main.master_username}:PASSWORD@${aws_rds_cluster.main.endpoint}:${aws_rds_cluster.main.port}/${aws_rds_cluster.main.database_name}?sslmode=require"
}

output "jdbc_connection_string_template" {
  description = "JDBC connection string template for Java applications"
  value       = "jdbc:postgresql://${aws_rds_cluster.main.endpoint}:${aws_rds_cluster.main.port}/${aws_rds_cluster.main.database_name}?ssl=true&sslmode=require"
}

# =============================================================================
# Instance Information
# =============================================================================

output "instance_identifiers" {
  description = "List of Aurora instance identifiers"
  value       = aws_rds_cluster_instance.main[*].identifier
}

output "instance_endpoints" {
  description = "List of Aurora instance endpoints"
  value       = aws_rds_cluster_instance.main[*].endpoint
}


# =============================================================================
# IAM Authentication
# =============================================================================

output "iam_auth_policy_arn" {
  description = "ARN of the IAM policy for database authentication (if IAM auth is enabled)"
  value       = var.enable_iam_auth ? aws_iam_policy.aurora_iam_auth[0].arn : null
}

output "iam_auth_policy_name" {
  description = "Name of the IAM policy for database authentication (if IAM auth is enabled)"
  value       = var.enable_iam_auth ? aws_iam_policy.aurora_iam_auth[0].name : null
}

# =============================================================================
# Monitoring
# =============================================================================

output "cloudwatch_alarm_cpu_arn" {
  description = "ARN of the CloudWatch alarm for CPU utilization"
  value       = aws_cloudwatch_metric_alarm.aurora_cpu.arn
}

output "cloudwatch_alarm_connections_arn" {
  description = "ARN of the CloudWatch alarm for database connections"
  value       = aws_cloudwatch_metric_alarm.aurora_connections.arn
}

output "cloudwatch_alarm_memory_arn" {
  description = "ARN of the CloudWatch alarm for freeable memory"
  value       = aws_cloudwatch_metric_alarm.aurora_memory.arn
}

output "cloudwatch_alarm_capacity_arn" {
  description = "ARN of the CloudWatch alarm for Serverless v2 capacity"
  value       = aws_cloudwatch_metric_alarm.aurora_capacity.arn
}
