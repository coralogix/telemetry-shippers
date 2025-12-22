# How to install the Supervised Collector in a Linux machine

## Prerequisites

- A running Linux machine
  - Only Debian or RPM based Linux distributions are supported
  - Only amd64 and arm64 architectures are supported
- `curl` and `tar` commands are available

## Installation

Use the `install.sh` script to install the Supervised Collector. You need to provide your Coralogix Private Key and Domain.

```sh
CORALOGIX_PRIVATE_KEY="<YOUR_PRIVATE_KEY>" CORALOGIX_DOMAIN="<YOUR_DOMAIN>" bash -c "$(curl -fsSL https://raw.githubusercontent.com/coralogix/otel-supervised-collector/master/install.sh)"
```

The script will:
1. Install the OpAMP Supervisor
2. Install the OpenTelemetry Collector
3. Configure the Supervisor to connect to Coralogix
4. Create a default Collector configuration

- By default the script fetches the latest recommended version from this repository's `master` branch.
  If that network fetch fails or you want to pin a specific release, set the `VERSION` environment
  variable before running the script, e.g. `VERSION=0.141.0 ./install.sh`. This bypasses the fetch
  and uses the value you provide.

## Configuration

The installation script sets up the initial configuration at `/etc/opampsupervisor/config.yaml`.
It uses the provided environment variables to authenticate with Coralogix.

You can customize the collector configuration by editing `/etc/opampsupervisor/collector.yaml`.

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
