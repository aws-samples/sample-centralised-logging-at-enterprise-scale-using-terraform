// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


locals {
  services = ["rds", "eks", "lambda"]
}

# Firehose Role to support all services
resource "aws_iam_role" "firehose_role" {
  name = "${var.environment}-firehose-role-${data.aws_region.current.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Firehose Policy to include all S3 buckets
resource "aws_iam_role_policy" "firehose_policy" {
  name = "${var.environment}-firehose-policy-${data.aws_region.current.name}"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = flatten([
          for service in local.services : [
            aws_s3_bucket.logs_buckets[service].arn,
            "${aws_s3_bucket.logs_buckets[service].arn}/*"
          ]
        ])
      }
    ]
  })
}

# CloudWatch to Firehose Role 
resource "aws_iam_role" "cloudwatch_destination_role" {
  name = "${var.environment}-cloudwatch-destination-role-${data.aws_region.current.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Destination Role Policy to include all Firehose streams
resource "aws_iam_role_policy" "destination_role_policy" {
  name = "${var.environment}-destination-role-policy-${data.aws_region.current.name}"
  role = aws_iam_role.cloudwatch_destination_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = [
          for service in local.services :
          aws_kinesis_firehose_delivery_stream.logs_firehose[service].arn
        ]
      }
    ]
  })
}

# Destination Policy 
data "aws_iam_policy_document" "destination_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = var.source_account_ids
    }
    actions = ["logs:PutSubscriptionFilter"]
    resources = [
      for service in local.services :
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:destination:${var.destination_name}-${service}-${data.aws_region.current.name}"
    ]
  }
}

#  Firehose IAM role 
resource "aws_iam_role_policy_attachment" "firehose_kms_policy" {
  for_each = toset(local.services)

  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.kms_policy[each.key].arn
}

# Create KMS policies for Firehose
resource "aws_iam_policy" "kms_policy" {
  for_each = toset(local.services)

  name = "${var.environment}-${each.value}-kms-policy-${data.aws_region.current.name}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.service_kms_keys[each.value].arn
        ]
      }
    ]
  })
}

