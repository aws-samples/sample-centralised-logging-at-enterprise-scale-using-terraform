// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


# General Settings
variable "environment" {
  description = "Environment name (e.g., prod, dev, staging)"
  type        = string
}

variable "account_name" {
  description = "Name of the AWS account"
  type        = string
}

variable "log_archive_account_id" {
  description = "AWS account ID for log archiving"
  type        = string
}


# Tags
variable "tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
}

# RDS Configuration
variable "rds_config" {
  description = "Configuration for RDS instance"
  type = object({
    identifier        = string
    allocated_storage = number
    storage_type      = string
    engine            = string
    engine_version    = string
    instance_class    = string
    username          = string
  })
  sensitive = true # Marks password as sensitive
}

variable "destination_name" {
  description = "Name of the log destination"
  type        = string
}


# RDS Parameter Group Configuration
variable "rds_parameters" {
  description = "RDS parameter group settings"
  type = object({
    general_log     = number
    slow_query_log  = number
    long_query_time = number
    log_output      = string
  })
}

variable "vpc_config" {
  description = "VPC configuration"
  type = object({
    vpc_cidr        = string
    private_subnets = list(string)
    public_subnets  = list(string)
  })
}

variable "eks_config" {
  description = "EKS cluster configuration"
  type = object({
    cluster_name = string
    eks_version  = string
    fargate_profiles = map(object({
      name = string
      selectors = list(object({
        namespace = string
      }))
    }))
  })
}



# variable "log_archive_account_id" {
#   description = "AWS account ID where the log destination exists"
#   type        = string
# }
# variable "destination_name" {
#   description = "Name of the Lambda function"
#   type        = string
# }


variable "lambda_config" {
  description = "Configuration for Lambda function"
  type = object({
    runtime     = string
    timeout     = number
    memory_size = number
  })
}

variable "restrictive_cidr_range" {
  description = "Restrictive CIDR range for security group rules"
  type        = list(string)
}

variable "ingress_allowed_cidr_blocks" {
  description = "List of CIDR blocks that can access the RDS instance"
  type        = list(string)
}

variable "egress_allowed_cidr_blocks" {
  description = "List of CIDR blocks that can access the RDS instance"
  type        = list(string)
}
