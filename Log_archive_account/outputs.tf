// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


# output "region_1_destination_arns_1" {
#   description = "ARNs of CloudWatch Logs destinations in ap-south-1"
#   value       = module.log_destination_region_1.destination_arn_1
# }
# output "region_1_destination_arns_2" {
#   description = "ARNs of CloudWatch Logs destinations in ap-south-1"
#   value       = module.log_destination_region_1.destination_arn_2
# }

# output "region_2_destination_arns_1" {
#   description = "ARNs of CloudWatch Logs destinations in eu-east-1"
#   value       = module.log_destination_region_2.destination_arn_1
# }

# output "region_2_destination_arns_2" {
#   description = "ARNs of CloudWatch Logs destinations in eu-east-1"
#   value       = module.log_destination_region_2.destination_arn_2
# }

# output "s3_bucket_arns" {
#   description = "ARNs of S3 buckets for each region"
#   value = {
#     region_1 = module.log_destination_region_1.s3_bucket_arn
#     region_2 = module.log_destination_region_2.s3_bucket_arn
#   }
# }