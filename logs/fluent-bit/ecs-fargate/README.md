# fluentbit ECS Fargate container

fluentbit is a lightweight data shipper that we are using as a logs shipper for AWS ECS Fargate workloads.

Here we explain how to deploy the fluentbit log_router into an existing AWS ECS Fargate task definition. We use an AWS customized fluentbit image called aws-for-fluent-bit, init version, as it has several features that allow for more convenient management of the configuration. We also have an example cloudformation template for review [here](https://github.com/coralogix/cloudformation-coralogix-aws/tree/master/aws-integrations/ecs-fargate)

The aws-for-fluent-bit image, [maintained here by AWS](https://github.com/aws/aws-for-fluent-bit), allows for loading of the fluentbit configuration via S3 or included local files. This makes adjusting your configuration more convenient and dynamic than baking a static configuration into your container image.

The base_filters.conf file includes a set of filters to ensure proper ingestion by our backend. This should be included as the first configuration file for your instance deployment. Ensure you upload this to an S3 bucket in your AWS account.

As I just alluded to, you can load multiple configuration files from S3 to build your final configuration. This is done by setting custom environment variables within the task definition.

Example container declaration within a Task Definition:

```
    "containerDefinitions": [
        {
            <Existing Container Definitions>
        },
        {
            "name": "log_router",
            "image": "public.ecr.aws/aws-observability/aws-for-fluent-bit:init-2.31.12",
            "cpu": 0,
            "portMappings": [],
            "essential": false,
            "environment": [
                {
                    "name": "aws_fluent_bit_init_s3_1",
                    "value": "arn:aws:s3:::<Your S3 Bucket>/base_filters.conf"
                },
                {
                    "name": "aws_fluent_bit_init_s3_2",
                    "value": "arn:aws:s3:::<Your S3 Bucket>/more_filters.conf"
                },
                {
                    "name": "aws_fluent_bit_init_s3_3",
                    "value": "arn:aws:s3:::<Your S3 Bucket>/custom_parser.conf"
                }        
            ],
            "mountPoints": [],
            "volumesFrom": [],
            "user": "0",
            "firelensConfiguration": {
                "type": "fluentbit",
                "options": {}
            }
        }
    ]
```

In the example above, you'll notice our `aws_fluent_bit_init_s3_1` environment variable points to the base_filters.conf file hosted in your S3 bucket. You can add additional log files, by increasing the _# suffix to reference additional files. You can also create your own custom image and include files locally if that better suits your needs. If doing so, you'd use the environment variable `aws_fluent_bit_init_file_1` instead. You can use S3 and local files in the same deployment.

Full details can be found in the AWS documentation [here](https://github.com/aws/aws-for-fluent-bit/tree/mainline/use_cases/init-process-for-fluent-bit).

In order to allow container access to the S3 object, you'll need to provide the s3:GetObject and s3:GetBucketLocation action permissions to the task:

```
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": [
				"s3:GetBucketLocation"
			],
			"Resource": "<Your specific bucket ARN>"
		},
		{
			"Effect": "Allow",
			"Action": [
				"s3:GetObject"
			],
			"Resource": "<Your specific bucket ARN>/*"
		}
	]
}
```

Note: Don't confuse Task Execution Role for Task Role, this permission needs to be added to the Task Role. (Contrary to the ADOT (OTEL) Metrics and Traces integration)

After you've added the above container to your existing Task Definition, you need to adjust the logConfiguration for the containers you wish to forward to Coralogix.

To do so, you'd add this "logConfiguration" section to each of your application containers at the root (same level as "name", "image" and others):

```
            "logConfiguration": {
                "logDriver": "awsfirelens",
                "options": {
                    "Format": "json_lines",
                    "Header": "Authorization Bearer <Coralogix APIKey>",
                    "Host": "ingress.<Coralogix Domain>",
                    "Name": "http",
                    "Port": "443",
                    "Retry_Limit": "10",
                    "TLS": "On",
                    "URI": "/logs/v1/singles",
                    "compress": "gzip"
                }
            }
```

**NOTE:** If you wish to store your Coralogix Privatekey in Secrets Manager, you can remove the `"Header"` from `"options"` and create one under `"secretOptions"` and reference the Secret's ARN. Store the secret as plaintext with the same format as above. You will also need to add the secretsmanager:GetSecretValue permission to your ecs Task Execution Role.

```
"secretOptions": [
    {
        "name": "Header",
        "valueFrom": "arn:aws:secretsmanager:us-east-1:<redacted>:secret:<redacted>"
    }
]
```
