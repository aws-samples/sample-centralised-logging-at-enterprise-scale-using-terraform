// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


# Existing data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# New data sources for VPC and subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Lambda Function ZIP
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Lambda Function
resource "aws_lambda_function" "lambda" {
  filename                       = data.archive_file.lambda_zip.output_path
  function_name                  = "${var.environment}-lambda-function"
  role                           = aws_iam_role.lambda_role.arn
  handler                        = "lambda_function.lambda_handler"
  runtime                        = var.lambda_config.runtime
  timeout                        = var.lambda_config.timeout
  memory_size                    = var.lambda_config.memory_size
  reserved_concurrent_executions = 100
  source_code_hash               = data.archive_file.lambda_zip.output_base64sha256

  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  code_signing_config_arn = aws_lambda_code_signing_config.this.arn

  tags = var.tags
  tracing_config {
    mode = "Active"
  }
}

resource "aws_lambda_code_signing_config" "this" {
  allowed_publishers {
    signing_profile_version_arns = [aws_signer_signing_profile.this.version_arn]
  }

  policies {
    untrusted_artifact_on_deployment = "Warn"
  }
}

resource "aws_signer_signing_profile" "this" {
  name_prefix = "lambda_signing_profile"
  platform_id = "AWSLambda-SHA384-ECDSA"
}

# Security Group for Lambda
resource "aws_security_group" "lambda_sg" {
  name        = "${var.environment}-lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = data.aws_vpc.default.id
  tags        = var.tags
}

# KMS Key for CloudWatch Log Group encryption
resource "aws_kms_key" "cloudwatch_log" {
  description             = "KMS key for CloudWatch Log Group encryption"
  deletion_window_in_days = 30
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
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# KMS Key Alias
resource "aws_kms_alias" "cloudwatch_log" {
  name          = "alias/${var.environment}-cloudwatch-log-key"
  target_key_id = aws_kms_key.cloudwatch_log.key_id
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.cloudwatch_log.arn
  tags              = var.tags
}

# Subscription filter for the CloudWatch Log Group
resource "aws_cloudwatch_log_subscription_filter" "lambda" {
  name            = "${var.environment}-subscription-filter"
  log_group_name  = aws_cloudwatch_log_group.lambda.name
  filter_pattern  = ""
  destination_arn = "arn:aws:logs:${data.aws_region.current.name}:${var.log_archive_account_id}:destination:${var.destination_name}-lambda-${data.aws_region.current.name}"

  depends_on = [aws_lambda_function.lambda, aws_cloudwatch_log_group.lambda]
}