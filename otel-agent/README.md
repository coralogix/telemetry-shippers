# OpenTelemetry Agent

The OpenTelemetry collector offers a vendor-agnostic implementation of how to receive, process and export telemetry data.

The section contains integrations of the Open Telemetry agent for various platforms. Agents are intented to be run as daemons on each server node or instance within a cluster or environment in order to collect logs, metrics and traces.

```
┌────────┬─────┐
│   Node │Agent├───────────────────┐
└────────┴─────┘                   │
                                   │
                              ┌────▼──────┐
┌────────┬─────┐              │           │
│   Node │Agent├──────────────► Coralogix │
└────────┴─────┘              │           │
                              └─────▲─────┘
                                    │
┌────────┬─────┐                    │
│   Node │Agent├────────────────────┘
└────────┴─────┘

```

**Agent Implementations:**

1. [ecs-ec2](./ecs-ec2/)
2. [k8s helm](./k8s-helm/)

## Coralogix's Endpoints

Depending on your region, you need to configure correct Coralogix endpoint. Here are the available Domains:

https://coralogix.com/docs/coralogix-endpoints/.

Example configuration:

```yaml
#config.yaml:
---
coralogix:
  domain: "<coralogix domain here>"
```
