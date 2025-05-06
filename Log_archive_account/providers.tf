// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


# Define providers for each region
provider "aws" {
  region = "us-east-1"
  alias  = "region_1"
}

provider "aws" {
  region = "us-west-2"
  alias  = "region_2"
}