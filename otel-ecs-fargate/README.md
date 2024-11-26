# OTEL ECS Fargate container

### Note: Previous versions of this integration used an ADOT (AWS Distribution for OpenTelemetry) collector image. If you are upgrading an existing deployment, make sure you upgrade both the configuration and the task definition.

### Note: Previous versions of this integration required logs to be processed using fluentbit logrouter. This is no longer necessary and logs can be collected by OTEL along with the metrics and traces.

The OpenTelemetry collector offers a vendor-agnostic implementation of how to receive, process and export telemetry data.

In this document, we'll explain how to add the OTEL collector as a sidecar agent to your ECS Task Definitions. We use the standard Opentelemetry Collector Contrib distribution but leverage the envprovider to generate the configuration from an AWS SSM Parameter Store. There is an example cloudformation template for review [here](https://github.com/coralogix/cloudformation-coralogix-aws/tree/master/aws-integrations/ecs-fargate)

The envprovider is used for loading of the OpenTelemetry configuration via Systems Manager Parameter Stores. This makes adjusting your configuration more convenient and more dynamic than baking a static configuration into your container image.

Our config.yaml file includes a standard configuration that'll ensure proper ingestion of logs, metrics and traces by our backend. Make sure to create this parameter store in the same region as your ECS cluster. We've included a sample cloudformation template to deploy this parameter store to simplify this process.

Once the Parameter Store has been created, you'll need to add the OTEL container to your existing Task Definition(s).

Example container declaration within a Task Definition:

```
    "containerDefinitions": [
        {
            <Existing Container Definitions>
        },
        {
            "name": "otel-collector",
            "image": "otel/opentelemetry-collector-contrib",
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
                }
            ],
            "essential": false,
            "command": [
                "--config",
                "env:SSM_CONFIG"
            ],
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
                    "name": "SSM_CONFIG",
                    "valueFrom": "CX_OTEL_ECS_Fargate_config.yaml"
                }
            ],
            "user": "0",
            "logConfiguration": {
                "logDriver": "awsfirelens",
                "options": {
                    "Name": "OpenTelemetry"
                }
            },
            "systemControls": [],
            "firelensConfiguration": {
                "type": "fluentbit"
            }
        }
    ]
```

In the example above, you'll need to set `<Coralogix PrivateKey>` and `<Coralogix Domain>`. The logConfiguration section included in the example will forward OTEL logs to the Coralogix platform. Make sure you set all your existing containers' logConfiguration to the same.

```
"logConfiguration": {
    "logDriver": "awsfirelens",
    "options": {
        "Name": "OpenTelemetry"
    }
},
```

After adding the above container to your existing Task Definition, your applications can submit their traces and metrics exports to http://localhost:4318/v1/traces and /v1/metrics. It will also collect container metrics from all containers in the Task Definition.

## Granting permissions for parameter store access

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

## Alternative log drivers (CloudWatch)

If you don't want all containers to submit their logs to Coralogix, you can set their logConfiguration with whichever logDriver configuration you would prefer. To submit them to Cloudwatch, you can configure as so:

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

## Using Secrets Manager for your private key

If you prefer to store your Coralogix private key in AWS Secrets Manager, remove the `"PRIVATE_KEY"` config from the `"environment"` section and instead add it to `"secrets"`, referencing the Secret's ARN.

```json
"secrets": [
    {
        "name": "SSM_CONFIG",
        "valueFrom": "CX_OTEL_ECS_Fargate_config.yaml"
    },
    {
        "name": "PRIVATE_KEY",
        "valueFrom": "arn:aws:secretsmanager:region:aws_account_id:secret:secret_name-AbCdEf"
    }
],

```

Create the Secret as "Plaintext" with only the API key with no quotation marks. You will also need to add the `secretsmanager:GetSecretValue` permission to your ECS Task Execution Role.

## Granting permissions for Secrets Manager Secret access

To allow your container to access the Secrets Manager Secret, you need to provide `secretsmanager:GetSecretValue` action permission to the ECS Task Execution Role. Here’s an example of the required permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
  	  "Effect": "Allow",
	  "Action": [
        "secretsmanager:GetSecretValue"
      ],
	  "Resource": [
        "arn:aws:secretsmanager:region:aws_account_id:secret:secret_name-AbCdEf"
      ]
    }
  ]
}

```
