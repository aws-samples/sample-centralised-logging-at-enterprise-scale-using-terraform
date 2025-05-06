// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


variable "environment" {
  description = "Environment (e.g., dev, staging, prod)"
  type        = string
}

variable "lambda_config" {
  description = "Configuration for Lambda function"
  type = object({
    runtime     = string
    timeout     = number
    memory_size = number
  })
}


variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# variable "destination_arn" {
#   description = "ARN of the cross-account destination for logs"
#   type        = string
# }
variable "log_archive_account_id" {
  description = "AWS account ID where the log destination exists"
  type        = string
}
variable "destination_name" {
  description = "Name of the Lambda function"
  type        = string
}

