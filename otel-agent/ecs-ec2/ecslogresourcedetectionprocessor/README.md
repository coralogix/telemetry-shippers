# The ecslogresourcedetection Processor
---


| Status                          |             |
| ------------------------------- | ----------- |
| Stability                       |  beta: logs |

The [coralogixrepo/otel-coralogix-ecs-ec2](https://hub.docker.com/r/coralogixrepo/otel-coralogix-ecs-ec2/tags) docker image includes an Open Telemetry distribution with a dedicated processor designed to handle logs collected at the Host level. This processor enables the collector to discover metadata endpoints for all active containers on an instance, utilizing container IDs to indentify metadata endpoints to enrich logs and establish correlations. It's important to note that the default resourcedetection processor does not offer this specific functionality.

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

