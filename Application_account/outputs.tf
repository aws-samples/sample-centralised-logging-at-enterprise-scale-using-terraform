// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


output "rds_endpoint_region_1" {
  description = "The RDS endpoint for region 1"
  value       = module.rds_region_1.rds_endpoint
}

output "rds_endpoint_region_2" {
  description = "The RDS endpoint for region 2"
  value       = module.rds_region_2.rds_endpoint
}