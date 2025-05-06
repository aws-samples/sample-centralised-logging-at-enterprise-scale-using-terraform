// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


variable "environment" {
  type = string
}

variable "source_account_ids" {
  description = "List of AWS account IDs allowed to put subscription filters"
  type        = list(string)
  default     = [] # You can set default values if needed
}

variable "destination_name" {
  type = string
}

