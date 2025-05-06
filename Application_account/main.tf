// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


# Lambda function
module "lambda_region_1" {
  source = "./modules/lambda"

  providers = {
    aws = aws.region_1
  }
  environment            = var.environment
  lambda_config          = var.lambda_config
  destination_name       = var.destination_name
  log_archive_account_id = var.log_archive_account_id
  tags                   = var.tags
}

module "lambda_region_2" {
  source = "./modules/lambda"

  providers = {
    aws = aws.region_2
  }
  environment            = var.environment
  lambda_config          = var.lambda_config
  destination_name       = var.destination_name
  log_archive_account_id = var.log_archive_account_id
  tags                   = var.tags
}


# EKS Cluster
module "eks_region_1" {
  source = "./modules/eks"

  providers = {
    aws = aws.region_1
  }

  eks_config             = var.eks_config
  vpc_config             = var.vpc_config
  log_archive_account_id = var.log_archive_account_id
  destination_name       = var.destination_name
  tags                   = var.tags
  restrictive_cidr_range = var.restrictive_cidr_range
}

module "eks_region_2" {
  source = "./modules/eks"

  providers = {
    aws = aws.region_2
  }

  eks_config             = var.eks_config
  vpc_config             = var.vpc_config
  log_archive_account_id = var.log_archive_account_id
  destination_name       = var.destination_name
  tags                   = var.tags
  restrictive_cidr_range = var.restrictive_cidr_range
}




#rds function
module "rds_region_1" {
  source = "./modules/rds"

  # RDS
  providers = {
    aws = aws.region_1
  }


  environment                 = var.environment
  account_name                = var.account_name
  tags                        = var.tags
  rds_config                  = var.rds_config
  log_archive_account_id      = var.log_archive_account_id
  destination_name            = var.destination_name
  egress_allowed_cidr_blocks  = var.egress_allowed_cidr_blocks
  ingress_allowed_cidr_blocks = var.ingress_allowed_cidr_blocks

}

module "rds_region_2" {
  source = "./modules/rds"


  providers = {
    aws = aws.region_2
  }


  environment                 = var.environment
  account_name                = var.account_name
  tags                        = var.tags
  rds_config                  = var.rds_config
  log_archive_account_id      = var.log_archive_account_id
  destination_name            = var.destination_name
  egress_allowed_cidr_blocks  = var.egress_allowed_cidr_blocks
  ingress_allowed_cidr_blocks = var.ingress_allowed_cidr_blocks

}




