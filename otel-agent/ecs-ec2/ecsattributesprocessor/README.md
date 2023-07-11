# The ecsattributes Processor

---

| Status    |            |                       |
|-----------|------------|-----------------------|
| Stability | beta: logs | WEP: metrics & traces |

The coralogixrepo/otel-coralogix-ecs-ec2 docker image includes an Open Telemetry distribution with a dedicated processor designed to handle metadata enrichment for logs collected at the Host level. This processor enables the collector to discover metadata endpoints for all active containers on an instance, utilizing container IDs to indentify metadata endpoints to enrich logs and establish correlations. It's important to note that the default resourcedetection processor does not offer this specific functionality.

### Pre-requisites
- Privileged mode must be enabled for the container running the collector
- The `docker.sock` must be mounted to the container running the collector at `/var/run/docker.sock`
- This processor uses the container ID to identify the correct metadata endpoint for each container. The processor checks for the container ID in **resource** attribute(s) specified during configuration. If no container ID can be determined, no metadata will be added.

### Attributes

| Attribute                       | Value                                                                               | Default |
|---------------------------------|-------------------------------------------------------------------------------------|---------|
| aws.ecs.task.definition.family  | The ECS task defintion family                                                       | ✔️       |
| aws.ecs.task.definition.version | The ECS task defintion version                                                      | ✔️       |
| image                           | The container image                                                                 | ✔️       |
| aws.ecs.container.name          | The name of the running container. The name given to the container by the ECS Agent | ✔️       |
| aws.ecs.container.arn           | The ECS instance ARN                                                                | ✔️       |
| aws.ecs.cluster                 | The ECS cluster name                                                                | ✔️       |
| aws.ecs.task.arn                | The ECS task ARN                                                                    | ✔️       |
| image.id                        | The image ID of the running container                                               | ✔️       |
| docker.name                     | The name of the running container. The is name you will see if you run `docker ps`  | ✔️       |
| docker.id                       | The docker container ID                                                             | ✔️       |
| name                            | Same as `ecs.container.name`                                                        | ✔️       |
| limits.cpu                      | The CPU limit of the container                                                      |         |
| limits.memory                   | The memory limit of the container                                                   |         |
| type                            | The type of the container                                                           |         |
| aws.ecs.known.status            | The lifecycle state of the container                                                |         |
| created.at                      | The time the container was created                                                  |         |
| `networks.*.ipv4.addresses.*`   | An expression that matches the IP address(s) assigned to a container                |         |
| `networks.*.network.mode`       | An expression that matches the network mode(s) associated with the container        |         |

Only containers with a valid ECS metadata endpoint will have attributes assigned, all others will be ignored.

To verify your container has a valid ECS metadata endpoint, you can check for the following environment variables in the your running container:

- ECS_CONTAINER_METADATA_URI
- ECS_CONTAINER_METADATA_URI_V4

Atleast one must be present.

### Configuration

The ecsattributes processor is enabled by adding the keyword `ecsattributes` to the `processors` section of the configuration file. The processor can be configured using the following options:

| Config               | Description                                                                                                                                                                      |
|----------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| attributes           | A list of regex patterns that match specific or multiple attribute keys.                                                                                                         |
| container_id.sources | The **resource** attribute key that contains the container ID. Defaults to `container.id`. If multiple attribute keys are provided, the first none-empty value will be selected. |

Note, given a `log.file.name=<container.id>-json.log`, the `ecsattributesprocessor` will automatically remove the `-json.log` suffix from the container ID when correlating metadata.

The following config, will collect all the [default attributes](#attributes).

```yaml
processors:
  ecsattributes:

  # check for container id in the following attributes:
  container_id:
    sources:
      - "container.id"
      - "log.file.name"
```

You can specify which attributes should be collected by using the `attributes` option which represents a list of regex patterns that match specific or multiple attribute keys.

```yaml
processors:
  ecsattributes:
    attributes:
      - '^aws.ecs.*' # all attributes that start with ecs
      - '^docker.*' # all attributes that start with docker
      - '^image.*|^network.*' # all attributes that start with image or network
```
