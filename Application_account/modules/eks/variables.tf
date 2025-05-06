// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


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
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_config" {
  description = "VPC configuration"
  type = object({
    vpc_cidr        = string
    private_subnets = list(string)
    public_subnets  = list(string)
  })
}
# variable "availability_zones" {
#   description = "List of availability zones"
#   type        = list(string)
# }

variable "log_archive_account_id" {
  description = "AWS account ID where the log destination exists"
  type        = string
}
variable "destination_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "restrictive_cidr_range" {
  description = "Restrictive CIDR range for security group rules"
  type        = list(string)
}