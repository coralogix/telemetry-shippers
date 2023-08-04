# ECS - OpenTelemetry

The image configuration utilises the *otlp receiver* for both *HTTP (on 4318)* and *GRPC (on 4317)*. Data can be sent using either endpoint.

Our Coralogix exporter allows us to use enrichments such as dynamic `application` or `subsystem` name, which is defined using: `application_name_attributes` and `subsystem_name_attributes` respectively. See [here](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/coralogixexporter) for more information on the Coralogix Exporter.

This guide shows the process for deploying Open Telemetry to ECS to fascilitate the collection of logs, metrics and traces.

### Required

- [AWS credentials must be configured](https://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/setup-credentials.html)
- [ecs-cli](https://github.com/aws/amazon-ecs-cli#installing)
- [aws-cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- Coralogix Otel ECS [cloudformation template](https://github.com/coralogix/cloudformation-coralogix-aws/blob/master/opentelemetry/ecs-ec2/README.md)

### ECS Cluster

If you already have an existing ECS Cluster you can skip this step.

**Deploy a new cluster:**

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

A **Task Definition** is a template defining a container configuration and an **ECS Service** is a configuration item that defines and orchestrates how a task definition should be run.

Deploy the cloudformation template found [here](https://github.com/coralogix/cloudformation-corlaogix-aws/tree/main/opentelemetry/ecs-ec2), ensuring that all the necessary parameters are provided

Once the template is deployed successfully, you can verify if the container is running using:

```sh
ecs-cli ps --region <region> -c <cluster name>
```

### Open Telemetry Configuration

When deploying Open Telemetry in ECS, if you are using the standard Open Telemetry distribution, you will be required to create a custom image with your configuration files baked in. This is not ideal as it requires you to rebuild the image each time you want to make a change to the configuration.

You also have the option of utilising the [coralogixrepo/coralogix-otel-collector](https://hub.docker.com/r/coralogixrepo/coralogix-otel-collector/tags) image. This is a custom distribution based on the official Open Telemetry Contrib image. It includes our custom [ecsattributes processor](https://github.com/coralogix/cloudformation-coralogix-aws/blob/master/opentelemetry/ecs-ec2/components.md#the-ecsattributes-processor) and our [awsecscontainermetrics](https://github.com/coralogix/cloudformation-coralogix-aws/blob/master/opentelemetry/ecs-ec2/components.md#aws-ecs-container-metrics-daemonset-receiver) receiver for ECS, which allow for better attribute and label correlation when running Open Telemetry as a daemonset on ECS.

The image allows you to pass in your configuration files as a Base64 encoded environment variable. `OTEL_CONFIG`

This repo provides example of the following configuration files (you can create other configuration with combination for logs/metric/taces) which work directly with the *coralogixrepo/coralogix-otel-collector* docker image for ECS and the cloudformation template provided [here](https://github.com/coralogix/cloudformation-coralogix-aws/blob/master/opentelemetry/ecs-ec2/README.md).

- [logging](https://github.com/coralogix/telemetry-shippers/blob/master/otel-agent/ecs-ec2/logging.yaml)
- [traces & metrics](https://github.com/coralogix/telemetry-shippers/blob/master/otel-agent/ecs-ec2/config.yaml)

### Deploying Open Telemetry

Once you have your configuration files and ECS Cluster ready, you can deploy Open Telemetry to ECS using the cloudformation templates available [here](https://github.com/coralogix/cloudformation-coralogix-aws/blob/master/opentelemetry/ecs-ec2/README.md).
