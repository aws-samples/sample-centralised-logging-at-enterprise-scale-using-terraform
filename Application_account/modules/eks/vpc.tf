// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_count = min(length(data.aws_availability_zones.available.names), length(var.vpc_config.private_subnets))
  azs      = slice(data.aws_availability_zones.available.names, 0, local.az_count)
}

# Create VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_config.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      "Name"                                                 = "${var.eks_config.cluster_name}-vpc",
      "kubernetes.io/cluster/${var.eks_config.cluster_name}" = "shared"
    }
  )
}

# Manage Default Security Group
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  # Empty ingress and egress blocks to remove all rules
  # This effectively restricts all traffic

  tags = merge(
    var.tags,
    {
      Name = "${var.eks_config.cluster_name}-default-sg"
    }
  )
}

# Create CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc-flow-logs/${var.eks_config.cluster_name}"
  retention_in_days = 365 # Adjust retention period as needed
  kms_key_id        = aws_kms_key.eks.arn
  tags              = var.tags
}

# Create IAM Role for VPC Flow Logs
resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.eks_config.cluster_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Create IAM Role Policy for VPC Flow Logs
resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.eks_config.cluster_name}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
      }
    ]
  })
}

# Enable VPC Flow Logs
resource "aws_flow_log" "vpc" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL" # Options: ACCEPT, REJECT, ALL
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn

  tags = merge(
    var.tags,
    {
      Name = "${var.eks_config.cluster_name}-vpc-flow-logs"
    }
  )
}

resource "aws_subnet" "private" {
  count             = local.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.vpc_config.private_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(
    var.tags,
    {
      "Name"                                                 = "${var.eks_config.cluster_name}-private-${local.azs[count.index]}",
      "kubernetes.io/cluster/${var.eks_config.cluster_name}" = "shared",
      "kubernetes.io/role/internal-elb"                      = "1"
    }
  )
}

resource "aws_subnet" "public" {
  count             = local.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.vpc_config.public_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(
    var.tags,
    {
      "Name"                                                 = "${var.eks_config.cluster_name}-public-${local.azs[count.index]}",
      "kubernetes.io/cluster/${var.eks_config.cluster_name}" = "shared",
      "kubernetes.io/role/elb"                               = "1"
    }
  )
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      "Name" = "${var.eks_config.cluster_name}-igw"
    }
  )
}

resource "aws_eip" "nat" {
  count  = local.az_count
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      "Name" = "${var.eks_config.cluster_name}-nat-eip-${local.azs[count.index]}"
    }
  )
}

resource "aws_nat_gateway" "this" {
  count         = local.az_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags,
    {
      "Name" = "${var.eks_config.cluster_name}-nat-${local.azs[count.index]}"
    }
  )
}

resource "aws_route_table" "private" {
  count  = local.az_count
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge(
    var.tags,
    {
      "Name" = "${var.eks_config.cluster_name}-private-rt-${local.azs[count.index]}"
    }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.tags,
    {
      "Name" = "${var.eks_config.cluster_name}-public-rt"
    }
  )
}

resource "aws_route_table_association" "private" {
  count          = local.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "public" {
  count          = local.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}