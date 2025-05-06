// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


variable "account_name" {
  description = "Name of the account used for resource naming"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
}

variable "rds_config" {
  description = "Configuration for the RDS instance"
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

variable "ingress_allowed_cidr_blocks" {
  description = "List of CIDR blocks that can access the RDS instance"
  type        = list(string)
}

variable "egress_allowed_cidr_blocks" {
  description = "List of CIDR blocks that can access the RDS instance"
  type        = list(string)
}

variable "destination_name" {
  description = "ARN of the destination for CloudWatch Logs"
  type        = string
}

variable "environment" {
  description = "Environment name used for resource naming (e.g., prod, dev, staging)"
  type        = string
}
variable "log_archive_account_id" {
  description = "AWS account ID where the log destination exists"
  type        = string
}
