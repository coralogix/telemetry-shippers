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

## Supported Platforms

### Windows Versions

- Windows 10 (all editions)
- Windows 11 (all editions)
- Windows Server 2016 and later

### Architectures

- x64 (amd64)
- ARM64

---

## Installation Options

### Install with Custom Configuration

```powershell
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -Config C:\path\to\config.yaml
```

### Install Specific Version

```powershell
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -Version 0.144.0
```

### Install with Custom Memory Limit

```powershell
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -MemoryLimit 2048
```

### Install with External Network Access (Gateway Mode)

```powershell
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -ListenInterface 0.0.0.0
```

---

## Dynamic Metadata Parsing (IIS Logs)

Enable dynamic metadata parsing for file-based logs, such as IIS logs with header-based format detection:

```powershell
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -EnableDynamicIISParsing
```

This option:

- Creates a storage directory at `C:\ProgramData\OpenTelemetry\Collector\storage`
- Runs the collector with `--feature-gates=filelog.allowHeaderMetadataParsing`

> **Note:** This feature is only available in regular mode, not supervisor mode.

---

## Supervisor Mode

Supervisor mode enables remote configuration management through Coralogix Fleet Management.

### Basic Installation

```powershell
$env:CORALOGIX_DOMAIN="<your-domain>"
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -Supervisor
```

> **Note:** Supervisor mode requires version **0.144.0 or higher** because the Windows MSI installer is only available from this version onwards. If the detected version is lower, the script will automatically use 0.144.0.

### With Specific Versions

```powershell
$env:CORALOGIX_DOMAIN="<your-domain>"
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -Supervisor -SupervisorVersion 0.144.0 -CollectorVersion 0.144.0
```

### With Local MSI File

```powershell
$env:CORALOGIX_DOMAIN="<your-domain>"
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -Supervisor -SupervisorMsi C:\path\to\opampsupervisor.msi
```

### With Custom Base Collector Config

```powershell
$env:CORALOGIX_DOMAIN="<your-domain>"
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -Supervisor -SupervisorCollectorBaseConfig C:\path\to\collector.yaml
```

The base config is merged with remote configuration from Fleet Manager.

> **Note:** The config cannot contain the `opamp` extension as the supervisor manages the OpAMP connection.

---

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

---

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

---

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
# View supervisor config
Get-Content "C:\Program Files\OpenTelemetry OpAMP Supervisor\config.yaml"

# View base collector config (merged with remote config)
Get-Content "C:\Program Files\OpenTelemetry OpAMP Supervisor\collector.yaml"

# View effective config (actual config after merge with Fleet Management)
Get-Content "C:\ProgramData\opampsupervisor\state\effective.yaml"
```

> **Note:** The `effective.yaml` contains the final merged configuration that the collector is actually using. This file is generated by the supervisor after merging the base config with remote configuration from Fleet Management.

---

## Uninstall

Remove the collector while keeping configuration and logs:

```powershell
.\coralogix-otel-collector.ps1 -Uninstall
```

Remove the collector and all data:

```powershell
.\coralogix-otel-collector.ps1 -Uninstall -Purge
```

> **Note:** For regular mode, the uninstall uses the Windows MSI uninstaller to properly remove the collector. You can also uninstall manually via **Windows Settings > Apps > "OpenTelemetry Collector"**.

---

## Configuration Behavior

| Scenario        | Action                            |
|-----------------|-----------------------------------|
| Fresh install   | Creates default empty config      |
| Config exists   | Preserves existing config         |
| With `-Config`  | Uses provided config              |
| Auto-upgrade    | Preserves existing config         |
| Supervisor mode | Config managed remotely via OpAMP |

---

## Troubleshooting

### Service Fails to Start

If you get "Cannot start service otelcol-contrib":

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
   Test-Path "C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe"
   Test-Path "C:\ProgramData\OpenTelemetry\Collector\config.yaml"
   ```

4. **Validate the configuration file:**

   ```powershell
   & "C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe" validate --config "C:\ProgramData\OpenTelemetry\Collector\config.yaml"
   ```

5. **Test running the collector manually (run as Administrator):**

   ```powershell
   $env:CORALOGIX_PRIVATE_KEY="<your-key>"
   & "C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe" --config "C:\ProgramData\OpenTelemetry\Collector\config.yaml"
   ```

6. **If all else fails, recreate the service:**

   ```powershell
   Stop-Service otelcol-contrib -ErrorAction SilentlyContinue
   & sc.exe delete otelcol-contrib

   # Reinstall (will auto-detect and upgrade)
   $env:CORALOGIX_PRIVATE_KEY="<your-key>"
   .\coralogix-otel-collector.ps1
   ```

### SSL/TLS Connection Error (Windows Server 2016 and older)

If you encounter "The request was aborted: Could not create SSL/TLS secure channel" when running the installation script, your system may be defaulting to TLS 1.0. GitHub requires TLS 1.2.

**Optional fix for affected versions:** On Windows Server 2016, Windows Server 2012 R2, or older Windows 10, use this one-liner instead—it enables TLS 1.2 before downloading:

```powershell
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'))
```

### Script Execution Policy

If you encounter execution policy errors:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Or run the script with bypass:

```powershell
powershell -ExecutionPolicy Bypass -File .\coralogix-otel-collector.ps1
```

### Switching Between Modes

Uninstall before switching between regular and supervisor modes:

```powershell
.\coralogix-otel-collector.ps1 -Uninstall -Purge

$env:CORALOGIX_DOMAIN="<your-domain>"
$env:CORALOGIX_PRIVATE_KEY="<your-private-key>"
.\coralogix-otel-collector.ps1 -Supervisor
```

### Process Not Found

If `Get-Process otelcol-contrib` returns "Cannot find a process":

1. **Check if the service is running:**

   ```powershell
   Get-Service otelcol-contrib
   # or for supervisor mode:
   Get-Service opampsupervisor
   ```

2. **Check why it failed:**

   ```powershell
   # For regular mode
   Get-EventLog -LogName Application -Source otelcol-contrib -Newest 20

   # For supervisor mode
   Get-EventLog -LogName Application -Source opampsupervisor -Newest 50 | Format-List
   ```

3. **Try starting the service manually:**

   ```powershell
   Start-Service otelcol-contrib
   Get-Service otelcol-contrib
   ```

### Administrator Privileges

The script requires administrator privileges. If you see permission errors:

1. Right-click PowerShell
2. Select **"Run as Administrator"**
3. Run the script again

---

## Additional Resources

| Resource                    | Link                                                                                             |
|-----------------------------|--------------------------------------------------------------------------------------------------|
| GitHub Repository           | [telemetry-shippers](https://github.com/coralogix/telemetry-shippers/tree/master/otel-installer) |
| OpenTelemetry Documentation | [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)                              |

---

## Support

**Need help?**

Our world-class customer success team is available 24/7 to walk you through your setup and answer any questions that may come up.

Feel free to reach out to us **via our in-app chat** or by sending us an email at [support@coralogix.com](mailto:support@coralogix.com).
