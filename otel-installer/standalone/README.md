# Standalone Installation (Linux/macOS)

Install the OpenTelemetry Collector directly on Linux or macOS as a system service.

## Overview

This script deploys the Coralogix OpenTelemetry Collector as:
- **Linux**: systemd service
- **macOS**: LaunchDaemon (system-wide) or LaunchAgent (user-level)

Both support **regular mode** (local config) and **supervisor mode** (remote config via Fleet Management).

<!-- split title=&#34;Linux Installation&#34; path=&#34;installation/linux/index.md&#34; -->

# Linux Installation

Install the OpenTelemetry Collector as a systemd service on Linux.

## Prerequisites

- Linux (Debian, Ubuntu, RHEL, CentOS, Amazon Linux, SUSE)
- `curl` and `tar` commands
- Root/sudo access
- Coralogix [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/)

## Quick Start

Run the following command to install the collector with default configuration:

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)"
```

## Environment Variables

### Required Variables

| Variable              | Required             | Description                                                                                 |
|-----------------------|----------------------|---------------------------------------------------------------------------------------------|
| CORALOGIX_PRIVATE_KEY | Yes                  | Your Coralogix [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/) |
| CORALOGIX_DOMAIN      | Supervisor mode only | Your Coralogix [domain](https://coralogix.com/docs/coralogix-domain/)                       |

### Automatically Set Variables

The installer automatically sets these environment variables for the collector service:

| Variable              | Default   | Description                                                         |
|-----------------------|-----------|---------------------------------------------------------------------|
| OTEL_MEMORY_LIMIT_MIB | 512       | Memory limit in MiB (set via `--memory-limit` flag)                 |
| OTEL_LISTEN_INTERFACE | 127.0.0.1 | Network interface for receivers (set via `--listen-interface` flag) |

To use these in your configuration file:

```yaml
processors:
  memory_limiter:
    limit_mib: ${env:OTEL_MEMORY_LIMIT_MIB:-512}

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: ${env:OTEL_LISTEN_INTERFACE:-127.0.0.1}:4317
```

## Supported Platforms

### Linux Distributions

- Debian, Ubuntu
- RHEL, CentOS, Fedora
- Amazon Linux, Amazon Linux 2023
- Rocky Linux, AlmaLinux, Oracle Linux
- SUSE Linux Enterprise Server, openSUSE

### Architectures

- x86_64 (amd64)
- ARM64 (aarch64)

## Install with Custom Configuration

To install with your own configuration file:

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- --config /path/to/config.yaml
```

## Install Specific Version

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- --version 0.140.1
```

## Install with Custom Memory Limit

Allocate more memory to the collector (useful for high-volume environments):

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- --memory-limit 2048
```

> **Note:** Your configuration must reference `${env:OTEL_MEMORY_LIMIT_MIB}` for this to take effect.

## Install as Gateway (Listen on All Interfaces)

By default, the collector listens only on `127.0.0.1` (localhost). To accept connections from other hosts (gateway mode):

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- --listen-interface 0.0.0.0
```

> **Note:** Your configuration must reference `${env:OTEL_LISTEN_INTERFACE}` for this to take effect.

## Install with Custom Memory and Network Settings

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- --memory-limit 2048 --listen-interface 0.0.0.0
```

## Enable Comprehensive Process Metrics

By default, the collector may not have permissions to read detailed process metrics (CPU, memory, disk I/O) for all processes. Use the `--enable-process-metrics` flag to grant the necessary Linux capabilities:

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- --enable-process-metrics
```

This grants `CAP_SYS_PTRACE` and `CAP_DAC_READ_SEARCH` capabilities to the collector binary, allowing it to:
- Read `/proc/[pid]/io` for all processes (disk I/O metrics)
- Access process information for all users (not just the collector user)

> **Security Note:** This is a secure, opt-in mechanism that avoids running the collector as root. The capabilities are granted only to the collector binary using Linux capabilities.

## Supervisor Mode

Supervisor mode enables remote configuration management through Coralogix Fleet Management:

```bash
CORALOGIX_DOMAIN="<your-domain>" CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- --supervisor
```

## Script Options

| Option                           | Description                                                                                                        |
|----------------------------------|--------------------------------------------------------------------------------------------------------------------|
| `-v, --version <version>`        | Install specific collector version                                                                                 |
| `-c, --config <path>`            | Path to custom configuration file                                                                                  |
| `-s, --supervisor`               | Install with OpAMP Supervisor mode (Linux only)                                                                    |
| `-u, --upgrade`                  | Upgrade existing installation (preserves config)                                                                   |
| `--memory-limit <MiB>`           | Total memory in MiB to allocate to the collector (default: 512) (ignored in supervisor mode)                       |
| `--listen-interface <ip>`        | Network interface for receivers to listen on (default: 127.0.0.1). Use `0.0.0.0` for all interfaces (gateway mode) |
| `--enable-process-metrics`       | Grant Linux capabilities for comprehensive process metrics collection                                              |
| `--supervisor-version <version>` | Supervisor version (supervisor mode only)                                                                          |
| `--collector-version <version>`  | Collector version (supervisor mode only)                                                                           |
| `--uninstall`                    | Remove the collector (keeps config)                                                                                |
| `--uninstall --purge`            | Remove the collector and all configuration                                                                         |
| `-h, --help`                     | Show help message                                                                                                  |

> **Note:** `--memory-limit` sets the `OTEL_MEMORY_LIMIT_MIB` environment variable. Your configuration must reference `${env:OTEL_MEMORY_LIMIT_MIB}` for this to take effect.
>
> **Note:** `--listen-interface` sets the `OTEL_LISTEN_INTERFACE` environment variable. Your configuration must reference `${env:OTEL_LISTEN_INTERFACE}` for this to take effect.

## Installation Locations

### Regular Mode

| Component     | Location                            |
|---------------|-------------------------------------|
| Binary        | `/usr/bin/otelcol-contrib`          |
| Configuration | `/etc/otelcol-contrib/config.yaml`  |
| Service       | `otelcol-contrib.service` (systemd) |
| Logs          | `journalctl -u otelcol-contrib`     |

### Supervisor Mode

| Component         | Location                                       |
|-------------------|------------------------------------------------|
| Collector Binary  | `/usr/local/bin/otelcol-contrib`               |
| Supervisor Config | `/etc/opampsupervisor/config.yaml`             |
| Effective Config  | `/var/lib/opampsupervisor/effective.yaml`      |
| Service           | `opampsupervisor.service` (systemd)            |
| Logs              | `/var/log/opampsupervisor/opampsupervisor.log` |

## Service Management

### Regular Mode

```bash
# Check status
sudo systemctl status otelcol-contrib

# View logs
sudo journalctl -u otelcol-contrib -f

# Restart
sudo systemctl restart otelcol-contrib

# Validate config
/usr/bin/otelcol-contrib validate --config /etc/otelcol-contrib/config.yaml
```

### Supervisor Mode

```bash
# Check status
sudo systemctl status opampsupervisor

# View logs
sudo journalctl -u opampsupervisor -f
tail -f /var/log/opampsupervisor/opampsupervisor.log

# Restart
sudo systemctl restart opampsupervisor
```

## Upgrade

Upgrade the collector while preserving your existing configuration:

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- --upgrade
```

To upgrade and replace the configuration:

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- --upgrade --config /path/to/new-config.yaml
```

## Uninstall

Remove the collector while keeping configuration and logs:

```bash
bash coralogix-otel-collector.sh --uninstall
```

Remove the collector and all data:

```bash
bash coralogix-otel-collector.sh --uninstall --purge
```

## Configuration Behavior

| Scenario              | Action                            |
|-----------------------|-----------------------------------|
| Fresh install         | Creates default empty config      |
| Config exists         | Preserves existing config         |
| With `--config`       | Uses provided config              |
| Upgrade (`--upgrade`) | Preserves existing config         |
| Supervisor mode       | Config managed remotely via OpAMP |

### Environment Variables in Configuration

The installer automatically sets `OTEL_MEMORY_LIMIT_MIB` and `OTEL_LISTEN_INTERFACE` environment variables for the collector service. To use them in your custom configuration:

- **Memory Limiter:** `limit_mib: ${env:OTEL_MEMORY_LIMIT_MIB:-512}`
- **Receiver Endpoint:** `endpoint: ${env:OTEL_LISTEN_INTERFACE:-127.0.0.1}:4317`

The installer will warn you if you specify `--memory-limit` or `--listen-interface` but your configuration doesn't reference these variables.

## Troubleshooting

### Service fails to start

1. Check status: `sudo systemctl status otelcol-contrib`
2. Check logs: `sudo journalctl -u otelcol-contrib -n 50`
3. Validate config: `/usr/bin/otelcol-contrib validate --config /etc/otelcol-contrib/config.yaml`

### Switching between modes

Uninstall before switching between regular and supervisor modes:

```bash
bash coralogix-otel-collector.sh --uninstall --purge
CORALOGIX_DOMAIN="<your-domain>" CORALOGIX_PRIVATE_KEY="<your-private-key>" bash coralogix-otel-collector.sh --supervisor
```

<!-- /split -->

<!-- split title=&#34;macOS Installation&#34; path=&#34;installation/macos/index.md&#34; -->

# macOS Installation

Install the OpenTelemetry Collector on macOS as a LaunchDaemon (system-wide) or LaunchAgent (user-level).

## Prerequisites

- macOS (Intel or Apple Silicon)
- `curl` and `tar` commands
- Root/sudo access
- Coralogix [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/)

## Quick Start

Run the following command to install the collector with default configuration:

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)"
```

## Environment Variables

### Required Variables

| Variable                   | Required | Description                                                                                 |
|----------------------------|----------|---------------------------------------------------------------------------------------------|
| CORALOGIX_PRIVATE_KEY      | Yes      | Your Coralogix [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/) |
| CORALOGIX_MACOS_USER_AGENT | No       | Set to `true` to install as user-level LaunchAgent (default: system-wide LaunchDaemon)      |

### Automatically Set Variables

The installer automatically sets these environment variables for the collector service:

| Variable              | Default   | Description                                                         |
|-----------------------|-----------|---------------------------------------------------------------------|
| OTEL_MEMORY_LIMIT_MIB | 512       | Memory limit in MiB (set via `--memory-limit` flag)                 |
| OTEL_LISTEN_INTERFACE | 127.0.0.1 | Network interface for receivers (set via `--listen-interface` flag) |

To use these in your configuration file:

```yaml
processors:
  memory_limiter:
    limit_mib: ${env:OTEL_MEMORY_LIMIT_MIB:-512}

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: ${env:OTEL_LISTEN_INTERFACE:-127.0.0.1}:4317
```

> **Note:** Supervisor mode is not supported on macOS.

## macOS LaunchAgent (User-Level)

Install as a user-level agent that runs at login (instead of system-wide at boot):

```bash
CORALOGIX_MACOS_USER_AGENT="true" CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)"
```

## Install with Custom Configuration

To install with your own configuration file:

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- --config /path/to/config.yaml
```

## Install Specific Version

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- --version 0.140.1
```

## Install with Custom Memory Limit

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- --memory-limit 2048
```

> **Note:** Your configuration must reference `${env:OTEL_MEMORY_LIMIT_MIB}` for this to take effect.

## Install as Gateway (Listen on All Interfaces)

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- --listen-interface 0.0.0.0
```

> **Note:** Your configuration must reference `${env:OTEL_LISTEN_INTERFACE}` for this to take effect.

## Script Options

| Option                    | Description                                                                                                        |
|---------------------------|--------------------------------------------------------------------------------------------------------------------|
| `-v, --version <version>` | Install specific collector version                                                                                 |
| `-c, --config <path>`     | Path to custom configuration file                                                                                  |
| `-u, --upgrade`           | Upgrade existing installation (preserves config)                                                                   |
| `--memory-limit <MiB>`    | Total memory in MiB to allocate to the collector (default: 512)                                                    |
| `--listen-interface <ip>` | Network interface for receivers to listen on (default: 127.0.0.1). Use `0.0.0.0` for all interfaces (gateway mode) |
| `--uninstall`             | Remove the collector (keeps config)                                                                                |
| `--uninstall --purge`     | Remove the collector and all configuration                                                                         |
| `-h, --help`              | Show help message                                                                                                  |

> **Note:** `--memory-limit` sets the `OTEL_MEMORY_LIMIT_MIB` environment variable. Your configuration must reference `${env:OTEL_MEMORY_LIMIT_MIB}` for this to take effect.
>
> **Note:** `--listen-interface` sets the `OTEL_LISTEN_INTERFACE` environment variable. Your configuration must reference `${env:OTEL_LISTEN_INTERFACE}` for this to take effect.

## Installation Locations

| Component     | LaunchDaemon (system-wide)                           | LaunchAgent (user-level)                             |
|---------------|------------------------------------------------------|------------------------------------------------------|
| Binary        | `/usr/local/bin/otelcol-contrib`                     | `/usr/local/bin/otelcol-contrib`                     |
| Configuration | `/etc/otelcol-contrib/config.yaml`                   | `/etc/otelcol-contrib/config.yaml`                   |
| Plist         | `/Library/LaunchDaemons/com.coralogix.otelcol.plist` | `~/Library/LaunchAgents/com.coralogix.otelcol.plist` |
| Logs          | `/var/log/otel-collector/otel-collector.log`         | `~/Library/Logs/otel-collector/otel-collector.log`   |

## Service Management

### LaunchDaemon (System-Wide)

```bash
# Check status
sudo launchctl list | grep otelcol

# View logs
tail -f /var/log/otel-collector/otel-collector.log

# Restart
sudo launchctl bootout system /Library/LaunchDaemons/com.coralogix.otelcol.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.coralogix.otelcol.plist
```

### LaunchAgent (User-Level)

```bash
# Check status
launchctl list | grep otelcol

# View logs
tail -f ~/Library/Logs/otel-collector/otel-collector.log

# Restart
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.coralogix.otelcol.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.coralogix.otelcol.plist
```

## Upgrade

Upgrade the collector while preserving your existing configuration:

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- --upgrade
```

To upgrade and replace the configuration:

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- --upgrade --config /path/to/new-config.yaml
```

## Uninstall

Remove the collector while keeping configuration and logs:

```bash
bash coralogix-otel-collector.sh --uninstall
```

Remove the collector and all data:

```bash
bash coralogix-otel-collector.sh --uninstall --purge
```

## Configuration Behavior

| Scenario              | Action                       |
|-----------------------|------------------------------|
| Fresh install         | Creates default empty config |
| Config exists         | Preserves existing config    |
| With `--config`       | Uses provided config         |
| Upgrade (`--upgrade`) | Preserves existing config    |

### Environment Variables in Configuration

The installer automatically sets `OTEL_MEMORY_LIMIT_MIB` and `OTEL_LISTEN_INTERFACE` environment variables for the collector service. To use them in your custom configuration:

- **Memory Limiter:** `limit_mib: ${env:OTEL_MEMORY_LIMIT_MIB:-512}`
- **Receiver Endpoint:** `endpoint: ${env:OTEL_LISTEN_INTERFACE:-127.0.0.1}:4317`

The installer will warn you if you specify `--memory-limit` or `--listen-interface` but your configuration doesn't reference these variables.

## Troubleshooting

### Service fails to start

1. Check plist exists: `ls -la /Library/LaunchDaemons/com.coralogix.otelcol.plist`
2. Check logs: `tail -f /var/log/otel-collector/otel-collector.log`
3. Validate config: `/usr/local/bin/otelcol-contrib validate --config /etc/otelcol-contrib/config.yaml`

<!-- /split -->

## Additional Resources

|                             |                                                                                                  |
|-----------------------------|--------------------------------------------------------------------------------------------------|
| GitHub Repository           | [telemetry-shippers](https://github.com/coralogix/telemetry-shippers/tree/master/otel-installer) |
| OpenTelemetry Documentation | [OpenTelemetry](https://opentelemetry.io/docs/collector/)                                        |

## Support

**Need help?**

Our world-class customer success team is available 24/7 to walk you through your setup and answer any questions that may come up.

Feel free to reach out to us **via our in-app chat** or by sending us an email at [support@coralogix.com](mailto:support@coralogix.com).
