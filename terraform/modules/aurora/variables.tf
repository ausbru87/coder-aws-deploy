# Aurora Module Variables
# Requirements: 2.3, 3.2, 8.2, 8.4, 8.5, 8.7, 12.9

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "database_subnet_ids" {
  description = "Subnet IDs for database (should span multiple AZs for high availability)"
  type        = list(string)

  validation {
    condition     = length(var.database_subnet_ids) >= 2
    error_message = "At least 2 subnet IDs are required for Multi-AZ deployment."
  }
}

variable "allowed_security_groups" {
  description = "Security groups allowed to access the database (typically EKS node security group)"
  type        = list(string)
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version (use latest stable version)"
  type        = string
  default     = "15.4"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+", var.engine_version))
    error_message = "Engine version must be in format X.Y (e.g., 15.4)."
  }
}

variable "instance_count" {
  description = "Number of Aurora instances (minimum 2 for Multi-AZ with automated failover)"
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 2
    error_message = "At least 2 instances are required for Multi-AZ deployment with automated failover."
  }
}

variable "min_capacity" {
  description = "Minimum ACU capacity for Serverless v2 (0.5 to 128)"
  type        = number
  default     = 0.5

  validation {
    condition     = var.min_capacity >= 0.5 && var.min_capacity <= 128
    error_message = "Minimum capacity must be between 0.5 and 128 ACUs."
  }
}

variable "max_capacity" {
  description = "Maximum ACU capacity for Serverless v2 (0.5 to 128)"
  type        = number
  default     = 16

  validation {
    condition     = var.max_capacity >= 0.5 && var.max_capacity <= 128
    error_message = "Maximum capacity must be between 0.5 and 128 ACUs."
  }
}

variable "backup_retention_period" {
  description = "Number of days to retain backups (90 days minimum per Requirement 8.5)"
  type        = number
  default     = 90

  validation {
    condition     = var.backup_retention_period >= 90
    error_message = "Backup retention period must be at least 90 days per compliance requirements."
  }
}

variable "enable_cross_region_backup" {
  description = "Enable cross-region backup replication using AWS Backup (Requirement 8.7)"
  type        = bool
  default     = false
}

variable "backup_region" {
  description = "AWS region for cross-region backup replication (e.g., us-west-2)"
  type        = string
  default     = "us-west-2"
}

variable "enable_iam_auth" {
  description = "Enable IAM database authentication (Requirement 3.2)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
