# ADOT (OTEL) ECS Fargate container

The OpenTelemetry collector offers a vendor-agnostic implementation of how to receive, process and export telemetry data.

In this document, we'll explain how to add the OTEL collector as a sidecar agent to your ECS Task Definitions.  We use an AWS customized OpenTelemetry image called AWS Distro for OpenTelemetry (ADOT), as it has several features that allow for more convenient management of the configuration.

The ADOT image, [maintained here by AWS](https://github.com/aws-observability/aws-otel-collector), allows for loading of the OpenTelemetry configuration via Systems Manager Parameter Stores. This makes adjusting your configuration more convenient and more dynamic than baking a static configuration into your container image.

Our config.yaml file includes a standard configuration that'll ensure proper ingestion by our backend. Make sure to create this parameter store in the same region as your ECS cluster. We've included a sample cloudformation template to deploy this parameter store to simplify this process.

Once the Parameter Store has been created, you'll need to add the container to your existing Task Definition.

Example container declaration within a Task Definition:

```
    "containerDefinitions": [
        {
            <Existing Container Definitions>
        },
        {
            "name": "otel-collector",
            "image": "public.ecr.aws/aws-observability/aws-otel-collector",
            "cpu": 0,
            "portMappings": [
                {
                    "name": "otel-collector-4317-tcp",
                    "containerPort": 4317,
                    "hostPort": 4317,
                    "protocol": "tcp",
                    "appProtocol": "grpc"
                },
                {
                    "name": "otel-collector-4318-tcp",
                    "containerPort": 4318,
                    "hostPort": 4318,
                    "protocol": "tcp",
                    "appProtocol": "grpc"
                }
            ],
            "essential": false,
            "environment": [
                {
                    "name": "PRIVATE_KEY",
                    "value": "<Coralogix PrivateKey>"
                },
                {
                    "name": "CORALOGIX_DOMAIN",
                    "value": "<Coralogix Domain>"
                }
            ],
            "mountPoints": [],
            "volumesFrom": [],
            "secrets": [
                {
                    "name": "AOT_CONFIG_CONTENT",
                    "valueFrom": "config.yaml"
                }
            ],
            "logConfiguration": {
                "logDriver": "awsfirelens",
                "options": {
                    "Format": "json_lines",
                    "Header": "private_key <Coralogix PrivateKey>",
                    "Host": "ingress.<Coralogix Domain>",
                    "Name": "http",
                    "Port": "443",
                    "Retry_Limit": "10",
                    "TLS": "On",
                    "URI": "/logs/rest/singles",
                    "compress": "gzip"
                }
            }
        }
    ]
```

In the example above, you'll need to set two instances each of <Coralogix PrivateKey> and <Coralogix Domain>. The logConfiguration section included in the example will forward OTEL logs to the Coralogix platform, as documented in our fluentbit log processing configuration instructions [here](../../logs/fluent-bit/ecs-fargate/README.md). If you don't want to have them submitted to the Coralogix platform, you can replace the logConfiguration with whichever logDriver configuration you would prefer. To submit to Cloudwatch, you can configure as so:

```
"logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-create-group": "true",
                    "awslogs-group": "<Log Group Name>",
                    "awslogs-region": "<Your Region>",
                    "awslogs-stream-prefix": "<Stream Prefix>"
                }
            }
```

In order to allow container access to the Systems Manager Parameter Store, you'll need to provide the ssm:GetParameters action permissions to the task execution role:

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters"
      ],
      "Resource": [
        "arn:aws:ssm:region:aws_account_id:parameter/parameter_name"
      ]
    }
  ]
}
```
Note: Don't confuse Task Role for Task Execution Role, this permission needs to be added to the Task Execution Role. (Contrary to the fluentbit Logs integration)

After adding the above container to your existing Task Definition, your applications can submit their traces and metrics exports to http://localhost:4318/v1/traces and /v1/metrics. It will also collect container metrics from all containers in the Task Definition.