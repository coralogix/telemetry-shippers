provider "aws" {
  default_tags {
    tags = {
      terraform-module         = "kinesis-firehose-to-coralogix"
      terraform-module-version = "v0.0.1"
      managed-by               = "coralogix-terraform"
    }
  }
}

locals {
  output_format = "opentelemetry0.7"
}

data "aws_caller_identity" "current_identity" {}
data "aws_region" "current_region" {}

resource "aws_cloudwatch_log_group" "firehose_loggroup" {
  name              = "/aws/kinesisfirehose/${var.firehose_stream}"
  retention_in_days = 1
}

resource "aws_cloudwatch_log_stream" "firehose_logstream_dest" {
  name           = "DestinationDelivery"
  log_group_name = aws_cloudwatch_log_group.firehose_loggroup.name
}

resource "aws_cloudwatch_log_stream" "firehose_logstream_backup" {
  name           = "BackupDelivery"
  log_group_name = aws_cloudwatch_log_group.firehose_loggroup.name
}

resource "aws_s3_bucket" "firehose_bucket" {
  bucket = "${var.firehose_stream}-backup"
}

### IAM role for s3 configuration
resource "aws_iam_role" "firehose_to_http" {
  name               = "firehose_to_http"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "firehose_to_http_metric_policy" {
  name   = "firehose_to_http_policy"
  role   = aws_iam_role.firehose_to_http.id
  policy = <<EOF
{
    "Version": "2012-10-17",  
    "Statement":
    [    
        {      
            "Effect": "Allow",      
            "Action": [
                "s3:AbortMultipartUpload",
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:ListBucketMultipartUploads",
                "s3:PutObject"
            ],      
            "Resource": [        
                "${aws_s3_bucket.firehose_bucket.arn}",
                "${aws_s3_bucket.firehose_bucket.arn}/*"		    
            ]     
        },
        {
           "Effect": "Allow",
           "Action": [
               "kms:Decrypt",
               "kms:GenerateDataKey"
           ],
           "Resource": [
               "arn:aws:kms:${data.aws_region.current_region.name}:${data.aws_caller_identity.current_identity.account_id}:key/key-id"           
           ],
           "Condition": {
               "StringEquals": {
                   "kms:ViaService": "s3.${data.aws_region.current_region.name}.amazonaws.com"
               },
               "StringLike": {
                   "kms:EncryptionContext:aws:s3:arn": "${aws_s3_bucket.firehose_bucket.arn}/prefix*"
               }
           }
        },     
        {
           "Effect": "Allow",
           "Action": [
               "kinesis:DescribeStream",
               "kinesis:GetShardIterator",
               "kinesis:GetRecords",
               "kinesis:ListShards"
           ],
           "Resource": "arn:aws:kinesis:${data.aws_region.current_region.name}:${data.aws_caller_identity.current_identity.account_id}:stream/${var.firehose_stream}"
        },
        {
           "Effect": "Allow",
           "Action": [
               "logs:PutLogEvents"
           ],
           "Resource": [
               "${aws_cloudwatch_log_group.firehose_loggroup.arn}"
           ]
        }
    ]
}
EOF
}

### IAM role for CloudWatch metric streams
resource "aws_iam_role" "metric_streams_to_firehose" {
  name               = "metric_streams_to_firehose_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "streams.metrics.cloudwatch.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "metric_streams_to_firehose_policy" {
  name   = "metrics_streams_to_firehose_policy"
  role   = aws_iam_role.metric_streams_to_firehose.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "firehose:DeleteDeliveryStream",
                "firehose:PutRecord", 
                "firehose:PutRecordBatch",
               "firehose:UpdateDestination"
            ],
            "Resource": "${aws_kinesis_firehose_delivery_stream.coralogix_stream.arn}"
        }
    ]
}
EOF
}

resource "aws_kinesis_firehose_delivery_stream" "coralogix_stream" {
  name        = "coralogix-${var.firehose_stream}"
  destination = "http_endpoint"

  s3_configuration {
    role_arn           = aws_iam_role.firehose_to_http.arn
    bucket_arn         = aws_s3_bucket.firehose_bucket.arn
    buffer_size        = 5
    buffer_interval    = 300
    compression_format = "GZIP"
  }

  http_endpoint_configuration {
    url                = var.endpoint_url
    name               = "Coralogix"
    access_key         = var.privatekey
    buffering_size     = 6
    buffering_interval = 60
    s3_backup_mode     = "FailedDataOnly"
    role_arn           = aws_iam_role.firehose_to_http.arn
    retry_duration     = 30
    cloudwatch_logging_options {
      enabled         = "true"
      log_group_name  = aws_cloudwatch_log_group.firehose_loggroup.name
      log_stream_name = aws_cloudwatch_log_stream.firehose_logstream_dest.name
    }

    request_configuration {
      content_encoding = "GZIP"

      common_attributes {
        name  = "integrationType"
        value = "CloudWatch_Metrics_OpenTelemetry070"
      }
    }
  }
}

# Creating one metric stream for all namespaces 
resource "aws_cloudwatch_metric_stream" "cloudwatch_metric_stream_all_ns" {
  count         = var.include_all_namespaces == true ? 1 : 0
  name          = "cloudwatch_metrics"
  role_arn      = aws_iam_role.metric_streams_to_firehose.arn
  firehose_arn  = aws_kinesis_firehose_delivery_stream.coralogix_stream.arn
  output_format = local.output_format
}

# Creating metric streams only for specific namespaces 
resource "aws_cloudwatch_metric_stream" "cloudwatch_metric_stream_included_ns" {
  count         = var.include_all_namespaces == false ? 1 : 0
  name          = "cloudwatch_metrics_selected_namespaces"
  role_arn      = aws_iam_role.metric_streams_to_firehose.arn
  firehose_arn  = aws_kinesis_firehose_delivery_stream.coralogix_stream.arn
  output_format = local.output_format
  dynamic "include_filter" {
    for_each = var.include_metric_stream_namespaces
    content {
      namespace = "AWS/${include_filter.value}"
    }
  }
}

