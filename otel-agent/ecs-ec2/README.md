# ECS - OpenTelemetry

The image configuration utilises the _otlp receiver_ for both _HTTP (on 4318)_  and _GRPC (on 4317)_. Data can be sent using either endpoint.

Our Coralogix exporter allows us to use enrichments such as dynamic `application` or `subsystem` name, which is defined using: `application_name_attributes` and `subsystem_name_attributes` respectively. See [here](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/coralogixexporter) for more information on the Coralogix Exporter.


This guide shows the process for deploying Open Telemetry to ECS to fascilitate the collection of logs, metrics and traces.


### Image

This implementation utilises a wrapper image (__coralogixrepo/otel-coralogix-ecs-ec2__) which is based on the official Open Telemetry Contrib image. The wrapper image is used to dynamically apply the Open Telemetry configuration at runtime from an environment variable.


### Required

- [AWS credentials must be configured](https://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/setup-credentials.html)
- [ecs-cli](https://github.com/aws/amazon-ecs-cli#installing)
- [aws-cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- Coralogix Otel ECS Agent [cloudformation template](https://github.com/coralogix/cloudformation-corlaogix-aws/tree/master/opentelemetry/ecs-ec2)


### Open Telemetry Configuration

The Open Telemetry configuration for the agent is stored in a Base64 encoded environment variable and applied at runtime. This allows you to dynamically pass any configuration values you choose as a parameter to Cloudformation.

This repo provides example of the following configuration files (you can create other configuration with combination for logs/metric/taces) which work directly with the _coralogixrepo/otel-coralogix-ecs-wrapper_ docker image for ECS.

- [logging](https://github.com/coralogix/telemetry-shippers/blob/master/otel-agent/ecs-ec2/logging.yaml)
- [traces & metrics](https://github.com/coralogix/telemetry-shippers/blob/master/otel-agent/ecs-ec2/config.yaml)



### ECS Cluster

If you already have an existing ECS Cluster you can skip this step. 

__Deploy a new cluster:__

```sh
ecs-cli up --region <region> --keypair <your-key-pair> --cluster <cluster-name> --size <no. of instances> --capability-iam 
```

The `--keypair` flag is not mandetory, however, if not supplied you will not be able to connect to any of the instances in the cluster via SSH. You can create a key pair using the command below:

```sh
aws ec2 create-key-pair --key-name MyKeyPair --query 'KeyMaterial' --output text > MyKeyPair.pem
```

The `ecs-cli up` command will levarage cloudformation to create an ECS Cluster. Default values will be used to create and configure a VPC and Subnets, however these values and more can be controlled from `ecs-cli` as well, see:

```sh
ecs-cli up --help
```


### ECS Task Definition & Service

Once we have an ECS Cluster in place, we need to deploy a Task Definition, which is used by ECS to create an ECS Service to run Open Telemetry.

A __Task Definition__ is a template defining a container configuration and an __ECS Service__ is a configuration item that defines and orchestrates how a task definition should be run.

Deploy the cloudformation template found [here](https://github.com/coralogix/cloudformation-corlaogix-aws/tree/main/opentelemetry/ecs-ec2), ensuring that all the necessary parameters are provided

Once the template is deployed successfully, you can verify if the container is running using:

```sh
ecs-cli ps --region <region> -c <cluster name>
```

