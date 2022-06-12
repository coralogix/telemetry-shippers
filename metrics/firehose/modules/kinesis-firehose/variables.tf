variable "firehose_stream" {
  description = "AWS Kinesis firehose delivery stream name"
  type        = string
}

variable "privatekey" {
  description = "Coralogix account private key"
}

variable "endpoint_url" {
  description = "Firehose endpoint, please see [Coralogix endpoints](https://github.com/coralogix/eng-integrations/blob/master/metrics/firehose/README.md#Coralogix Endpoints)"
  type        = string
}

variable "include_all_namespaces" {
  description = "If set to true, the CloudWatch metric stream will include all available namespaces"
  type        = bool
  default     = true
}

variable "include_metric_stream_namespaces" {
  description = "List of specific namespaces to include in the CloudWatch metric stream"
  type        = list(string)
  default     = []
}
