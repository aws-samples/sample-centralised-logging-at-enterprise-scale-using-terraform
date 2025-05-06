// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


environment            = ""
account_name           = ""
log_archive_account_id = ""

# Tags (combined for all resources)
tags = {
  Environment = ""
  Project     = ""
  ManagedBy   = ""
  CostCenter  = ""
  Owner       = ""
  Terraform   = ""
}

# VPC Configuration (for each region)
# VPC Configuration
vpc_config = {
  vpc_cidr        = ""
  private_subnets = ["", "", ""]
  public_subnets  = ["", "", ""]
}

# EKS Configuration
eks_config = {
  cluster_name = ""
  eks_version  = ""
  fargate_profiles = {
    default = {
      name = ""
      selectors = [
        { namespace = "" },
        { namespace = "" }
      ]
    }
    apps = {
      name = ""
      selectors = [
        { namespace = "" }
      ]
    }
  }
}

# RDS Configuration
rds_config = {
  identifier        = ""
  allocated_storage = ""
  storage_type      = ""
  engine            = ""
  engine_version    = ""
  instance_class    = ""
  username          = ""
}

ingress_allowed_cidr_blocks = [""]
egress_allowed_cidr_blocks  = [""]

# RDS Parameter Group Configuration
rds_parameters = {
  general_log     = ""
  slow_query_log  = ""
  long_query_time = ""
  log_output      = ""
}

# Lambda Configuration
lambda_config = {
  runtime     = ""
  timeout     = ""
  memory_size = ""
}

# Log Configuration
destination_name = ""

# Cross-account log destination ARNs (update with actual ARNs)
restrictive_cidr_range = [""]
