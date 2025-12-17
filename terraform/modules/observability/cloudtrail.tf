# CloudTrail Configuration for Security Monitoring
# Requirements: 3.5
#
# Enables CloudTrail logging for:
# - API activity monitoring
# - Security event tracking
# - Compliance auditing

# =============================================================================
# CloudTrail S3 Bucket
# =============================================================================

resource "aws_s3_bucket" "cloudtrail" {
  count  = var.enable_cloudtrail && var.cloudtrail_s3_bucket_name == "" ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-cloudtrail-${local.account_id}"

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-cloudtrail"
    Purpose = "CloudTrail logs storage"
  })
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  count  = var.enable_cloudtrail && var.cloudtrail_s3_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  count  = var.enable_cloudtrail && var.cloudtrail_s3_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  count  = var.enable_cloudtrail && var.cloudtrail_s3_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  count  = var.enable_cloudtrail && var.cloudtrail_s3_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    id     = "cloudtrail-retention"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555 # 7 years for compliance
    }
  }
}

# S3 bucket policy for CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail" {
  count  = var.enable_cloudtrail && var.cloudtrail_s3_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${local.account_id}:trail/${var.project_name}-${var.environment}"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/AWSLogs/${local.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${local.account_id}:trail/${var.project_name}-${var.environment}"
          }
        }
      }
    ]
  })
}

# =============================================================================
# CloudTrail
# =============================================================================

resource "aws_cloudtrail" "main" {
  count = var.enable_cloudtrail ? 1 : 0

  name                          = "${var.project_name}-${var.environment}"
  s3_bucket_name                = var.cloudtrail_s3_bucket_name != "" ? var.cloudtrail_s3_bucket_name : aws_s3_bucket.cloudtrail[0].id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true

  # CloudWatch Logs integration
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail[0].arn

  # Event selectors for management and data events
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    # Log S3 data events for the CloudTrail bucket
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3"]
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-cloudtrail"
  })

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# CloudWatch Log Group for CloudTrail
resource "aws_cloudwatch_log_group" "cloudtrail" {
  count             = var.enable_cloudtrail ? 1 : 0
  name              = "/aws/cloudtrail/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-cloudtrail-logs"
    Purpose = "CloudTrail logs"
  })
}

# IAM Role for CloudTrail to write to CloudWatch Logs
resource "aws_iam_role" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0
  name  = "${var.project_name}-${var.environment}-cloudtrail-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0
  name  = "${var.project_name}-${var.environment}-cloudtrail-policy"
  role  = aws_iam_role.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
    }]
  })
}
