// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


# MODIFICATION 1: S3 Bucket ARNs for all services
output "s3_bucket_arns" {
  description = "ARNs of all S3 buckets (RDS, EKS, and Lambda)"
  value = {
    for service in local.services :
    service => aws_s3_bucket.logs_buckets[service].arn
  }
}

# MODIFICATION 2: Firehose ARNs for all services
output "firehose_arns" {
  description = "ARNs of all Kinesis Firehose streams (RDS, EKS, and Lambda)"
  value = {
    for service in local.services :
    service => aws_kinesis_firehose_delivery_stream.logs_firehose[service].arn
  }
}

# MODIFICATION 3: CloudWatch Log Destination ARNs for all services
output "destination_arns" {
  description = "ARNs of all CloudWatch Log destinations (RDS, EKS, and Lambda)"
  value = {
    for service in local.services :
    service => aws_cloudwatch_log_destination.test_destinations[service].arn
  }
}

# MODIFICATION 4: S3 Bucket Names for all services
output "s3_bucket_names" {
  description = "Names of all S3 buckets (RDS, EKS, and Lambda)"
  value = {
    for service in local.services :
    service => aws_s3_bucket.logs_buckets[service].id
  }
}

# MODIFICATION 5: Firehose Names for all services
output "firehose_names" {
  description = "Names of all Kinesis Firehose streams (RDS, EKS, and Lambda)"
  value = {
    for service in local.services :
    service => aws_kinesis_firehose_delivery_stream.logs_firehose[service].name
  }
}

# MODIFICATION 6: CloudWatch Log Group Names for all services
output "cloudwatch_log_group_names" {
  description = "Names of all CloudWatch Log Groups (RDS, EKS, and Lambda)"
  value = {
    for service in local.services :
    service => aws_cloudwatch_log_group.firehose_logs[service].name
  }
}

# MODIFICATION 7: SQS Queue URLs for all services
output "sqs_queue_urls" {
  description = "URLs of all SQS queues (RDS, EKS, and Lambda)"
  value = {
    for service in local.services :
    service => aws_sqs_queue.s3_event_queues[service].url
  }
}

# MODIFICATION 8: SQS Queue ARNs for all services
output "sqs_queue_arns" {
  description = "ARNs of all SQS queues (RDS, EKS, and Lambda)"
  value = {
    for service in local.services :
    service => aws_sqs_queue.s3_event_queues[service].arn
  }
}