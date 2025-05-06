// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


data "aws_caller_identity" "current" {}
# data "aws_region" "current" {}
resource "aws_eks_cluster" "this" {
  name     = "${var.eks_config.cluster_name}-${data.aws_region.current.name}"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.eks_config.eks_version

  vpc_config {
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = [aws_security_group.cluster.id]
  }

  # Enable EKS control plane logging
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Enable encryption for secrets
  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
    aws_cloudwatch_log_group.eks,
  ]

  tags = var.tags
}

resource "aws_eks_fargate_profile" "this" {
  for_each               = var.eks_config.fargate_profiles
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = each.value.name
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution.arn
  subnet_ids             = aws_subnet.private[*].id

  dynamic "selector" {
    for_each = each.value.selectors
    content {
      namespace = selector.value.namespace
      labels    = lookup(selector.value, "labels", null)
    }
  }

  tags = var.tags
}

# Customer Managed KMS Key for EKS
resource "aws_kms_key" "eks" {
  description              = "Customer managed key for EKS cluster ${var.eks_config.cluster_name} secret encryption"
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
        Sid    = "Allow EKS Service"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
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
        Sid    = "Allow Key Administration"
        Effect = "Allow"
        Principal = {
          AWS = "${aws_iam_role.fargate_pod_execution.arn}"
        }
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name    = "${var.eks_config.cluster_name}-eks-cmk"
      Purpose = "EKS Secret Encryption"
    }
  )
}

# KMS Alias
resource "aws_kms_alias" "eks" {
  name          = "alias/${var.eks_config.cluster_name}-eks-cmk"
  target_key_id = aws_kms_key.eks.key_id
}

# CloudWatch log group for EKS cluster logs
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.eks_config.cluster_name}/cluster"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.eks.arn
  tags              = var.tags


}

# Security group for the EKS cluste
resource "aws_security_group" "cluster" {
  name        = "${var.eks_config.cluster_name}-cluster-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.restrictive_cidr_range
    description = "Allow access from specified CIDR blocks"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.eks_config.cluster_name}-cluster-sg"
    }
  )
}
#
resource "aws_security_group_rule" "cluster_ingress_https" {
  description       = "Allow pods to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.cluster.id
  to_port           = 443
  type              = "ingress"
  cidr_blocks       = concat(var.vpc_config.private_subnets, var.vpc_config.public_subnets)
}


#subscripton filter for eks cluster logs

# Subscription filter for API logs
resource "aws_cloudwatch_log_subscription_filter" "api_logs" {
  name            = "${var.eks_config.cluster_name}-api-logs-subscription"
  log_group_name  = "/aws/eks/${var.eks_config.cluster_name}-${data.aws_region.current.name}/cluster"
  filter_pattern  = "{ $.logStream = \"*-api-*\" }"
  destination_arn = "arn:aws:logs:${data.aws_region.current.name}:${var.log_archive_account_id}:destination:${var.destination_name}-eks-${data.aws_region.current.name}"

  depends_on = [aws_eks_cluster.this]
}




