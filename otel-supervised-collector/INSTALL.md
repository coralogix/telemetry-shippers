# How to install the Supervised Collector in a Linux machine

## Prerequisites

- A running Linux machine
  - Only Debian or RPM based Linux distributions are supported
  - Only amd64 and arm64 architectures are supported
- `curl` and `tar` commands are available

## Installation

Use the `install.sh` script to install the Supervised Collector.

## Configuration

The Supervised Collector is configured using a YAML file.

There is an example configuration file at `/etc/opampsupervisor/config.example.yaml`.
Copy it or create a new one and edit it to your needs. Here's a handy example:

```yaml
server:
  endpoint: "https://ingress.<YOUR_CORALOGIX_DOMAIN_URL>/opamp/v1"
  headers:
    Authorization: "Bearer ${env:CORALOGIX_PRIVATE_KEY}"
  tls:
    insecure_skip_verify: true

capabilities:
  reports_effective_config: true
  reports_own_metrics: true
  reports_own_logs: true
  reports_own_traces: true
  reports_health: true
  accepts_remote_config: true
  reports_remote_config: true

agent:
  executable: /usr/local/bin/otelcol-contrib
  passthrough_logs: true

  description:
    non_identifying_attributes:
      service.name: "opentelemetry-collector"
      cx.agent.type: "standalone"

  # This passes config files to the Collector.
  config_files:
    - /etc/opampsupervisor/collector.yaml

  # This adds CLI arguments to the Collector.
  args: []

  # This adds env vars to the Collector process.
  env:
    CORALOGIX_PRIVATE_KEY: "${env:CORALOGIX_PRIVATE_KEY}"

# The storage can be used for many things:
# - It stores configuration sent by the OpAMP server so that new collector
#   processes can start with the most known desired config.
storage:
  directory: /var/lib/opampsupervisor/

telemetry:
  logs:
    level: debug
    output_paths:
      - /var/log/opampsupervisor/opampsupervisor.log
```

Now append the `CORALOGIX_PRIVATE_KEY` environment variable to the
`/etc/opampsupervisor/opampsupervisor.conf` file to pass the environment
variable to the Supervisor process:

```sh
CORALOGIX_PRIVATE_KEY="<YOUR_CORALOGIX_PRIVATE_KEY>"
```

Now, create a basic empty configuration file for the Collector at `/etc/opampsupervisor/collector.yaml`:

```yaml
receivers:
  nop:
exporters:
  nop:
extensions:
  health_check:
    endpoint: 127.0.0.1:13133
service:
  extensions:
    - health_check
  telemetry:
    logs:
      encoding: json
  pipelines:
    traces:
      receivers: [nop]
      exporters: [nop]
    metrics:
      receivers: [nop]
      exporters: [nop]
    logs:
      receivers: [nop]
      exporters: [nop]
```

# Running it

To run the Supervisor, use the following command:

```
sudo systemctl start opampsupervisor
```

To check the status of the Supervisor, use the following command:

```
sudo systemctl status opampsupervisor
```

To check the logs of the Collector, use the following command:

```
tail -f /var/log/opampsupervisor/opampsupervisor.log
```

## Uninstallation

Use the `uninstall.sh` script to uninstall the Supervised Collector.
