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
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"; .\coralogix-otel-collector.ps1
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
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"; .\coralogix-otel-collector.ps1 -Config C:\path\to\config.yaml
```

## Install Specific Version

```powershell
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"; .\coralogix-otel-collector.ps1 -Version 0.140.1
```

## Dynamic Metadata Parsing (IIS Logs)

Enable dynamic metadata parsing for file-based logs, such as IIS logs with header-based format detection:

```powershell
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"; .\coralogix-otel-collector.ps1 -EnableDynamicMetadataParsing
```

This option:
- Creates a storage directory at `C:\ProgramData\OpenTelemetry\Collector\storage`
- Runs the collector with `--feature-gates=filelog.allowHeaderMetadataParsing`

> **Note:** This feature is only available in regular mode, not supervisor mode.

## Supervisor Mode

Supervisor mode enables remote configuration management through Coralogix Fleet Management:

```powershell
$env:CORALOGIX_DOMAIN="<your-domain>"; $env:CORALOGIX_PRIVATE_KEY="<your-private-key>"; .\coralogix-otel-collector.ps1 -Supervisor
```

> **Note:** Supervisor mode requires version 0.144.0 or higher because the Windows MSI installer is only available from this version onwards. If the detected version is lower, the script will automatically use 0.144.0. Use `-SupervisorVersion` and `-CollectorVersion` to override, or `-SupervisorMsi` to provide a local MSI file.

Install with supervisor using specific versions:

```powershell
$env:CORALOGIX_DOMAIN="<your-domain>"; $env:CORALOGIX_PRIVATE_KEY="<your-private-key>"; .\coralogix-otel-collector.ps1 -Supervisor -SupervisorVersion 0.140.1 -CollectorVersion 0.140.0
```

Install with supervisor using a local MSI file:

```powershell
$env:CORALOGIX_DOMAIN="<your-domain>"; $env:CORALOGIX_PRIVATE_KEY="<your-private-key>"; .\coralogix-otel-collector.ps1 -Supervisor -SupervisorMsi C:\path\to\opampsupervisor.msi
```

Install with supervisor and a custom base collector config:

```powershell
$env:CORALOGIX_DOMAIN="<your-domain>"; $env:CORALOGIX_PRIVATE_KEY="<your-private-key>"; .\coralogix-otel-collector.ps1 -Supervisor -SupervisorBaseConfig C:\path\to\collector.yaml
```

The base config is merged with remote configuration from Fleet Manager. Note: The config cannot contain the `opamp` extension as the supervisor manages the OpAMP connection.

## Script Parameters

| Parameter | Description |
| --- | --- |
| `-Version <version>` | Install specific collector version |
| `-Config <path>` | Path to custom configuration file |
| `-Supervisor` | Install with OpAMP Supervisor mode |
| `-SupervisorVersion <version>` | Supervisor version (supervisor mode only) |
| `-CollectorVersion <version>` | Collector version (supervisor mode only) |
| `-SupervisorMsi <path>` | Path to local OpAMP Supervisor MSI file |
| `-SupervisorBaseConfig <path>` | Path to base collector config for supervisor mode |
| `-EnableDynamicMetadataParsing` | Enable dynamic metadata parsing for file logs (e.g., IIS) |
| `-Uninstall` | Remove the collector (keeps config) |
| `-Uninstall -Purge` | Remove the collector and all configuration |
| `-Help` | Show help message |

## Installation Locations

### Regular Mode

| Component | Location |
| --- | --- |
| Binary | `C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe` |
| Configuration | `C:\ProgramData\OpenTelemetry\Collector\config.yaml` |
| Service | `otelcol-contrib` (Windows Service) |
| Logs | Windows Event Log (Application) |

### Supervisor Mode

| Component | Location |
| --- | --- |
| Collector Binary | `C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe` |
| Supervisor Binary | `C:\Program Files\OpenTelemetry OpAMP Supervisor\opampsupervisor.exe` |
| Supervisor Config | `C:\Program Files\OpenTelemetry OpAMP Supervisor\config.yaml` |
| Collector Config | `C:\Program Files\OpenTelemetry OpAMP Supervisor\collector.yaml` |
| Effective Config | `C:\ProgramData\opampsupervisor\state\effective.yaml` |
| Service | `opampsupervisor` (Windows Service) |
| Logs | Windows Event Log (Application) - Source: `opampsupervisor` |

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
& "C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe" validate --config "C:\ProgramData\OpenTelemetry\Collector\config.yaml"
```

### Supervisor Mode

```powershell
# Check status
Get-Service opampsupervisor

# View logs
Get-EventLog -LogName Application -Source opampsupervisor -Newest 50 | Format-List

# Restart
Restart-Service opampsupervisor

# Stop
Stop-Service opampsupervisor

# Start
Start-Service opampsupervisor

# Check collector process (managed by supervisor)
Get-Process otelcol-contrib -ErrorAction SilentlyContinue
```

### Viewing Configuration Files (Supervisor Mode)

```powershell
# View supervisor config
Get-Content "C:\Program Files\OpenTelemetry OpAMP Supervisor\config.yaml"

# View base collector config (merged with remote config)
Get-Content "C:\Program Files\OpenTelemetry OpAMP Supervisor\collector.yaml"

# View effective config (actual config after merge with Fleet Management)
Get-Content "C:\ProgramData\opampsupervisor\state\effective.yaml"
```

> **Note:** The `effective.yaml` contains the final merged configuration that the collector is actually using. This file is generated by the supervisor after merging the base config with remote configuration from Fleet Management.

## Uninstall

Remove the collector while keeping configuration and logs:

```powershell
.\coralogix-otel-collector.ps1 -Uninstall
```

Remove the collector and all data:

```powershell
.\coralogix-otel-collector.ps1 -Uninstall -Purge
```

**Note:** For regular mode, the uninstall uses the Windows MSI uninstaller to properly remove the collector. This ensures all MSI-installed components are cleanly removed. You can also uninstall manually via Windows Settings > Apps > "OpenTelemetry Collector".

## Configuration Behavior

| Scenario | Action |
| --- | --- |
| Fresh install | Creates default empty config |
| Config exists | Preserves existing config |
| With `-Config` | Uses provided config |
| Auto-upgrade | Preserves existing config |
| Supervisor mode | Config managed remotely via OpAMP |

## Troubleshooting

### Service fails to start

If you get "Cannot start service otelcol-contrib", follow these steps:

1. **Check service status and configuration:**
   ```powershell
   Get-Service otelcol-contrib
   Get-CimInstance Win32_Service -Filter "Name='otelcol-contrib'" | Select-Object Name, State, StartMode, PathName
   ```

2. **Check Windows Event Log for detailed errors:**
   ```powershell
   # Check System Event Log for service errors
   Get-EventLog -LogName System -Source "Service Control Manager" -Newest 20 | Where-Object {$_.Message -like "*otelcol*"}
   
   # Check Application Event Log
   Get-EventLog -LogName Application -Newest 50 | Where-Object {$_.Source -like "*otel*" -or $_.Message -like "*otel*"}
   ```

3. **Verify all required files exist:**
   ```powershell
   # Check binary (MSI install location)
   Test-Path "C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe"
   
   # Check config
   Test-Path "C:\ProgramData\OpenTelemetry\Collector\config.yaml"
   ```

4. **Validate the configuration file:**
   ```powershell
   & "C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe" validate --config "C:\ProgramData\OpenTelemetry\Collector\config.yaml"
   ```

5. **Test running the collector manually (run as Administrator):**
   ```powershell
   # Set environment variable and run collector manually
   $env:CORALOGIX_PRIVATE_KEY="<your-key>"
   & "C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe" --config "C:\ProgramData\OpenTelemetry\Collector\config.yaml"
   ```

6. **Check service binary path:**
   ```powershell
   # View the exact command the service is trying to run
   $service = Get-CimInstance Win32_Service -Filter "Name='otelcol-contrib'"
   $service.PathName
   ```

7. **Check if registry environment variables are set:**
   ```powershell
   Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\otelcol-contrib\Environment" -ErrorAction SilentlyContinue
   ```

8. **If all else fails, recreate the service:**
   ```powershell
   # Stop and remove the service
   Stop-Service otelcol-contrib -ErrorAction SilentlyContinue
   & sc.exe delete otelcol-contrib
   
   # Reinstall (will auto-detect and upgrade)
   $env:CORALOGIX_PRIVATE_KEY="<your-key>"; .\coralogix-otel-collector.ps1
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
$env:CORALOGIX_DOMAIN="<your-domain>"; $env:CORALOGIX_PRIVATE_KEY="<your-private-key>"; .\coralogix-otel-collector.ps1 -Supervisor
```

### Process not found

If `Get-Process otelcol-contrib` returns "Cannot find a process":

1. **Check if the service is running:**
   ```powershell
   Get-Service otelcol-contrib
   # or for supervisor mode:
   Get-Service opampsupervisor
   ```

2. **If service is stopped, check why it failed:**
   ```powershell
   # For regular mode - check Event Log
   Get-EventLog -LogName Application -Source otelcol-contrib -Newest 20
   
   # For supervisor mode - check log file
   Get-EventLog -LogName Application -Source opampsupervisor -Newest 50 | Format-List
   ```

3. **Try starting the service manually:**
   ```powershell
   Start-Service otelcol-contrib
   # Check status again
   Get-Service otelcol-contrib
   ```

4. **Check if the binary exists:**
   ```powershell
   Test-Path "C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe"
   ```

5. **Try finding the process with different methods:**
   ```powershell
   # Search for any process with "otel" in the name
   Get-Process | Where-Object {$_.ProcessName -like "*otel*"}
   
   # Or search by executable path
   Get-Process | Where-Object {$_.Path -like "*OpenTelemetry*"}
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

