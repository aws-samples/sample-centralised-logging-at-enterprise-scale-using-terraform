// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


module "log_destination_region_1" {
  source = "./modules/log_destination"

  providers = {
    aws = aws.region_1
  }

  environment        = var.environment
  source_account_ids = var.source_account_ids
  destination_name   = var.destination_name
}

module "log_destination_region_2" {
  source = "./modules/log_destination"

  providers = {
    aws = aws.region_2
  }

  environment        = var.environment
  source_account_ids = var.source_account_ids
  destination_name   = var.destination_name
}