# OTEL ECS Fargate container

The OpenTelemetry collector offers a vendor-agnostic implementation of how to receive, process and export telemetry data.

In this document, we'll explain how to add the OTEL collector as a sidecar agent to your ECS Fargate Task Definitions. We use the standard Opentelemetry Collector Contrib distribution but leverage the envprovider to load the configuration from an AWS S3 bucket. There is an example cloudformation template for review [here](https://github.com/coralogix/cloudformation-coralogix-aws/tree/master/aws-integrations/ecs-fargate)

The envprovider is used for loading of the OpenTelemetry configuration via S3. This makes adjusting your configuration more convenient and more dynamic than baking a static configuration into your container image.

Our config.yaml file includes an example configuration that'll ensure proper ingestion of logs, metrics and traces by our backend. Upload this configuration to an S3 bucket accessible by your ecs services.

Once the configuration has been uploaded to S3, you'll need to add the OTEL container to your existing Task Definition(s). In the container definition, make sure to adjust the command, CORALOGIX_PRIVATE_KEY and CORALOGIX_DOMAIN. The s3: reference needs to be the Object URI of the S3 object, but replace the https: prefix with s3:

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
                "s3://example-bucket.s3.us-east-1.amazonaws.com/example_config.yaml"
            ],
            "environment": [
                {
                    "name": "CORALOGIX_PRIVATE_KEY",
                    "value": "<Coralogix PrivateKey>"
                },
                {
                    "name": "CORALOGIX_DOMAIN",
                    "value": "<Coralogix Domain>"
                }
            ],
            "mountPoints": [],
            "volumesFrom": [],
            "user": "0",
            "logConfiguration": {
                "logDriver": "awsfirelens",
                "options": {
                    "Name": "otel-collector"
                }
            },
            "systemControls": [],
            "firelensConfiguration": {
                "type": "fluentbit"
            }
        }
    ]
```

Make sure you set all your existing containers' logConfiguration to the same.

```
"logConfiguration": {
    "logDriver": "awsfirelens",
    "options": {
        "Name": "otel-collector"
    }
},
```

After adding the above container to your existing Task Definition, your applications can submit their traces and metrics exports to http://localhost:4318/v1/traces and /v1/metrics. It will also collect container metrics from all containers in the Task Definition.

## Granting permissions for S3 configuration file access

In order to allow container access to the S3 configuration, you'll need to provide s3 permissions to your task role:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws:s3:::example-bucket"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::example-bucket/example_config.yaml"
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

If you prefer to store your Coralogix private key in AWS Secrets Manager, remove the `"CORALOGIX_PRIVATE_KEY"` config from the `"environment"` section and instead add it to `"secrets"`, referencing the Secret's ARN.

```json
"secrets": [
    {
        "name": "CORALOGIX_PRIVATE_KEY",
        "valueFrom": "arn:aws:secretsmanager:region:aws_account_id:secret:secret_name-AbCdEf"
    }
],

```

Create the Secret as "Plaintext" with only the API key with no quotation marks. You will also need to add the `secretsmanager:GetSecretValue` permission to your ECS Task Execution Role. The Secret should also be stored in the same region as your ECS cluster.

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
