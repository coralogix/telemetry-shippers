# fluent-bit (log_router) EKS Fargate

The EKS Fargate observability integration is broken down into two parts, Metrics and Traces performed by OpenTelemetry, and Logs, using the AWS log_router framework. Each integration can be deployed completely independent of each other. In this document, we'll discuss Logs via log_router.

# Logs

For EKS Fargate logs, we leverage the AWS log_router built into the Fargate Kubelet to route your application logs to the Coralogix platform through a Kinesis Firehose.

## Requirements

- AWS Kinesis Firehose configured per our documentation here: [AWS Kinesis Data Firehose - Logs - Coralogix](https://coralogix.com/docs/aws-firehose/)

- Proper permissions added to each of your Fargate profile Pod Execution Roles
- Deployment of the log_router configuration

## Kinesis Firehose

Following the above documentation, you should have a configured Kinesis Firehose to use with your log_router. Though there are other exporters available for the log_router (fluent-bit), it is restricted to ElasticSearch, Firehose and Cloudwatch. We’ve selected the Kinesis Firehose as it limits added cost while allowing direct submission to the Coralogix Platform.

## Fargate Profile Permissions

For the sidecar fluent-bit pod to submit messages to the Kinesis Firehose, it requires put and put batch permissions. This is accomplished by adding the following permissions to every Fargate Profile that you wish to monitor for application logs.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "firehose:PutRecord",
                "firehose:PutRecordBatch"
            ],
            "Resource": [
                "<firehose_ARN>"
            ]
        }
    ]
}
```

## log_router Deployment

To deploy the log_router, you’ll need a specific namespace with appropriate labels configured in your cluster. You won’t be deploying any workloads into this namespace, so you don’t need a Fargate Profile configured for it.

Though the configuration will look like standard fluent-bit configuration, only specific sections that can be modified, and certain modules that can be used. Below is our recommended Kubernetes manifest which will deploy the namespace and the fluent-bit ConfigMap:

```yaml
---
kind: Namespace
apiVersion: v1
metadata:
  name: aws-observability
  labels:
    aws-observability: enabled

---
kind: ConfigMap
apiVersion: v1
metadata:
  name: aws-logging
  namespace: aws-observability
data:
  filters.conf: |
    [FILTER]
        Name parser
        Match *
        Key_name log
        Parser crio

    [FILTER]
        Name             kubernetes
        Match            kube.*
        Merge_Log           On
        Buffer_Size         0
        Kube_Meta_Cache_TTL 300s
        Keep_Log Off
        Merge_Log_Key log_obj
        K8S-Logging.Parser On
        K8S-Logging.Exclude On
        Annotations Off

  output.conf: |
    [OUTPUT]
      Name  kinesis_firehose
      Match *
      region <AWS Region> (no quotes)
      delivery_stream <Data Firehose Delivery Stream Name> (no quotes)

  parsers.conf: |
    [PARSER]
        Name crio
        Format Regex
        Regex ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>P|F) (?<log>.*)$
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z
        Time_Keep true
```

Details on the workings of the AWS log router can be found in the configuration documentation on the AWS docs site here:

[Fargate logging - Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/fargate-logging.html)

## Notes:

- The log_router will only be attached to workloads started after the manifest has been applied. **You will need to restart your pods** in order for the log_router to start forwarding the logs to your Firehose.
- You can add additional filters, but they are limited to the following types:
  `grep, parser, record_modifier, rewrite_tag, throttle, nest, modify, kubernetes`
- If you wish to add a Cloudwatch output, you’ll have to add additional permissions to your Fargate profile. Please review the above linked AWS documentation for details.
