# Aurora PostgreSQL Module for Coder Deployment
# Creates Aurora Serverless v2 cluster with multi-AZ and automated backups
# Requirements: 2.3, 8.2, 8.4, 8.5, 8.7, 12.9, 3.2

resource "random_password" "master" {
  length  = 32
  special = false
}

# Aurora Cluster Parameter Group for TLS enforcement
resource "aws_rds_cluster_parameter_group" "main" {
  family      = "aurora-postgresql${split(".", var.engine_version)[0]}"
  name        = "${var.project_name}-${var.environment}-aurora-params"
  description = "Aurora PostgreSQL cluster parameter group with TLS enforcement"

  # Enforce TLS connections (Requirement 12.9)
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Log connections for auditing
  parameter {
    name         = "log_connections"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Log disconnections for auditing
  parameter {
    name         = "log_disconnections"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-params"
  })
}

# Aurora DB Parameter Group for instance-level settings
resource "aws_db_parameter_group" "main" {
  family = "aurora-postgresql${split(".", var.engine_version)[0]}"
  name   = "${var.project_name}-${var.environment}-aurora-db-params"

  # Additional instance-level parameters can be added here

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-db-params"
  })
}

# Aurora Cluster
# Requirements: 2.3 (Multi-AZ PostgreSQL Serverless v2), 12.9 (AES-256 encryption, TLS)
resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.project_name}-${var.environment}-aurora"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = var.engine_version
  database_name      = "coder"
  master_username    = "coder_admin"
  master_password    = random_password.master.result

  db_subnet_group_name            = aws_db_subnet_group.main.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name

  # Serverless v2 configuration
  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  # Backup configuration for RPO compliance (Requirements: 8.2, 8.4, 8.5)
  # RPO target: 15 minutes - achieved via continuous backup with PITR
  backup_retention_period = var.backup_retention_period # 90 days per Requirement 8.5
  preferred_backup_window = "03:00-04:00"
  copy_tags_to_snapshot   = true

  # Enable IAM database authentication (Requirement 3.2)
  iam_database_authentication_enabled = var.enable_iam_auth

  # Encryption at rest with AES-256 (Requirement 12.9)
  storage_encrypted = true
  kms_key_id        = aws_kms_key.aurora.arn

  # High availability - Multi-AZ with automated failover (Requirement 2.3)
  deletion_protection       = var.environment == "prod" ? true : false
  skip_final_snapshot       = var.environment == "prod" ? false : true
  final_snapshot_identifier = var.environment == "prod" ? "${var.project_name}-${var.environment}-final-snapshot" : null

  # Logging for audit and troubleshooting
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Apply changes immediately in non-prod, during maintenance window in prod
  apply_immediately = var.environment != "prod"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora"
  })

  lifecycle {
    prevent_destroy = false
  }
}

# Aurora Instance (Serverless v2)
# Multi-AZ deployment with automated failover (Requirement 2.3)
resource "aws_rds_cluster_instance" "main" {
  count = var.instance_count # Default 2 for Multi-AZ with writer and reader

  identifier              = "${var.project_name}-${var.environment}-aurora-${count.index}"
  cluster_identifier      = aws_rds_cluster.main.id
  instance_class          = "db.serverless"
  engine                  = aws_rds_cluster.main.engine
  engine_version          = aws_rds_cluster.main.engine_version
  db_parameter_group_name = aws_db_parameter_group.main.name

  # Performance monitoring
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.aurora.arn
  performance_insights_retention_period = 7

  # Enhanced monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # Auto minor version upgrade for security patches
  auto_minor_version_upgrade = true

  # Apply changes immediately in non-prod
  apply_immediately = var.environment != "prod"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-${count.index}"
    Role = count.index == 0 ? "writer" : "reader"
  })
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-aurora-subnet-group"
  subnet_ids = var.database_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-subnet-group"
  })
}

# Security Group
resource "aws_security_group" "aurora" {
  name        = "${var.project_name}-${var.environment}-aurora-sg"
  description = "Security group for Aurora PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-sg"
  })
}

# KMS Key for encryption
resource "aws_kms_key" "aurora" {
  description             = "KMS key for Aurora cluster ${var.project_name}-${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-key"
  })
}

resource "aws_kms_alias" "aurora" {
  name          = "alias/${var.project_name}-${var.environment}-aurora"
  target_key_id = aws_kms_key.aurora.key_id
}

# Store credentials in Secrets Manager
resource "aws_secretsmanager_secret" "master" {
  name = "coder/${var.environment}/aurora-master"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "master" {
  secret_id = aws_secretsmanager_secret.master.id
  secret_string = jsonencode({
    username = aws_rds_cluster.main.master_username
    password = random_password.master.result
    host     = aws_rds_cluster.main.endpoint
    port     = aws_rds_cluster.main.port
    database = aws_rds_cluster.main.database_name
    engine   = "postgresql"
  })
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# =============================================================================
# Cross-Region Backup Replication using AWS Backup (Requirement 8.7)
# =============================================================================

# AWS Backup Vault in primary region
resource "aws_backup_vault" "primary" {
  count = var.enable_cross_region_backup ? 1 : 0

  name        = "${var.project_name}-${var.environment}-aurora-backup-vault"
  kms_key_arn = aws_kms_key.aurora.arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-backup-vault"
  })
}

# IAM Role for AWS Backup
resource "aws_iam_role" "backup" {
  count = var.enable_cross_region_backup ? 1 : 0

  name = "${var.project_name}-${var.environment}-aurora-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  count = var.enable_cross_region_backup ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  count = var.enable_cross_region_backup ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# AWS Backup Plan for Aurora with cross-region copy (Requirements: 8.4, 8.7)
resource "aws_backup_plan" "aurora" {
  count = var.enable_cross_region_backup ? 1 : 0

  name = "${var.project_name}-${var.environment}-aurora-backup-plan"

  # Daily backup rule with 90-day retention (Requirement 8.5)
  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.primary[0].name
    schedule          = "cron(0 5 * * ? *)" # Daily at 5 AM UTC

    # Lifecycle - 90 day retention per Requirement 8.5
    lifecycle {
      delete_after = var.backup_retention_period
    }

    # Cross-region copy for disaster recovery (Requirement 8.7)
    copy_action {
      destination_vault_arn = "arn:aws:backup:${var.backup_region}:${data.aws_caller_identity.current.account_id}:backup-vault:${var.project_name}-${var.environment}-aurora-backup-vault-dr"

      lifecycle {
        delete_after = var.backup_retention_period
      }
    }

    # Enable continuous backup for point-in-time recovery (Requirement 8.2)
    enable_continuous_backup = true
  }

  # Hourly backup for RPO compliance (Requirement 8.4 - 15 min RPO)
  # Note: Aurora continuous backup provides PITR within 5 minutes
  rule {
    rule_name         = "hourly-backup"
    target_vault_name = aws_backup_vault.primary[0].name
    schedule          = "cron(0 * * * ? *)" # Every hour

    lifecycle {
      delete_after = 7 # Keep hourly backups for 7 days
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-backup-plan"
  })
}

# Backup Selection - Associate Aurora cluster with backup plan
resource "aws_backup_selection" "aurora" {
  count = var.enable_cross_region_backup ? 1 : 0

  name         = "${var.project_name}-${var.environment}-aurora-backup-selection"
  plan_id      = aws_backup_plan.aurora[0].id
  iam_role_arn = aws_iam_role.backup[0].arn

  resources = [
    aws_rds_cluster.main.arn
  ]
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# =============================================================================
# IAM Database Authentication (Requirement 3.2)
# =============================================================================

# IAM Policy for database authentication
# This policy allows IAM roles to connect to the Aurora cluster using IAM auth
resource "aws_iam_policy" "aurora_iam_auth" {
  count = var.enable_iam_auth ? 1 : 0

  name        = "${var.project_name}-${var.environment}-aurora-iam-auth"
  description = "Policy for IAM database authentication to Aurora PostgreSQL"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowIAMDatabaseAuthentication"
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = [
          "arn:aws:rds-db:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_rds_cluster.main.cluster_resource_id}/*"
        ]
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-iam-auth"
  })
}

# Data source for current region
data "aws_region" "current" {}

# =============================================================================
# CloudWatch Alarms for Aurora Monitoring
# =============================================================================

# CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-aurora-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Aurora cluster CPU utilization is high"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.cluster_identifier
  }

  tags = var.tags
}

# Database Connections Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_connections" {
  alarm_name          = "${var.project_name}-${var.environment}-aurora-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "Aurora cluster database connections are high"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.cluster_identifier
  }

  tags = var.tags
}

# Freeable Memory Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-aurora-memory-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 1073741824 # 1GB in bytes
  alarm_description   = "Aurora cluster freeable memory is low"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.cluster_identifier
  }

  tags = var.tags
}

# Serverless Database Capacity Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_capacity" {
  alarm_name          = "${var.project_name}-${var.environment}-aurora-capacity-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "ServerlessDatabaseCapacity"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.max_capacity * 0.8 # Alert at 80% of max capacity
  alarm_description   = "Aurora Serverless v2 capacity is approaching maximum"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.cluster_identifier
  }

  tags = var.tags
}
