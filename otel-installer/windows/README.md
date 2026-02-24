# Windows Installation

Install the OpenTelemetry Collector directly on Windows as a Windows Service.

## Overview

This PowerShell script deploys the Coralogix OpenTelemetry Collector as a Windows Service. It supports both **regular mode** (local config) and **supervisor mode** (remote config via Fleet Management).

## Prerequisites

- Windows 10/11, Windows Server 2016 or later
- PowerShell 5.1 or later
- Administrator privileges
- Coralogix [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/)

> [!IMPORTANT]
> **Configuration Required**
>
> A configuration file must be provided when installing the collector. Use the example configuration from the [`otel-windows-standalone/build`](https://github.com/coralogix/telemetry-shippers/tree/master/otel-windows-standalone/build) folder. **Make sure to update the `domain` value** in the configuration file to match your [Coralogix domain](https://coralogix.com/docs/coralogix-domain/).

## Quick Start

Run the following command in an elevated PowerShell (Run as Administrator) to download the installer from GitHub and install with your config file:

```powershell
$u='https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'; $f="$env:TEMP\coralogix-otel-collector.ps1"; Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing; $env:CORALOGIX_PRIVATE_KEY='<your-private-key>'; & $f -Config 'C:\path\to\your\config.yaml'
```

Replace `<your-private-key>` with your [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/) and `C:\path\to\your\config.yaml` with the path to your config file. Ensure the config file exists on the machine before running (e.g. create it in Notepad and save as `C:\otel\config.yaml`). **Copy the command as a single line;** the key must be in single quotes with a closing quote before the semicolon (e.g. `'your-key'; & $f`).

> **Note:** On **Windows Server 2016 or older**, prepend `[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; ` to the command so the download from GitHub succeeds (GitHub requires TLS 1.2+).

## Environment Variables

### Required Variables

| Variable              | Required             | Description                                                                                 |
|-----------------------|----------------------|---------------------------------------------------------------------------------------------|
| CORALOGIX_PRIVATE_KEY | Yes                  | Your Coralogix [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/) |
| CORALOGIX_DOMAIN      | Supervisor mode only | Your Coralogix [domain](https://coralogix.com/docs/coralogix-domain/)                       |

### Automatically Set Variables

The installer automatically sets these environment variables for the collector service:

| Variable              | Default   | Description                                                            |
|-----------------------|-----------|------------------------------------------------------------------------|
| OTEL_MEMORY_LIMIT_MIB | 512       | Memory limit in MiB (set via `-MemoryLimit` parameter)                 |
| OTEL_LISTEN_INTERFACE | 127.0.0.1 | Network interface for receivers (set via `-ListenInterface` parameter) |

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

### Windows Versions

- Windows 10 (all editions)
- Windows 11 (all editions)
- Windows Server 2016 and later

### Architectures

- x64 (amd64)
- ARM64

## Install with Custom Configuration

To install with your own configuration file (script is downloaded from GitHub and run from temp):

```powershell
$u='https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'; $f="$env:TEMP\coralogix-otel-collector.ps1"; Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing; $env:CORALOGIX_PRIVATE_KEY='<your-private-key>'; & $f -Config 'C:\path\to\config.yaml'
```

## Install Specific Version

```powershell
$u='https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'; $f="$env:TEMP\coralogix-otel-collector.ps1"; Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing; $env:CORALOGIX_PRIVATE_KEY='<your-private-key>'; & $f -Version 0.144.0
```

## Install with Custom Memory Limit

```powershell
$u='https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'; $f="$env:TEMP\coralogix-otel-collector.ps1"; Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing; $env:CORALOGIX_PRIVATE_KEY='<your-private-key>'; & $f -MemoryLimit 2048
```

> **Note:** Your configuration must reference `${env:OTEL_MEMORY_LIMIT_MIB}` for this to take effect.

## Install as Gateway (Listen on All Interfaces)

By default, the collector listens only on `127.0.0.1`. To accept connections from other hosts (gateway mode):

```powershell
$u='https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'; $f="$env:TEMP\coralogix-otel-collector.ps1"; Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing; $env:CORALOGIX_PRIVATE_KEY='<your-private-key>'; & $f -ListenInterface 0.0.0.0
```

> **Note:** Your configuration must reference `${env:OTEL_LISTEN_INTERFACE}` for this to take effect.

## Dynamic Metadata Parsing (IIS Logs)

Enable dynamic metadata parsing for file-based logs, such as IIS logs with header-based format detection:

```powershell
$u='https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'; $f="$env:TEMP\coralogix-otel-collector.ps1"; Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing; $env:CORALOGIX_PRIVATE_KEY='<your-private-key>'; & $f -EnableDynamicIISParsing
```

This option creates a storage directory at `C:\ProgramData\OpenTelemetry\Collector\storage` and runs the collector with `--feature-gates=filelog.allowHeaderMetadataParsing`. Only available in regular mode, not supervisor mode.

## Supervisor Mode

Supervisor mode enables remote configuration management through Coralogix [Fleet Management](https://coralogix.com/docs/user-guides/fleet-management/overview/).

### Basic Installation

```powershell
$u='https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'; $f="$env:TEMP\coralogix-otel-collector.ps1"; Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing; $env:CORALOGIX_DOMAIN='<your-domain>'; $env:CORALOGIX_PRIVATE_KEY='<your-private-key>'; & $f -Supervisor
```

> **Note:** Supervisor mode requires version **0.144.0 or higher** (Windows MSI is available from this version). If the detected version is lower, the script will automatically use 0.144.0.

### With Specific Versions

```powershell
$u='https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'; $f="$env:TEMP\coralogix-otel-collector.ps1"; Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing; $env:CORALOGIX_DOMAIN='<your-domain>'; $env:CORALOGIX_PRIVATE_KEY='<your-private-key>'; & $f -Supervisor -SupervisorVersion 0.144.0 -CollectorVersion 0.144.0
```

### With Local MSI File

```powershell
$u='https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'; $f="$env:TEMP\coralogix-otel-collector.ps1"; Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing; $env:CORALOGIX_DOMAIN='<your-domain>'; $env:CORALOGIX_PRIVATE_KEY='<your-private-key>'; & $f -Supervisor -SupervisorMsi 'C:\path\to\opampsupervisor.msi'
```

### With Custom Base Collector Config

```powershell
$u='https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'; $f="$env:TEMP\coralogix-otel-collector.ps1"; Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing; $env:CORALOGIX_DOMAIN='<your-domain>'; $env:CORALOGIX_PRIVATE_KEY='<your-private-key>'; & $f -Supervisor -SupervisorCollectorBaseConfig 'C:\path\to\collector.yaml'
```

The base config is merged with remote configuration from Fleet Manager. The config cannot contain the `opamp` extension (the supervisor manages the OpAMP connection).

## Script Parameters

| Parameter                               | Description                                                      |
|-----------------------------------------|------------------------------------------------------------------|
| `-Version <version>`                    | Install specific collector version                               |
| `-Config <path>`                        | Path to custom configuration file                                |
| `-MemoryLimit <MiB>`                    | Total memory in MiB to allocate (default: 512)                   |
| `-ListenInterface <ip>`                 | Network interface for receivers (default: 127.0.0.1)             |
| `-Supervisor`                           | Install with OpAMP Supervisor mode                               |
| `-SupervisorVersion <version>`          | Supervisor version (supervisor mode only)                        |
| `-CollectorVersion <version>`           | Collector version (supervisor mode only)                         |
| `-SupervisorMsi <path>`                 | Path to local OpAMP Supervisor MSI file                          |
| `-SupervisorCollectorBaseConfig <path>` | Path to base collector config for supervisor mode                |
| `-SupervisorOpampConfig <path>`         | Path to custom OpAMP supervisor config file                      |
| `-EnableDynamicIISParsing`              | Enable dynamic IIS log parsing with header-based field detection |
| `-Uninstall`                            | Remove the collector (keeps config)                              |
| `-Uninstall -Purge`                     | Remove the collector and all configuration                       |
| `-Help`                                 | Show help message                                                |

## Installation Locations

### Regular Mode

| Component     | Location                                                       |
|---------------|----------------------------------------------------------------|
| Binary        | `C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe` |
| Configuration | `C:\ProgramData\OpenTelemetry\Collector\config.yaml`           |
| Service       | `otelcol-contrib` (Windows Service)                            |
| Logs          | Windows Event Log (Application)                                |

### Supervisor Mode

| Component         | Location                                                              |
|-------------------|-----------------------------------------------------------------------|
| Collector Binary  | `C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe`        |
| Supervisor Binary | `C:\Program Files\OpenTelemetry OpAMP Supervisor\opampsupervisor.exe` |
| Supervisor Config | `C:\Program Files\OpenTelemetry OpAMP Supervisor\config.yaml`         |
| Collector Config  | `C:\Program Files\OpenTelemetry OpAMP Supervisor\collector.yaml`      |
| Effective Config  | `C:\ProgramData\opampsupervisor\state\effective.yaml`                 |
| Service           | `opampsupervisor` (Windows Service)                                   |
| Logs              | Windows Event Log (Application) - Source: `opampsupervisor`           |

## Service Management

### Regular Mode

```powershell
# Check status
Get-Service otelcol-contrib

# View logs (Event Log)
Get-EventLog -LogName Application -Source otelcol-contrib -Newest 50

# Restart / Stop / Start
Restart-Service otelcol-contrib
Stop-Service otelcol-contrib
Start-Service otelcol-contrib

# Validate config
& "C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe" validate --config "C:\ProgramData\OpenTelemetry\Collector\config.yaml"
```

### Supervisor Mode

```powershell
# Check status
Get-Service opampsupervisor

# View logs
Get-EventLog -LogName Application -Source opampsupervisor -Newest 50 | Format-List

# Restart / Stop / Start
Restart-Service opampsupervisor
Stop-Service opampsupervisor
Start-Service opampsupervisor

# Check collector process (managed by supervisor)
Get-Process otelcol-contrib -ErrorAction SilentlyContinue
```

### Viewing Configuration Files (Supervisor Mode)

```powershell
# View effective config (actual config after merge with Fleet Management)
Get-Content "C:\ProgramData\opampsupervisor\state\effective.yaml"
```

## Uninstall

Remove the collector while keeping configuration and logs (script is downloaded from GitHub and run):

```powershell
$u='https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'; $f="$env:TEMP\coralogix-otel-collector.ps1"; Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing; & $f -Uninstall
```

Remove the collector and all data:

```powershell
$u='https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'; $f="$env:TEMP\coralogix-otel-collector.ps1"; Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing; & $f -Uninstall -Purge
```

> **Note:** For regular mode, uninstall uses the Windows MSI uninstaller. You can also uninstall manually via **Windows Settings > Apps > "OpenTelemetry Collector"**.

## Configuration Behavior

| Scenario        | Action                            |
|-----------------|-----------------------------------|
| Fresh install   | Creates default empty config      |
| Config exists   | Preserves existing config         |
| With `-Config`  | Uses provided config              |
| Auto-upgrade    | Preserves existing config         |
| Supervisor mode | Config managed remotely via OpAMP |

## Troubleshooting

### Service Fails to Start

If the installer reports that the service failed to start, it will print recent errors from the Application Event Log. You can also run:

```powershell
Get-EventLog -LogName Application -Source otelcol-contrib -Newest 20
```

Common causes:

- **IIS receiver in config but IIS not installed:** Remove the `iis` receiver (and its use in pipelines) from your config if the machine does not have the IIS role, or install the Web Server (IIS) role.
- **Invalid config:** Run: `& "C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe" validate --config "C:\ProgramData\OpenTelemetry\Collector\config.yaml"`
- **Missing env var:** Ensure `CORALOGIX_PRIVATE_KEY` is set for the service (the installer sets it; if you reconfigure manually, set it in the service’s environment).

### Script Execution Policy

If you get execution policy errors:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Or run with bypass:

```powershell
powershell -ExecutionPolicy Bypass -Command { $u='https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'; $f="$env:TEMP\coralogix-otel-collector.ps1"; Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing; $env:CORALOGIX_PRIVATE_KEY='<your-private-key>'; & $f -Config 'C:\otel\config.yaml' }
```

### Administrator Privileges

The script requires administrator privileges. Right-click PowerShell and choose **Run as Administrator**, then run the install command again.

## Additional Resources

| Resource                    | Link                                                                                             |
|-----------------------------|--------------------------------------------------------------------------------------------------|
| GitHub Repository           | [telemetry-shippers](https://github.com/coralogix/telemetry-shippers/tree/master/otel-installer) |
| OpenTelemetry Documentation | [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)                              |

## Support

**Need help?**

Our world-class customer success team is available 24/7 to walk you through your setup and answer any questions that may come up.

Feel free to reach out to us **via our in-app chat** or by sending us an email at [support@coralogix.com](mailto:support@coralogix.com).
