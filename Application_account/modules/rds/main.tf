// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Create custom parameter group
resource "aws_db_parameter_group" "mysql_param_group" {
  name        = "${var.account_name}-mysql-params-${data.aws_region.current.name}"
  family      = "mysql8.0" # Adjust based on your MySQL version
  description = "Custom parameter group for MySQL RDS with logging enabled"

  parameter {
    name         = "general_log"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "slow_query_log"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "long_query_time"
    value        = "10"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_output"
    value        = "FILE"
    apply_method = "immediate"
  }
  parameter {
    name         = "require_secure_transport"
    value        = "1"
    apply_method = "immediate"
  }
  tags = var.tags
}


# Create a random password
resource "random_password" "master_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Add random suffix to avoid name conflicts
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_kms_key" "secrets_manager_kms_key" {
  description             = "KMS Key for Secrets Manager"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  # Add key policy
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
        Sid    = "Allow Secrets Manager to use the key"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs to use the key"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt",
          "kms:GenerateDataKey",
          "kms:Describe"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow attachment of persistent resources"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" : "true"
          }
        }
      }
    ]
  })

  tags = {
    Name = "secrets-manager-kms-key"
  }
}

# Create the secret with a unique name
resource "aws_secretsmanager_secret" "db_password" {
  name_prefix = "${var.environment}-${var.account_name}-db-password-${data.aws_region.current.name}-"
  description = "RDS database password for ${var.environment} environment"
  tags        = var.tags
  kms_key_id  = aws_kms_key.secrets_manager_kms_key.arn
  # Set recovery window to 0 to force immediate deletion
  recovery_window_in_days = 0

  lifecycle {
    create_before_destroy = true
  }
}

# Create KMS key for RDS encryption
resource "aws_kms_key" "rds_encryption" {
  description             = "KMS Key for RDS Encryption"
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
        Sid    = "Allow RDS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:ReEncrypt*",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow attachment of persistent resources"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" : "true"
          }
        }
      }
    ]
  })

  tags = {
    Name = "rds-encryption-key"
  }
}


# Create an alias for the KMS key
resource "aws_kms_alias" "rds_encryption_alias" {
  name          = "alias/rds-encryption-key"
  target_key_id = aws_kms_key.rds_encryption.key_id
}

# Create KMS key for Performance Insights
resource "aws_kms_key" "performance_insights" {
  description             = "KMS Key for RDS Performance Insights"
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
        Sid    = "Allow RDS Performance Insights"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "rds-performance-insights-key"
  })
}


resource "aws_db_instance" "this" {
  identifier                            = "${var.account_name}-${var.rds_config.identifier}-${data.aws_region.current.name}"
  allocated_storage                     = var.rds_config.allocated_storage
  storage_type                          = var.rds_config.storage_type
  engine                                = var.rds_config.engine
  engine_version                        = var.rds_config.engine_version
  instance_class                        = var.rds_config.instance_class
  username                              = var.rds_config.username
  password                              = random_password.master_password.result
  skip_final_snapshot                   = true
  publicly_accessible                   = false
  monitoring_interval                   = 0
  enabled_cloudwatch_logs_exports       = ["audit", "error", "general", "slowquery"]
  parameter_group_name                  = aws_db_parameter_group.mysql_param_group.id
  apply_immediately                     = true
  multi_az                              = true
  vpc_security_group_ids                = [aws_security_group.rds.id]
  db_subnet_group_name                  = aws_db_subnet_group.default.name
  kms_key_id                            = aws_kms_key.rds_encryption.arn
  storage_encrypted                     = true
  deletion_protection                   = true
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.performance_insights.arn
  performance_insights_retention_period = 7
  tags                                  = var.tags
  auto_minor_version_upgrade            = true
}

# Update the secret version with the endpoint after RDS is created
resource "aws_secretsmanager_secret_version" "db_password_update" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.rds_config.username
    password = random_password.master_password.result
    engine   = var.rds_config.engine
    port     = 3306
    host     = aws_db_instance.this.endpoint
  })
  depends_on = [aws_db_instance.this]
}

# Create security group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.account_name}-rds-sg-${data.aws_region.current.name}"
  description = "Security group for RDS instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.ingress_allowed_cidr_blocks
    description = "Allow access from specified CIDR blocks"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.egress_allowed_cidr_blocks
    description = "Allow access from specified CIDR blocks"
  }

  tags = var.tags
}

# Create DB subnet group
resource "aws_db_subnet_group" "default" {
  name       = "${var.account_name}-subnet-group-${data.aws_region.current.name}"
  subnet_ids = data.aws_subnets.default.ids

  tags = var.tags
}



resource "aws_cloudwatch_log_group" "rds_logs" {
  for_each          = toset(["error", "slowquery", "general", "audit"])
  name              = "/aws/rds/instance/${aws_db_instance.this.identifier}/${each.value}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.secrets_manager_kms_key.arn
  depends_on        = [aws_db_instance.this]
}

# data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_subscription_filter" "rds_logs" {
  for_each        = toset(["error", "slowquery", "general", "audit"])
  name            = "general-log-filter"
  log_group_name  = "/aws/rds/instance/${aws_db_instance.this.identifier}/${each.value}"
  destination_arn = "arn:aws:logs:${data.aws_region.current.name}:${var.log_archive_account_id}:destination:${var.destination_name}-rds-${data.aws_region.current.name}"
  filter_pattern  = ""
}
