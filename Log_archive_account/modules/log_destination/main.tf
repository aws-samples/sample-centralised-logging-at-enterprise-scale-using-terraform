// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# KMS Keys for each service
resource "aws_kms_key" "service_kms_keys" {
  for_each = toset(local.services)

  description             = "KMS key for ${each.value} S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 and other services to use the key"
        Effect = "Allow"
        Principal = {
          Service = ["s3.amazonaws.com", "firehose.amazonaws.com", "events.amazonaws.com"]
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Firehose and EventBridge to use the key"
        Effect = "Allow"
        Principal = {
          Service = ["firehose.amazonaws.com", "events.amazonaws.com"]
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Service = each.value
  }
}

# Update KMS key policy for SQS to allow S3 to use the key
resource "aws_kms_key" "sqs_kms_keys" {
  for_each = toset(local.services)

  description             = "KMS key for ${each.value} SQS queue encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use the key"
        Effect = "Allow"
        Principal = {
          Service = ["s3.amazonaws.com", "sqs.amazonaws.com"]
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Service = each.value
  }
}

# S3 Buckets
resource "aws_s3_bucket" "logs_buckets" {
  for_each = toset(local.services)

  bucket        = "${var.environment}-${data.aws_region.current.name}-${each.value}-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  # Wait for bucket to be fully created
  lifecycle {
    create_before_destroy = true
  }
}

# Enable logging for S3 Buckets
resource "aws_s3_bucket_logging" "logs_buckets" {
  for_each = aws_s3_bucket.logs_buckets

  bucket = each.value.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "access-logs/${each.value.id}/"
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "logs_buckets" {
  for_each = aws_s3_bucket.logs_buckets

  bucket = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "logs_buckets_lifecycle" {
  for_each = aws_s3_bucket.logs_buckets

  bucket = each.value.id

  rule {
    id     = "logs_lifecycle"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555 # Approximately 7 years
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.logs_buckets]
}

# Block public access for S3 Buckets
resource "aws_s3_bucket_public_access_block" "logs_buckets" {
  for_each = aws_s3_bucket.logs_buckets

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "logs_buckets" {
  for_each = aws_s3_bucket.logs_buckets

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.service_kms_keys[each.key].arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# KMS Aliases for each service
resource "aws_kms_alias" "service_kms_aliases" {
  for_each = toset(local.services)

  name          = "alias/${var.environment}-${each.value}-s3-kms-key"
  target_key_id = aws_kms_key.service_kms_keys[each.value].key_id
}

# S3 Bucket Policy
resource "aws_s3_bucket_policy" "logs_buckets" {
  for_each = aws_s3_bucket.logs_buckets

  bucket = each.value.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3Operations"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "s3:PutObject",
          "s3:GetBucketNotification",
          "s3:PutBucketNotification"
        ]
        Resource = [
          each.value.arn,
          "${each.value.arn}/*"
        ]
      },
      {
        Sid    = "AllowSQSNotifications"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "s3:GetBucketNotification",
          "s3:PutBucketNotification"
        ]
        Resource = each.value.arn
      }
    ]
  })

  depends_on = [aws_s3_bucket.logs_buckets]
}

# SQS Queues
resource "aws_sqs_queue" "s3_event_queues" {
  for_each = toset(local.services)

  name                       = "${var.environment}-${data.aws_region.current.name}-${each.value}-s3-event-notification-queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600
  max_message_size           = 262144
  kms_master_key_id          = aws_kms_key.sqs_kms_keys[each.value].arn

  depends_on = [
    aws_s3_bucket.logs_buckets,
    aws_kms_key.sqs_kms_keys
  ]
}

resource "aws_sqs_queue_policy" "s3_event_queue_policy" {
  for_each = aws_sqs_queue.s3_event_queues

  queue_url = each.value.url
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "sqs:SendMessage"
        ]
        Resource = each.value.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.logs_buckets[each.key].arn
          }
        }
      }
    ]
  })
}

# S3 Bucket Notifications
resource "aws_s3_bucket_notification" "logs_buckets" {
  for_each = aws_s3_bucket.logs_buckets

  bucket = each.value.id

  queue {
    queue_arn = aws_sqs_queue.s3_event_queues[each.key].arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_sqs_queue.s3_event_queues,
    aws_sqs_queue_policy.s3_event_queue_policy
  ]
}

# CloudWatch Log Groups for Firehose
resource "aws_cloudwatch_log_group" "firehose_logs" {
  for_each          = toset(local.services)
  name              = "/aws/firehose/${var.environment}-${each.value}-logs-firehose-${data.aws_region.current.name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.cloudwatch.arn
}

# Customer Managed KMS Key for CloudWatch Logs
resource "aws_kms_key" "cloudwatch" {
  description              = "Customer managed key for CloudWatch Logs encryption"
  deletion_window_in_days  = 30
  enable_key_rotation      = true
  multi_region             = false
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  key_usage                = "ENCRYPT_DECRYPT"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Firehose Service"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-cloudwatch-logs-firehose-cmk"
    Environment = var.environment
    Purpose     = "CloudWatch Logs Encryption for Firehose"
  }

}

# KMS Alias for CloudWatch Logs
resource "aws_kms_alias" "cloudwatch" {
  name          = "alias/${var.environment}-cloudwatch-logs-firehose-cmk"
  target_key_id = aws_kms_key.cloudwatch.key_id
}


# CloudWatch Log Streams
resource "aws_cloudwatch_log_stream" "firehose_log_streams" {
  for_each = aws_cloudwatch_log_group.firehose_logs

  name           = "S3Delivery"
  log_group_name = each.value.name
}

# KMS Key for Firehose encryption
resource "aws_kms_key" "firehose_key" {
  description             = "KMS key for Firehose encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Firehose to use the key"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = var.environment
  }
}

# KMS Alias
resource "aws_kms_alias" "firehose_key_alias" {
  name          = "alias/${var.environment}-firehose-key"
  target_key_id = aws_kms_key.firehose_key.key_id
}


# Kinesis Firehose Delivery Streams
resource "aws_kinesis_firehose_delivery_stream" "logs_firehose" {
  for_each = toset(local.services)

  name        = "${var.environment}-${each.value}-logs-firehose-${data.aws_region.current.name}"
  destination = "extended_s3"

  server_side_encryption {
    enabled  = true
    key_type = "CUSTOMER_MANAGED_CMK"
    key_arn  = aws_kms_key.firehose_key.arn
  }

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose_role.arn
    bucket_arn          = aws_s3_bucket.logs_buckets[each.key].arn
    prefix              = "AWSLogs/${data.aws_region.current.name}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    compression_format  = "GZIP"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_logs[each.key].name
      log_stream_name = aws_cloudwatch_log_stream.firehose_log_streams[each.key].name
    }
  }

  depends_on = [
    aws_s3_bucket.logs_buckets,
    aws_iam_role.firehose_role,
    aws_kms_key.firehose_key
  ]
}

# CloudWatch Log Destinations
resource "aws_cloudwatch_log_destination" "test_destinations" {
  for_each = toset(local.services)

  name       = "${var.destination_name}-${each.value}-${data.aws_region.current.name}"
  role_arn   = aws_iam_role.cloudwatch_destination_role.arn
  target_arn = aws_kinesis_firehose_delivery_stream.logs_firehose[each.key].arn

  depends_on = [aws_kinesis_firehose_delivery_stream.logs_firehose]
}

# CloudWatch Log Destination Policies
resource "aws_cloudwatch_log_destination_policy" "test_destination_policies" {
  for_each = aws_cloudwatch_log_destination.test_destinations

  destination_name = each.value.name
  access_policy    = data.aws_iam_policy_document.destination_policy.json

  depends_on = [
    aws_cloudwatch_log_destination.test_destinations,
    aws_kinesis_firehose_delivery_stream.logs_firehose
  ]
}

# Access Logs Bucket
resource "aws_s3_bucket" "access_logs" {
  bucket        = "${var.environment}-${data.aws_region.current.name}-s3-access-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

# Access Logs Bucket Versioning
resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access for Access Logs Bucket
resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Access Logs Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.service_kms_keys[keys(aws_kms_key.service_kms_keys)[0]].arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Access Logs Bucket Lifecycle Policy
resource "aws_s3_bucket_lifecycle_configuration" "access_logs_lifecycle" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "access_logs_lifecycle"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555 # Approximately 7 years
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Access Logs Bucket Policy
resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3LogDelivery"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action = [
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.access_logs.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceAccount" : data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# SQS Queue for Access Logs Bucket Events
resource "aws_sqs_queue" "access_logs_event_queue" {
  name                       = "${var.environment}-${data.aws_region.current.name}-access-logs-event-notification-queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600
  max_message_size           = 262144
  kms_master_key_id          = aws_kms_key.sqs_kms_keys[keys(aws_kms_key.sqs_kms_keys)[0]].arn
}

# SQS Queue Policy for Access Logs
resource "aws_sqs_queue_policy" "access_logs_event_queue_policy" {
  queue_url = aws_sqs_queue.access_logs_event_queue.url
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.access_logs_event_queue.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.access_logs.arn
          }
        }
      }
    ]
  })
}

# S3 Bucket Notification for Access Logs
resource "aws_s3_bucket_notification" "access_logs_notification" {
  bucket = aws_s3_bucket.access_logs.id

  queue {
    queue_arn = aws_sqs_queue.access_logs_event_queue.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_sqs_queue.access_logs_event_queue,
    aws_sqs_queue_policy.access_logs_event_queue_policy
  ]
}