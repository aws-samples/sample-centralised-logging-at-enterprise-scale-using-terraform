// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
# Create a new IAM role
resource "aws_iam_role" "subscription_filter_role" {
  name = "${var.environment}-subscription-filter-role-${data.aws_region.current.name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
      }
    ]
  })
}
# Create the IAM policy
resource "aws_iam_policy" "subscription_filter_policy" {
  name        = "${var.environment}-subscription-policy-${data.aws_region.current.name}"
  description = "Policy to allow PutSubscriptionFilter"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPutSubscriptionFilter"
        Effect = "Allow"
        Action = "logs:PutSubscriptionFilter"
        Resource = [
          "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:*",
          "arn:aws:logs:${data.aws_region.current.name}:${var.log_archive_account_id}:destination:*"
        ]
      }
    ]
  })
}
# Attach the policy to the new role
resource "aws_iam_role_policy_attachment" "subscription_filter_policy_attachment" {
  role       = aws_iam_role.subscription_filter_role.name
  policy_arn = aws_iam_policy.subscription_filter_policy.arn
}