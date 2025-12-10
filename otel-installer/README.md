# Coralogix OpenTelemetry Collector Installer

A unified installation script for deploying the Coralogix OpenTelemetry Collector on Linux and macOS.

## Supported Platforms

### Linux Distributions

**Debian-based:**
- Debian
- Ubuntu

**RPM-based:**
- Red Hat Enterprise Linux (RHEL)
- CentOS
- Fedora
- Amazon Linux
- Rocky Linux
- AlmaLinux
- Oracle Linux
- SUSE Linux Enterprise Server (SLES)
- openSUSE

### macOS
- macOS (Intel and Apple Silicon)

### Architectures
- x86_64 (amd64)
- ARM64 (aarch64)

## Quick Start

### One-Line Installation (Recommended)

```bash
CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/coralogix-otel-collector.sh)"
```

### Install Specific Version

```bash
CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/coralogix-otel-collector.sh)" \
  -- -v 0.140.1
```

### With Custom Configuration

```bash
CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/coralogix-otel-collector.sh)" \
  -- -c /path/to/your/config.yaml
```

### Supervisor Mode (Linux only)

Supervisor mode enables remote configuration management through Coralogix OpAMP:

```bash
CORALOGIX_DOMAIN="us1.coralogix.com" CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/coralogix-otel-collector.sh)" \
  -- -s
```

With specific versions for supervisor and collector:

```bash
CORALOGIX_DOMAIN="us1.coralogix.com" CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/coralogix-otel-collector.sh)" \
  -- -s --supervisor-version 0.140.1 --collector-version 0.140.0
```

### macOS LaunchAgent (User-Level)

Install as a user-level agent that runs at login (instead of system-wide at boot):

```bash
CORALOGIX_MACOS_USER_AGENT="true" CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/coralogix-otel-collector.sh)"
```

### Upgrade Existing Installation

Upgrades the binary while preserving your existing configuration:

```bash
CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/coralogix-otel-collector.sh)" \
  -- -u
```

To upgrade and replace config:

```bash
CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/coralogix-otel-collector.sh)" \
  -- -u -c /path/to/new/config.yaml
```

### Uninstall

```bash
# Remove service and binary, keep config and logs (can reinstall later)
bash coralogix-otel-collector.sh --uninstall

# Remove everything including config and logs
bash coralogix-otel-collector.sh --uninstall --purge
```

## Options

| Short | Long | Description |
|-------|------|-------------|
| `-v` | `--version <version>` | Install specific OTEL Collector version (default: latest from Coralogix Helm chart) |
| `-c` | `--config <path>` | Path to custom configuration file (not available with -s/--supervisor) |
| `-s` | `--supervisor` | Install with OpAMP Supervisor mode (Linux only) |
| `-u` | `--upgrade` | Upgrade existing installation |
| | `--supervisor-version <ver>` | Supervisor version (supervisor mode only, default: same as --version) |
| | `--collector-version <ver>` | Collector version (supervisor mode only, default: same as --version) |
| | `--uninstall` | Uninstall the collector |
| | `--purge` | Remove all data when uninstalling (must be used with --uninstall) |
| `-h` | `--help` | Show help message |

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `CORALOGIX_PRIVATE_KEY` | Coralogix private key | Yes |
| `CORALOGIX_DOMAIN` | Coralogix domain (e.g., `us1.coralogix.com`, `eu2.coralogix.com`) | Supervisor mode only |
| `CORALOGIX_MACOS_USER_AGENT` | Set to `true` to install as user-level LaunchAgent on macOS | No |

## Installation Locations

### Linux (Regular Mode)

| Component | Location |
|-----------|----------|
| Binary | `/usr/bin/otelcol-contrib` |
| Config | `/etc/otelcol-contrib/config.yaml` |
| Service | `otelcol-contrib.service` (systemd) |
| Logs | `journalctl -u otelcol-contrib` |

### Linux (Supervisor Mode)

| Component | Location |
|-----------|----------|
| Collector Binary | `/usr/local/bin/otelcol-contrib` |
| Supervisor Config | `/etc/opampsupervisor/config.yaml` |
| Collector Config | `/etc/opampsupervisor/collector.yaml` |
| Effective Config | `/var/lib/opampsupervisor/effective.yaml` |
| Service | `opampsupervisor.service` (systemd) |
| Logs | `/var/log/opampsupervisor/opampsupervisor.log` |

### macOS

| Component | LaunchDaemon (system-wide) | LaunchAgent (user-level) |
|-----------|----------------------------|--------------------------|
| Binary | `/usr/local/bin/otelcol-contrib` | `/usr/local/bin/otelcol-contrib` |
| Config | `/etc/otelcol-contrib/config.yaml` | `/etc/otelcol-contrib/config.yaml` |
| Service | `/Library/LaunchDaemons/com.coralogix.otelcol.plist` | `~/Library/LaunchAgents/com.coralogix.otelcol.plist` |
| Logs | `/var/log/otel-collector/otel-collector.log` | `~/Library/Logs/otel-collector/otel-collector.log` |

## Configuration Behavior

### Regular Mode

| Scenario | Config Action |
|----------|---------------|
| Fresh install (no existing config) | Creates default empty config |
| Fresh install (config exists) | **Preserves existing config** |
| Install with `-c config.yaml` | Uses provided config |
| Upgrade (`-u`) | **Preserves existing config** |
| Upgrade with `-u -c config.yaml` | Replaces with provided config |
| Uninstall | Preserves config (use `--purge` to remove) |

### Supervisor Mode

Supervisor mode always uses an empty local config. The actual configuration is managed remotely via OpAMP server.

### Default Configuration

The default empty config includes:
- `nop` receivers and exporters
- Health check on `127.0.0.1:13133`
- Empty pipelines for traces, metrics, and logs

## Service Management

### Linux (Regular Mode)

```bash
# Check status
sudo systemctl status otelcol-contrib

# Start/Stop/Restart
sudo systemctl start otelcol-contrib
sudo systemctl stop otelcol-contrib
sudo systemctl restart otelcol-contrib

# View logs
sudo journalctl -u otelcol-contrib -f

# View config
cat /etc/otelcol-contrib/config.yaml
```

### Linux (Supervisor Mode)

```bash
# Supervisor status
sudo systemctl status opampsupervisor

# Collector process
ps aux | grep otelcol-contrib

# Supervisor logs
sudo journalctl -u opampsupervisor -f
tail -f /var/log/opampsupervisor/opampsupervisor.log

# View configs
cat /etc/opampsupervisor/config.yaml       # Supervisor config
cat /etc/opampsupervisor/collector.yaml    # Collector config
cat /var/lib/opampsupervisor/effective.yaml # Effective config from OpAMP

# Restart supervisor
sudo systemctl restart opampsupervisor
```

### macOS (LaunchDaemon - system-wide)

```bash
# Check status
sudo launchctl list | grep otelcol

# Stop
sudo launchctl bootout system /Library/LaunchDaemons/com.coralogix.otelcol.plist

# Start
sudo launchctl bootstrap system /Library/LaunchDaemons/com.coralogix.otelcol.plist

# Restart
sudo launchctl bootout system /Library/LaunchDaemons/com.coralogix.otelcol.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.coralogix.otelcol.plist

# View logs
tail -f /var/log/otel-collector/otel-collector.log
```

### macOS (LaunchAgent - user-level)

To install as a user-level agent (runs at login, logs to user directory):

```bash
CORALOGIX_MACOS_USER_AGENT=true CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/coralogix-otel-collector.sh)"
```

```bash
# Check status
launchctl list | grep otelcol

# Stop
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.coralogix.otelcol.plist

# Start
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.coralogix.otelcol.plist

# Restart
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.coralogix.otelcol.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.coralogix.otelcol.plist

# View logs (user-level location)
tail -f ~/Library/Logs/otel-collector/otel-collector.log
```

## Troubleshooting

### Installation fails with "Missing required commands"

Install the required dependencies:
- `curl` - for downloading files
- `tar` - for extracting archives

### Service fails to start

1. Check the service status:
   ```bash
   sudo systemctl status otelcol-contrib  # Linux
   ```

2. Check the logs:
   ```bash
   sudo journalctl -u otelcol-contrib -n 50  # Linux
   tail -f /var/log/otel-collector/otel-collector.log  # macOS
   ```

3. Validate the configuration:
   ```bash
   /usr/bin/otelcol-contrib validate --config /etc/otelcol-contrib/config.yaml
   ```

### Permission denied errors

The script automatically handles sudo. If you encounter permission issues, you can:
- Run as root: `sudo bash script.sh`
- Pre-cache sudo credentials: `sudo -v && bash script.sh`

### Switching between regular and supervisor modes

You must uninstall before switching modes:

```bash
# Uninstall current installation
bash coralogix-otel-collector.sh --uninstall --purge

# Install with different mode
CORALOGIX_DOMAIN="..." CORALOGIX_PRIVATE_KEY="..." bash coralogix-otel-collector.sh -s
```

## Requirements

- Linux (Debian/Ubuntu or RPM-based) or macOS
- Architecture: amd64 or arm64
- Root/sudo access (except for macOS LaunchAgent mode)
- `curl` and `tar` commands

## License

See LICENSE file in the repository root.
