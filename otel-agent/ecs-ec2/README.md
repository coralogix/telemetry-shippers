# ECS - OpenTelemetry

The image configuration utilises the *otlp receiver* for both *HTTP (on 4318)* and *GRPC (on 4317)*. Data can be sent using either endpoint.

Our Coralogix exporter allows us to use enrichments such as dynamic `application` or `subsystem` name, which is defined using: `application_name_attributes` and `subsystem_name_attributes` respectively. See [here](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/coralogixexporter) for more information on the Coralogix Exporter.

This guide shows the process for deploying Open Telemetry to ECS to fascilitate the collection of logs, metrics and traces.

### Image

This implementation utilises a wrapper image (**coralogixrepo/otel-coralogix-ecs-ec2**) which is based on the official Open Telemetry Contrib image. The wrapper image is used to dynamically apply the Open Telemetry configuration at runtime from an environment variable.

### Required

- [AWS credentials must be configured](https://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/setup-credentials.html)
- [ecs-cli](https://github.com/aws/amazon-ecs-cli#installing)
- [aws-cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- Coralogix Otel ECS Agent [cloudformation template](https://github.com/coralogix/cloudformation-corlaogix-aws/tree/master/opentelemetry/ecs-ec2)

### Open Telemetry Configuration

The Open Telemetry configuration for the agent is stored in a Base64 encoded environment variable and applied at runtime. This allows you to dynamically pass any configuration values you choose as a parameter to Cloudformation.

This repo provides example of the following configuration files (you can create other configuration with combination for logs/metric/taces) which work directly with the *coralogixrepo/otel-coralogix-ecs-wrapper* docker image for ECS.

- [logging](https://github.com/coralogix/telemetry-shippers/blob/master/otel-agent/ecs-ec2/logging.yaml)
- [traces & metrics](https://github.com/coralogix/telemetry-shippers/blob/master/otel-agent/ecs-ec2/config.yaml)

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
<br>

# The ecslogresourcedetection Processor
---


| Status                          |             |
| ------------------------------- | ----------- |
| Stability                       |  beta: logs |

The coralogixrepo/otel-coralogix-ecs-ec2 docker image includes an Open Telemetry distribution with a dedicated processor designed to handle logs collected at the Host level. This processor enables the collector to discover metadata endpoints for all active containers on an instance, utilizing container IDs to indentify metadata endpoints to enrich logs and establish correlations. It's important to note that the default resourcedetection processor does not offer this specific functionality.

### Pre-requisites
- Privileged mode must be enabled for the container running the collector
- The `docker.sock` must be mounted to the container running the collector at `/var/run/docker.sock`
- This processor uses the container ID to identify the correct metadata endpoint for each container. The processor checks for the container ID in an attribute `container.id` or it will parse it from the `log.file.name` directly. One of these **must** be provided.

### Attributes

| Attribute                       | Value | Default |
| ------------------------------- | ----- | ------- |
| ecs.task.definition.family      | The ECS task defintion family | ✔️ |
| ecs.task.definition.version     | The ECS task defintion version | ✔️ |
| image                           | The container image | ✔️ |
| ecs.container.name              | The name of the running container<br>The name given to the container by the ECS Agent | ✔️ |
| ecs.cluster                     | The ECS cluster name | ✔️ |
| ecs.task.arn                    | The ECS task ARN | ✔️ |
| image.id                        | The image ID of the running container | ✔️ |
| docker.name                     | The name of the running container<br>The is name you will see if you run `docker ps` | ✔️ |
| docker.id                       | The docker container ID | ✔️ |
| name                            | Same as `ecs.container.name` | ✔️ |
| limits.cpu                      | The CPU limit of the container | |
| limits.memory                   | The memory limit of the container | |
| type                            | The type of the container | |
| known.status                    | The lifecycle state of the container | |
| created.at                      | The time the container was created | |
| `networks.*.ipv4.addresses.*` | An expression that matches the IP address(s) assigned to a container | |
| `networks.*.network.mode`         | An expression that matches the network mode(s) associated with the container | |

The ECS Agent container does not have a metadata endpoint. The ecslogresourcedetection processor will automatically detect ECS Agent container and assign the following attribute:
| Attribute                       | Value |
| ------------------------------- | ----- |
| ecs.agent                       | True  |

### Config

The ecslogresourcedetection processor is enabled by adding the keyword `ecslogresourcedetection` to the `processors` section of the configuration file. The processor can be configured using the following options:

| Config | Description                                                                  |
| ------ | ---------------------------------------------------------------------------- |
| attributes | A list of regex patterns that match specific or multiple attribute keys. |

The following config, will collect all the [default attributes](#attributes).

```yaml
processors:
  ecslogresourcedetection:
```

You can specify which attributes should be collected by using the `attributes` option which represents a list of regex patterns that match specific or multiple attribute keys.

```yaml
processors:
  ecslogresourcedetection:
    attributes:
      - '^ecs.*' # all attributes that start with ecs
      - '^docker.*' # all attributes that start with docker
      - '^image.*|^network.*' # all attributes that start with image or network
```

