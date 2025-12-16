# Windows Installation

Install the OpenTelemetry Collector directly on Windows as a Windows Service.

## Overview

This PowerShell script deploys the Coralogix OpenTelemetry Collector as a Windows Service. It supports both **regular mode** (local config) and **supervisor mode** (remote config via Fleet Management).

## Prerequisites

- Windows 10/11, Windows Server 2016 or later
- PowerShell 5.1 or later
- Administrator privileges
- Coralogix [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/)

## Quick Start

Run the following command in PowerShell (as Administrator) to install the collector with default configuration:

```powershell
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'))
```

Or download and run the script locally:

```powershell
# Download the script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1" -OutFile "coralogix-otel-collector.ps1"

# Run with your private key
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1
```

## Environment Variables

| Variable | Required | Description |
| --- | --- | --- |
| CORALOGIX_PRIVATE_KEY | Yes | Your Coralogix [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/) |
| CORALOGIX_DOMAIN | Supervisor mode only | Your Coralogix [domain](https://coralogix.com/docs/coralogix-domain/) |

## Supported Platforms

### Windows Versions

- Windows 10 (all editions)
- Windows 11 (all editions)
- Windows Server 2016 and later

### Architectures

- x64 (amd64)
- ARM64

## Install with Custom Configuration

To install with your own configuration file:

```powershell
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -Config C:\path\to\config.yaml
```

## Install Specific Version

```powershell
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -Version 0.140.1
```

## Supervisor Mode

Supervisor mode enables remote configuration management through Coralogix Fleet Management:

```powershell
$env:CORALOGIX_DOMAIN="<your-domain>"
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -Supervisor
```

Install with supervisor using specific versions:

```powershell
$env:CORALOGIX_DOMAIN="<your-domain>"
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -Supervisor -SupervisorVersion 0.140.1 -CollectorVersion 0.140.0
```

## Script Parameters

| Parameter | Description |
| --- | --- |
| `-Version <version>` | Install specific collector version |
| `-Config <path>` | Path to custom configuration file |
| `-Supervisor` | Install with OpAMP Supervisor mode |
| `-Upgrade` | Upgrade existing installation (preserves config) |
| `-SupervisorVersion <version>` | Supervisor version (supervisor mode only) |
| `-CollectorVersion <version>` | Collector version (supervisor mode only) |
| `-Uninstall` | Remove the collector (keeps config) |
| `-Uninstall -Purge` | Remove the collector and all configuration |
| `-Help` | Show help message |

## Installation Locations

### Regular Mode

| Component | Location |
| --- | --- |
| Binary | `C:\Program Files\OpenTelemetry\Collector\otelcol-contrib.exe` |
| Configuration | `C:\ProgramData\OpenTelemetry\Collector\config.yaml` |
| Service | `otelcol-contrib` (Windows Service) |
| Logs | Windows Event Log (Application) |

### Supervisor Mode

| Component | Location |
| --- | --- |
| Collector Binary | `C:\Program Files\OpenTelemetry\Collector\otelcol-contrib.exe` |
| Supervisor Binary | `C:\Program Files\OpenTelemetry\Supervisor\opampsupervisor.exe` |
| Supervisor Config | `C:\ProgramData\OpenTelemetry\Supervisor\config.yaml` |
| Collector Config | `C:\ProgramData\OpenTelemetry\Supervisor\collector.yaml` |
| Effective Config | `C:\ProgramData\OpenTelemetry\Supervisor\state\effective.yaml` |
| Service | `opampsupervisor` (Windows Service) |
| Logs | `C:\ProgramData\OpenTelemetry\Supervisor\logs\opampsupervisor.log` |

## Service Management

### Regular Mode

```powershell
# Check status
Get-Service otelcol-contrib

# View logs (Event Log)
Get-EventLog -LogName Application -Source otelcol-contrib -Newest 50

# Restart
Restart-Service otelcol-contrib

# Stop
Stop-Service otelcol-contrib

# Start
Start-Service otelcol-contrib

# Validate config
& "C:\Program Files\OpenTelemetry\Collector\otelcol-contrib.exe" validate --config "C:\ProgramData\OpenTelemetry\Collector\config.yaml"
```

### Supervisor Mode

```powershell
# Check status
Get-Service opampsupervisor

# View logs
Get-Content "C:\ProgramData\OpenTelemetry\Supervisor\logs\opampsupervisor.log" -Tail 50 -Wait

# Restart
Restart-Service opampsupervisor

# Stop
Stop-Service opampsupervisor

# Start
Start-Service opampsupervisor

# Check collector process
Get-Process otelcol-contrib
```

## Upgrade

Upgrade the collector while preserving your existing configuration:

```powershell
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -Upgrade
```

To upgrade and replace the configuration:

```powershell
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -Upgrade -Config C:\path\to\new-config.yaml
```

## Uninstall

Remove the collector while keeping configuration and logs:

```powershell
.\coralogix-otel-collector.ps1 -Uninstall
```

Remove the collector and all data:

```powershell
.\coralogix-otel-collector.ps1 -Uninstall -Purge
```

## Configuration Behavior

| Scenario | Action |
| --- | --- |
| Fresh install | Creates default empty config |
| Config exists | Preserves existing config |
| With `-Config` | Uses provided config |
| Upgrade (`-Upgrade`) | Preserves existing config |
| Supervisor mode | Config managed remotely via OpAMP |

## Troubleshooting

### Service fails to start

1. Check status: `Get-Service otelcol-contrib`
2. Check Event Log: `Get-EventLog -LogName Application -Source otelcol-contrib -Newest 50`
3. Validate config:
   ```powershell
   & "C:\Program Files\OpenTelemetry\Collector\otelcol-contrib.exe" validate --config "C:\ProgramData\OpenTelemetry\Collector\config.yaml"
   ```

### Script execution policy

If you encounter execution policy errors, run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Or run the script with bypass:

```powershell
powershell -ExecutionPolicy Bypass -File .\coralogix-otel-collector.ps1
```

### Switching between modes

Uninstall before switching between regular and supervisor modes:

```powershell
.\coralogix-otel-collector.ps1 -Uninstall -Purge
$env:CORALOGIX_DOMAIN="<your-domain>"
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -Supervisor
```

### Administrator privileges

The script requires administrator privileges. If you see permission errors:

1. Right-click PowerShell
2. Select "Run as Administrator"
3. Run the script again

## Additional Resources

| | |
| --- | --- |
| GitHub Repository | [telemetry-shippers](https://github.com/coralogix/telemetry-shippers/tree/master/otel-installer) |
| OpenTelemetry Documentation | [OpenTelemetry](https://opentelemetry.io/docs/collector/) |

## Support

**Need help?**

Our world-class customer success team is available 24/7 to walk you through your setup and answer any questions that may come up.

Feel free to reach out to us **via our in-app chat** or by sending us an email at [support@coralogix.com](mailto:support@coralogix.com).

