#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Coralogix OpenTelemetry Collector Installer for Windows
    
.DESCRIPTION
    Installs the OpenTelemetry Collector as a Windows Service on Windows systems.
    Supports regular mode (local config) and supervisor mode (remote config via Fleet Management).
    
.PARAMETER Version
    OTEL Collector version to install (default: latest from Coralogix Helm chart)
    
.PARAMETER Config
    Path to custom configuration file (not available with Supervisor mode)
    
.PARAMETER Supervisor
    Install with OpAMP Supervisor mode (config is managed by the OpAMP server)
    
.PARAMETER SupervisorVersion
    Supervisor version (supervisor mode only, default: same as Version)
    
.PARAMETER CollectorVersion
    Collector version (supervisor mode only, default: same as Version)

.PARAMETER SupervisorMsi
    Path to a local OpAMP Supervisor MSI file (supervisor mode only)
    When provided, uses the local MSI instead of downloading from GitHub releases

.PARAMETER SupervisorBaseConfig
    Path to a base collector configuration file for supervisor mode.
    This config is merged with remote configuration from Fleet Manager.
    Cannot contain 'opamp' extension (supervisor manages OpAMP connection).
    (supervisor mode only)

.PARAMETER MemoryLimit
    Total memory in MiB to allocate to the collector (default: 512)
    Config must reference: ${env:OTEL_MEMORY_LIMIT_MIB}
    (ignored in supervisor mode)

.PARAMETER ListenInterface
    Network interface for receivers to listen on (default: 127.0.0.1)
    Config must reference: ${env:OTEL_LISTEN_INTERFACE}
    Use 0.0.0.0 to listen on all interfaces (gateway mode)
    (ignored in supervisor mode)

.PARAMETER EnableDynamicMetadataParsing
    Enable dynamic metadata parsing for file-based logs (e.g., IIS logs)
    Creates storage directory and adds --feature-gates=filelog.allowHeaderMetadataParsing
    (regular mode only, not available with Supervisor)
    
.PARAMETER Uninstall
    Uninstall the collector (use Purge to remove all data)
    
.PARAMETER Purge
    Remove all data when uninstalling (must be used with Uninstall)
    
.PARAMETER Help
    Show help message
    
.EXAMPLE
    # One-line installation (recommended)
    $env:CORALOGIX_PRIVATE_KEY="your-key"; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'))
    
.EXAMPLE
    # Install specific version
    $env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -Version 0.140.1
    
.EXAMPLE
    # Install with custom config
    $env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -Config C:\path\to\config.yaml
    
.EXAMPLE
    # Install with supervisor
    $env:CORALOGIX_DOMAIN="your-domain"; $env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -Supervisor

.EXAMPLE
    # Install with supervisor using local MSI
    $env:CORALOGIX_DOMAIN="your-domain"; $env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -Supervisor -SupervisorMsi C:\path\to\opampsupervisor.msi

.EXAMPLE
    # Install with supervisor and custom base config
    $env:CORALOGIX_DOMAIN="your-domain"; $env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -Supervisor -SupervisorBaseConfig C:\path\to\collector.yaml
    
.EXAMPLE
    # Install with custom memory limit
    $env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -MemoryLimit 2048

.EXAMPLE
    # Install with external network access (gateway mode - listen on all interfaces)
    $env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -ListenInterface 0.0.0.0

.EXAMPLE
    # Install with custom memory limit and external access
    $env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -MemoryLimit 2048 -ListenInterface 0.0.0.0

.EXAMPLE
    # Install with dynamic metadata parsing for IIS logs
    $env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -EnableDynamicMetadataParsing

.EXAMPLE
    # Uninstall (keep config/logs)
    .\coralogix-otel-collector.ps1 -Uninstall
    
.EXAMPLE
    # Uninstall and remove all data
    .\coralogix-otel-collector.ps1 -Uninstall -Purge
    
.NOTES
    Environment Variables:
    - CORALOGIX_PRIVATE_KEY: Coralogix private key (required)
    - CORALOGIX_DOMAIN: Coralogix domain (required for supervisor mode)
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias("v")]
    [string]$Version = "",
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias("c")]
    [string]$Config = "",
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias("s")]
    [switch]$Supervisor = $false,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SupervisorVersion = "",
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$CollectorVersion = "",
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SupervisorMsi = "",
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SupervisorBaseConfig = "",
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [int]$MemoryLimit = 512,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$ListenInterface = "127.0.0.1",
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [switch]$EnableDynamicMetadataParsing = $false,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [switch]$Uninstall = $false,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [switch]$Purge = $false,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias("h")]
    [switch]$Help = $false
)

# TLS 1.2 enforcement - must be FIRST before any network operations
# Windows Server 2016 (build 14393) and older may default to TLS 1.0/1.1
# which modern services like GitHub reject
if ([System.Environment]::OSVersion.Version.Build -lt 17763) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# Script constants
$SERVICE_NAME = "otelcol-contrib"
$SUPERVISOR_SERVICE_NAME = "opampsupervisor"
$BINARY_NAME = "otelcol-contrib.exe"
# Minimum version for supervisor mode (MSI only available from this version onwards)
$SUPERVISOR_MIN_VERSION = "0.144.0"
# MSI installs to "OpenTelemetry Collector" folder
$INSTALL_DIR = "${env:ProgramFiles}\OpenTelemetry Collector"
$BINARY_PATH = Join-Path $INSTALL_DIR $BINARY_NAME
$CONFIG_DIR = "${env:ProgramData}\OpenTelemetry\Collector"
$CONFIG_FILE = Join-Path $CONFIG_DIR "config.yaml"
$LOG_DIR = "${env:ProgramData}\OpenTelemetry\Collector\logs"
# Supervisor paths - must match official MSI installer paths
# See: https://github.com/open-telemetry/opentelemetry-collector-releases/blob/main/cmd/opampsupervisor/windows-installer.wxs
$SUPERVISOR_INSTALL_DIR = "${env:ProgramFiles}\OpenTelemetry OpAMP Supervisor"
$SUPERVISOR_BINARY_NAME = "opampsupervisor.exe"
$SUPERVISOR_BINARY_PATH = Join-Path $SUPERVISOR_INSTALL_DIR $SUPERVISOR_BINARY_NAME
$SUPERVISOR_CONFIG_FILE = Join-Path $SUPERVISOR_INSTALL_DIR "config.yaml"
$SUPERVISOR_COLLECTOR_CONFIG_FILE = Join-Path $SUPERVISOR_INSTALL_DIR "collector.yaml"
$SUPERVISOR_DATA_DIR = "${env:ProgramData}\opampsupervisor"
$SUPERVISOR_STATE_DIR = Join-Path $SUPERVISOR_DATA_DIR "state"
$SUPERVISOR_LOG_DIR = Join-Path $SUPERVISOR_DATA_DIR "logs"
$CHART_YAML_URL = "https://raw.githubusercontent.com/coralogix/opentelemetry-helm-charts/refs/heads/main/charts/opentelemetry-collector/Chart.yaml"
$OTEL_RELEASES_BASE_URL = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases"
$OTEL_COLLECTOR_CHECKSUMS_FILE = "opentelemetry-collector-releases_otelcol-contrib_checksums.txt"
$OTEL_SUPERVISOR_CHECKSUMS_FILE = "checksums.txt"
$OTEL_SUPERVISOR_MSI_CHECKSUMS_FILE = "checksums.txt"

# Global variables
$script:UserSetMemoryLimit = $false
$script:UserSetListenInterface = $false

# Functions
function Write-Log {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit 1
}

function Show-Usage {
    $usage = @"
Coralogix OpenTelemetry Collector Installer for Windows

Usage:
    .\coralogix-otel-collector.ps1 [OPTIONS]

Options:
    -Version <version>              OTEL Collector version to install
                                    (default: latest from Coralogix Helm chart)
    -Config <path>                  Path to custom configuration file
                                    (not available with -Supervisor)
    -Supervisor                     Install with OpAMP Supervisor mode
                                    (config is managed by the OpAMP server)
    -SupervisorVersion <ver>        Supervisor version (supervisor mode only)
                                    (default: same as -Version)
    -CollectorVersion <ver>         Collector version (supervisor mode only)
                                    (default: same as -Version)
    -SupervisorMsi <path>           Path to local OpAMP Supervisor MSI file
                                    (supervisor mode only)
    -SupervisorBaseConfig <path>    Path to base collector config for supervisor mode
                                    Merged with remote config from Fleet Manager
                                    (supervisor mode only)
    -MemoryLimit <MiB>              Total memory in MiB to allocate to the collector
                                    Sets OTEL_MEMORY_LIMIT_MIB environment variable
                                    Config must reference: `${env:OTEL_MEMORY_LIMIT_MIB}
                                    (default: 512, ignored in supervisor mode)
    -ListenInterface <ip>           Network interface for receivers to listen on
                                    Sets OTEL_LISTEN_INTERFACE environment variable
                                    Config must reference: `${env:OTEL_LISTEN_INTERFACE}
                                    (default: 127.0.0.1 for localhost only,
                                     use 0.0.0.0 for all interfaces)
                                    (ignored in supervisor mode)
    -EnableDynamicMetadataParsing   Enable dynamic metadata parsing for file logs
                                    (e.g., IIS logs with header-based format detection)
                                    Creates storage directory and enables feature gate
                                    (regular mode only)
    -Uninstall                      Uninstall the collector
                                    (use -Purge to remove all data)
    -Purge                          Remove all data when uninstalling
                                    (must be used with -Uninstall)
    -Help                           Show this help message

Environment Variables:
    CORALOGIX_PRIVATE_KEY   Coralogix private key (required)
    CORALOGIX_DOMAIN        Coralogix domain (required for supervisor mode)

Examples:
    # One-line installation (recommended)
    `$env:CORALOGIX_PRIVATE_KEY="your-key"; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/windows/coralogix-otel-collector.ps1'))

    # Install specific version
    `$env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -Version 0.140.1

    # Install with custom config
    `$env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -Config C:\path\to\config.yaml

    # Install with supervisor
    `$env:CORALOGIX_DOMAIN="your-domain"; `$env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -Supervisor

    # Install with supervisor using specific versions
    `$env:CORALOGIX_DOMAIN="your-domain"; `$env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -Supervisor -SupervisorVersion 0.140.1 -CollectorVersion 0.140.0

    # Install with supervisor using local MSI
    `$env:CORALOGIX_DOMAIN="your-domain"; `$env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -Supervisor -SupervisorMsi C:\path\to\opampsupervisor.msi

    # Install with supervisor and custom base config
    `$env:CORALOGIX_DOMAIN="your-domain"; `$env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -Supervisor -SupervisorBaseConfig C:\path\to\collector.yaml

    # Install with custom memory limit
    `$env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -MemoryLimit 2048

    # Install with external network access (gateway mode - listen on all interfaces)
    `$env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -ListenInterface 0.0.0.0

    # Install with custom memory limit and external access
    `$env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -MemoryLimit 2048 -ListenInterface 0.0.0.0

    # Install with dynamic metadata parsing for IIS logs
    `$env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -EnableDynamicMetadataParsing

    # Uninstall (keep config/logs)
    .\coralogix-otel-collector.ps1 -Uninstall

    # Uninstall and remove all data
    .\coralogix-otel-collector.ps1 -Uninstall -Purge
"@
    Write-Host $usage
}

function Test-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "This script requires administrator privileges. Please run PowerShell as Administrator."
    }
}

function Test-ConfigEnvVars {
    param([string]$ConfigPath)
    
    if ($Supervisor) {
        if ($script:UserSetMemoryLimit -or $script:UserSetListenInterface) {
            Write-Warn "Note: -MemoryLimit and -ListenInterface values are passed as environment variables"
            Write-Warn "but their effect depends on whether the remote Fleet Management config references them"
            Write-Warn "(e.g., `${env:OTEL_MEMORY_LIMIT_MIB} and `${env:OTEL_LISTEN_INTERFACE})"
        }
        return
    }
    
    if (-not (Test-Path $ConfigPath)) {
        return
    }
    
    $configContent = Get-Content $ConfigPath -Raw -ErrorAction SilentlyContinue
    if (-not $configContent) {
        return
    }
    
    if ($script:UserSetMemoryLimit) {
        if ($configContent -notmatch "OTEL_MEMORY_LIMIT_MIB") {
            Write-Warn "You specified -MemoryLimit but the config doesn't reference `${env:OTEL_MEMORY_LIMIT_MIB}"
            Write-Warn "The -MemoryLimit flag will have no effect."
            Write-Warn "Update your config to use: limit_mib: `${env:OTEL_MEMORY_LIMIT_MIB}"
        }
    }
    
    if ($script:UserSetListenInterface) {
        if ($configContent -notmatch "OTEL_LISTEN_INTERFACE") {
            Write-Warn "You specified -ListenInterface but the config doesn't reference `${env:OTEL_LISTEN_INTERFACE}"
            Write-Warn "The -ListenInterface flag will have no effect."
            Write-Warn "Update your config to use: endpoint: `${env:OTEL_LISTEN_INTERFACE}:<port>"
        }
    }
}

function Get-DefaultVersion {
    try {
        $chartYaml = Invoke-WebRequest -Uri $CHART_YAML_URL -UseBasicParsing -ErrorAction Stop
        $content = $chartYaml.Content
        
        # Split content into lines for better parsing (handle both Windows and Unix line endings)
        $lines = $content -split "[\r\n]+"
        
        foreach ($line in $lines) {
            # Look for appVersion line (case-insensitive, with or without quotes)
            # Pattern matches: "appVersion: 0.141.0" or "appVersion: '0.141.0'" or "  appVersion: 0.141.0"
            if ($line -match '^\s*appVersion\s*:\s*(.+)') {
                $version = $matches[1].Trim()
                # Remove surrounding quotes (single or double) and any whitespace
                $version = $version -replace '^["'']|["'']$', '' -replace '\s', ''
                
                # Validate version format (e.g., 0.141.0)
                if ($version -match '^\d+\.\d+\.\d+') {
                    Write-Log "Found version in Chart.yaml: $version"
                    return $version
                }
            }
        }
    }
    catch {
        Write-Warn "Unable to fetch Chart.yaml from $CHART_YAML_URL"
        Write-Host ""
        Write-Host "This may be due to network connectivity issues or GitHub being unavailable."
        Write-Host ""
        Write-Host "To proceed, please specify the version manually using the -Version parameter:"
        Write-Host "  .\coralogix-otel-collector.ps1 -Version 0.XXX.X"
        Write-Host ""
        Write-Host "You can find the latest version at appVersion field in the Chart.yaml file:"
        Write-Host "  https://raw.githubusercontent.com/coralogix/opentelemetry-helm-charts/refs/heads/main/charts/opentelemetry-collector/Chart.yaml"
        Write-Host ""
        return $null
    }
    
    Write-Warn "Unable to extract appVersion from Chart.yaml"
    Write-Host ""
    Write-Host "Please specify the version manually using the -Version parameter:"
    Write-Host "  .\coralogix-otel-collector.ps1 -Version 0.XXX.X"
    Write-Host ""
    Write-Host "You can find the latest version at appVersion field in the Chart.yaml file:"
    Write-Host "  https://raw.githubusercontent.com/coralogix/opentelemetry-helm-charts/refs/heads/main/charts/opentelemetry-collector/Chart.yaml"
    Write-Host ""
    return $null
}

function Test-Version {
    param([string]$Version)
    
    $releaseUrl = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/tag/v$Version"
    try {
        $response = Invoke-WebRequest -Uri $releaseUrl -UseBasicParsing -Method Head -ErrorAction Stop
        return $true
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-Warn "Version v$Version not found in OpenTelemetry Collector releases"
            Write-Host ""
            Write-Host "Please verify the version exists at:"
            Write-Host "  $releaseUrl"
            Write-Host ""
            Write-Host "You can find available versions at:"
            Write-Host "  https://github.com/open-telemetry/opentelemetry-collector-releases/releases"
            Write-Host ""
            return $false
        }
        return $false
    }
}

function Test-SupervisorVersion {
    param([string]$Version)
    
    # Supervisor uses a different release path: cmd/opampsupervisor/v{version}
    $releaseUrl = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/tag/cmd%2Fopampsupervisor%2Fv$Version"
    try {
        $response = Invoke-WebRequest -Uri $releaseUrl -UseBasicParsing -Method Head -ErrorAction Stop
        return $true
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-Warn "Supervisor version v$Version not found in OpenTelemetry releases"
            Write-Host ""
            Write-Host "Please verify the version exists at:"
            Write-Host "  $releaseUrl"
            Write-Host ""
            Write-Host "You can find available supervisor versions at:"
            Write-Host "  https://github.com/open-telemetry/opentelemetry-collector-releases/releases?q=opampsupervisor"
            Write-Host ""
            return $false
        }
        return $false
    }
}

function Get-Version {
    if ($Version) {
        $ver = $Version
    }
    else {
        $ver = Get-DefaultVersion
        if (-not $ver) {
            Write-Error "Version not specified and unable to fetch default version."
        }
    }
    
    if (-not (Test-Version -Version $ver)) {
        Write-Error "Invalid version: $ver"
    }
    
    return $ver
}

function Get-Architecture {
    # Win32_Processor.Architecture values:
    # 0 = x86 (32-bit Intel) - NOT SUPPORTED
    # 5 = ARM (32-bit ARM) - NOT SUPPORTED
    # 6 = ia64 (Itanium) - NOT SUPPORTED
    # 9 = x64 (64-bit AMD/Intel)
    # 12 = ARM64 (64-bit ARM)
    $arch = (Get-WmiObject Win32_Processor).Architecture
    switch ($arch) {
        0 { 
            Write-Error "32-bit x86 architecture is not supported. Only 64-bit systems (x64, ARM64) are supported."
        }
        5 { 
            Write-Error "32-bit ARM architecture is not supported. Only 64-bit systems (x64, ARM64) are supported."
        }
        9 { return "amd64" }   # x64 (64-bit Intel/AMD)
        12 { return "arm64" }  # ARM64 (64-bit ARM)
        default {
            # Fallback to environment variable for edge cases
            $machine = $env:PROCESSOR_ARCHITECTURE
            if ($machine -eq "AMD64") {
                return "amd64"
            }
            elseif ($machine -eq "ARM64") {
                return "arm64"
            }
            elseif ($machine -eq "x86") {
                Write-Error "32-bit x86 architecture is not supported. Only 64-bit systems (x64, ARM64) are supported."
            }
            else {
                Write-Error "Unsupported architecture: $machine (WMI code: $arch). Only 64-bit systems (x64, ARM64) are supported."
            }
        }
    }
}

function Test-Installed {
    if ($Supervisor) {
        $service = Get-Service -Name $SUPERVISOR_SERVICE_NAME -ErrorAction SilentlyContinue
        if ($service) {
            return $true
        }
        if (Test-Path $SUPERVISOR_BINARY_PATH) {
            return $true
        }
    }
    else {
        $service = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
        if ($service) {
            return $true
        }
        if (Test-Path $BINARY_PATH) {
            return $true
        }
    }
    return $false
}

function Get-EmptyCollectorConfig {
    return @"
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
"@
}

function New-EmptyConfig {
    Write-Log "Creating empty baseline configuration"
    New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null
    Get-EmptyCollectorConfig | Out-File -FilePath $CONFIG_FILE -Encoding utf8 -Force
}

function Get-Timestamp {
    return Get-Date -Format "yyyyMMdd-HHmmss"
}

function Invoke-Download {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$ExpectedChecksum = ""
    )
    
    Write-Log "Downloading: $Url"
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to download: $Url - $($_.Exception.Message)"
    }
    
    if ($ExpectedChecksum) {
        Test-FileChecksum -FilePath $Destination -ExpectedChecksum $ExpectedChecksum
    }
}

function Get-FileChecksum {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found for checksum calculation: $FilePath"
    }
    
    $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
    return $hash.Hash.ToLower()
}

function Test-FileChecksum {
    param(
        [string]$FilePath,
        [string]$ExpectedChecksum
    )
    
    $actualChecksum = Get-FileChecksum -FilePath $FilePath
    $expectedLower = $ExpectedChecksum.ToLower()
    
    if ($actualChecksum -ne $expectedLower) {
        Write-Error "Checksum verification failed for $(Split-Path $FilePath -Leaf)
Expected: $expectedLower
Actual:   $actualChecksum
The downloaded file may be corrupted or tampered with."
    }
    
    Write-Log "Checksum verified: $(Split-Path $FilePath -Leaf)"
}

function Get-OtelChecksum {
    param(
        [string]$Version,
        [string]$Filename
    )
    
    $checksumsUrl = "${OTEL_RELEASES_BASE_URL}/download/v${Version}/${OTEL_COLLECTOR_CHECKSUMS_FILE}"
    
    try {
        $checksums = Invoke-WebRequest -Uri $checksumsUrl -UseBasicParsing -ErrorAction Stop
        $lines = $checksums.Content -split "[\r\n]+"
        
        foreach ($line in $lines) {
            # Format: "checksum  filename"
            if ($line -match "^([a-f0-9]{64})\s+$([regex]::Escape($Filename))$") {
                return $matches[1]
            }
        }
    }
    catch {
        Write-Warn "Could not fetch checksums file: $($_.Exception.Message)"
    }
    
    return $null
}

function Get-SupervisorChecksum {
    param(
        [string]$Version,
        [string]$Filename
    )
    
    $checksumsUrl = "${OTEL_RELEASES_BASE_URL}/download/cmd/opampsupervisor/v${Version}/${OTEL_SUPERVISOR_CHECKSUMS_FILE}"
    
    try {
        $checksums = Invoke-WebRequest -Uri $checksumsUrl -UseBasicParsing -ErrorAction Stop
        $lines = $checksums.Content -split "[\r\n]+"
        
        foreach ($line in $lines) {
            # Format: "checksum  filename"
            if ($line -match "^([a-f0-9]{64})\s+$([regex]::Escape($Filename))$") {
                return $matches[1]
            }
        }
    }
    catch {
        Write-Warn "Could not fetch supervisor checksums file: $($_.Exception.Message)"
    }
    
    return $null
}

function Test-Port {
    param(
        [int]$Port,
        [string]$Name
    )
    
    try {
        $connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        if ($connection) {
            return $false  # Port is in use
        }
    }
    catch {
        # Get-NetTCPConnection not available, try netstat
        try {
            $netstat = netstat -an | Select-String ":$Port\s+.*LISTENING"
            if ($netstat) {
                return $false  # Port is in use
            }
        }
        catch {
            # Can't check, assume port is available
        }
    }
    return $true  # Port is available
}

function Test-Ports {
    $portsInUse = @()
    
    if (-not (Test-Port -Port 4317 -Name "OTLP gRPC")) {
        $portsInUse += "  - Port 4317 (OTLP gRPC)"
    }
    if (-not (Test-Port -Port 4318 -Name "OTLP HTTP")) {
        $portsInUse += "  - Port 4318 (OTLP HTTP)"
    }
    if (-not (Test-Port -Port 13133 -Name "Health Check")) {
        $portsInUse += "  - Port 13133 (Health Check)"
    }
    
    if ($portsInUse.Count -gt 0) {
        Write-Host ""
        Write-Warn "The following ports are already in use:"
        foreach ($port in $portsInUse) {
            Write-Host $port
        }
        Write-Host ""
        Write-Host "This may cause the collector to fail to start."
        Write-Host ""
        Write-Host "Common causes:"
        Write-Host "  - Another collector instance is running (Docker or standalone)"
        Write-Host "  - Another service is using these ports"
        Write-Host ""
        Write-Host "To check what's using a port: netstat -ano | findstr :PORT"
        Write-Host ""
        
        # In non-interactive mode, fail
        if (-not [Environment]::UserInteractive) {
            Write-Error "Port conflict detected. Stop conflicting services and retry."
        }
        
        $response = Read-Host "Continue anyway? [y/N]"
        if ($response -notmatch '^[Yy]$') {
            Write-Error "Installation cancelled due to port conflicts"
        }
    }
}

function Install-CollectorMSI {
    <#
    .SYNOPSIS
    Downloads and installs the OpenTelemetry Collector using MSI installer.
    
    .DESCRIPTION
    Handles MSI download, installation, and verification. Used by both regular
    and supervisor mode installations.
    
    .PARAMETER Version
    The collector version to install.
    
    .PARAMETER Arch
    The architecture (amd64, arm64).
    
    .PARAMETER RemoveService
    If true, removes the service created by MSI after installation.
    Used for supervisor mode where the supervisor manages the collector.
    #>
    param(
        [string]$Version,
        [string]$Arch,
        [switch]$RemoveService = $false
    )
    
    # Map architecture names (MSI uses x64, tar.gz uses amd64)
    $msiArch = if ($Arch -eq "amd64") { "x64" } else { $Arch }
    
    $msiName = "otelcol-contrib_${Version}_windows_${msiArch}.msi"
    $msiUrl = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${Version}/${msiName}"
    $workDir = Join-Path $env:TEMP "${SERVICE_NAME}-msi-$(Get-Timestamp)-$PID"
    
    try {
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $originalLocation = Get-Location
        Set-Location $workDir
        
        Write-Log "Downloading OpenTelemetry Collector ${Version} MSI..."
        Write-Log "Download URL: $msiUrl"
        Invoke-Download -Url $msiUrl -Destination $msiName
        
        Write-Log "Installing OpenTelemetry Collector from MSI..."
        $msiPath = Join-Path $workDir $msiName
        $msiArgs = "/i `"$msiPath`" /qn /norestart"
        $msiResult = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow
        
        if ($msiResult.ExitCode -ne 0 -and $msiResult.ExitCode -ne 3010) {
            Write-Error "MSI installation failed with exit code: $($msiResult.ExitCode)"
        }
        # Exit code 3010 means success but requires reboot (acceptable)
        Write-Log "MSI installation completed successfully"
        
        # Verify binary exists at expected location
        if (-not (Test-Path $BINARY_PATH)) {
            Write-Error "Collector binary not found at expected location: $BINARY_PATH"
        }
        Write-Log "Collector binary installed at: $BINARY_PATH"
        
        # Handle the service created by MSI
        $msiService = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
        if ($msiService) {
            Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            
            if ($RemoveService) {
                Write-Log "Removing MSI-created collector service (supervisor will manage collector)..."
                & sc.exe delete $SERVICE_NAME 2>&1 | Out-Null
                Write-Log "Collector service removed"
            } else {
                Write-Log "MSI-installed service detected, will be reconfigured with custom settings..."
            }
        }
        
        # Verify installation
        $versionOutput = & $BINARY_PATH --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Installation verification failed"
        }
        Write-Log "Collector installed successfully: $versionOutput"
        
        Set-Location $originalLocation
    }
    finally {
        if (Test-Path $workDir) {
            Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-SupervisorMSI {
    <#
    .SYNOPSIS
    Downloads and installs the OpAMP Supervisor using MSI installer.
    
    .DESCRIPTION
    Handles MSI download or uses a provided local MSI file, then installs via msiexec.
    
    .PARAMETER Version
    The supervisor version to install.
    
    .PARAMETER Arch
    The architecture (amd64, arm64).
    
    .PARAMETER LocalMsiPath
    Optional path to a local MSI file. If provided, skips download.
    #>
    param(
        [string]$Version,
        [string]$Arch,
        [string]$LocalMsiPath = ""
    )
    
    $workDir = Join-Path $env:TEMP "${SUPERVISOR_SERVICE_NAME}-msi-$(Get-Timestamp)-$PID"
    
    try {
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $originalLocation = Get-Location
        Set-Location $workDir
        
        if ($LocalMsiPath) {
            # Use provided local MSI
            Write-Log "Using local OpAMP Supervisor MSI: $LocalMsiPath"
            $msiPath = $LocalMsiPath
        }
        else {
            # Download MSI from GitHub releases
            # Map architecture names (MSI uses x64, not amd64)
            $msiArch = if ($Arch -eq "amd64") { "x64" } else { $Arch }
            $msiName = "opampsupervisor_${Version}_windows_${msiArch}.msi"
            $msiUrl = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/cmd%2Fopampsupervisor%2Fv${Version}/${msiName}"
            
            Write-Log "Downloading OpAMP Supervisor ${Version} MSI..."
            Write-Log "Download URL: $msiUrl"
            
            $supervisorChecksum = Get-SupervisorChecksum -Version $Version -Filename $msiName
            if ($supervisorChecksum) {
                Invoke-Download -Url $msiUrl -Destination $msiName -ExpectedChecksum $supervisorChecksum
            }
            else {
                Write-Log "Checksum not available - downloading without verification"
                Invoke-Download -Url $msiUrl -Destination $msiName
            }
            
            $msiPath = Join-Path $workDir $msiName
        }
        
        Write-Log "Installing OpAMP Supervisor from MSI..."
        $msiArgs = "/i `"$msiPath`" /qn /norestart"
        $msiResult = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow
        
        if ($msiResult.ExitCode -ne 0 -and $msiResult.ExitCode -ne 3010) {
            Write-Error "Supervisor MSI installation failed with exit code: $($msiResult.ExitCode)"
        }
        Write-Log "Supervisor MSI installation completed successfully"
        
        # Find the supervisor binary - check multiple possible locations
        # Primary path matches official MSI: C:\Program Files\OpenTelemetry OpAMP Supervisor
        $script:SupervisorBinaryFound = $null
        $possiblePaths = @(
            $SUPERVISOR_BINARY_PATH,
            "${env:ProgramFiles}\OpenTelemetry OpAMP Supervisor\opampsupervisor.exe",
            "${env:ProgramFiles}\OpenTelemetry\Supervisor\opampsupervisor.exe",
            "${env:ProgramFiles}\OpAMP Supervisor\opampsupervisor.exe",
            "${env:ProgramFiles}\opampsupervisor\opampsupervisor.exe"
        )
        
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                Write-Log "Found supervisor binary at: $path"
                $script:SupervisorBinaryFound = $path
                break
            }
        }
        
        # Also search Program Files recursively for opampsupervisor.exe
        if (-not $script:SupervisorBinaryFound) {
            Write-Log "Searching Program Files for opampsupervisor.exe..."
            $found = Get-ChildItem -Path "${env:ProgramFiles}" -Filter "opampsupervisor.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                Write-Log "Found supervisor binary at: $($found.FullName)"
                $script:SupervisorBinaryFound = $found.FullName
            }
        }
        
        if (-not $script:SupervisorBinaryFound) {
            Write-Error "Supervisor binary not found after MSI installation. Please check the MSI installation logs."
        }
        
        Write-Log "Supervisor binary location: $($script:SupervisorBinaryFound)"
        
        Set-Location $originalLocation
    }
    finally {
        if (Test-Path $workDir) {
            Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-Supervisor {
    param(
        [string]$SupervisorVer,
        [string]$CollectorVer,
        [string]$Arch,
        [string]$MsiPath = ""
    )
    
    $workDir = Join-Path $env:TEMP "${SUPERVISOR_SERVICE_NAME}-install-$(Get-Timestamp)-$PID"
    
    try {
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        Set-Location $workDir
        
        # Install collector binary using MSI (remove service since supervisor manages the collector)
        Write-Log "Installing OpenTelemetry Collector binary (required for supervisor)..."
        Install-CollectorMSI -Version $CollectorVer -Arch $Arch -RemoveService
        
        # Install supervisor via MSI (MSI creates install dir and ProgramData folders)
        Install-SupervisorMSI -Version $SupervisorVer -Arch $Arch -LocalMsiPath $MsiPath
        
        # Ensure state directory exists (not created by MSI)
        Write-Log "Creating state directory for supervisor..."
        New-Item -ItemType Directory -Path $SUPERVISOR_STATE_DIR -Force | Out-Null
        
        # Stop existing service if running
        $existingService = Get-Service -Name $SUPERVISOR_SERVICE_NAME -ErrorAction SilentlyContinue
        if ($existingService) {
            Write-Log "Stopping existing supervisor service..."
            Stop-Service -Name $SUPERVISOR_SERVICE_NAME -Force -ErrorAction SilentlyContinue
        }
        
        Configure-Supervisor
    }
    finally {
        if (Test-Path $workDir) {
            Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Configure-Supervisor {
    Write-Log "Configuring OpAMP Supervisor..."
    
    # Use the found binary path or fall back to default
    $supervisorBinary = if ($script:SupervisorBinaryFound) { $script:SupervisorBinaryFound } else { $SUPERVISOR_BINARY_PATH }
    
    # Verify binary exists before creating service
    if (-not (Test-Path $supervisorBinary)) {
        Write-Error "Supervisor binary not found at: $supervisorBinary"
    }
    Write-Log "Using supervisor binary at: $supervisorBinary"
    
    $domain = $env:CORALOGIX_DOMAIN
    $endpointUrl = "https://ingress.${domain}/opamp/v1"
    
    $supervisorConfig = @"
server:
  endpoint: "${endpointUrl}"
  headers:
    Authorization: "Bearer `${env:CORALOGIX_PRIVATE_KEY}"
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
  executable: $($BINARY_PATH -replace '\\', '/')
  passthrough_logs: true
  description:
    non_identifying_attributes:
      service.name: "opentelemetry-collector"
      cx.agent.type: "standalone"
  config_files:
    - $($SUPERVISOR_COLLECTOR_CONFIG_FILE -replace '\\', '/')
  args: []
  env:
    CORALOGIX_PRIVATE_KEY: "`${env:CORALOGIX_PRIVATE_KEY}"
    OTEL_MEMORY_LIMIT_MIB: "`${env:OTEL_MEMORY_LIMIT_MIB}"
    OTEL_LISTEN_INTERFACE: "`${env:OTEL_LISTEN_INTERFACE}"

storage:
  directory: $($SUPERVISOR_STATE_DIR -replace '\\', '/')

telemetry:
  logs:
    level: debug
    output_paths:
      - $($SUPERVISOR_LOG_DIR -replace '\\', '/')/opampsupervisor.log
"@
    
    $supervisorConfig | Out-File -FilePath $SUPERVISOR_CONFIG_FILE -Encoding utf8 -Force
    
    # Write collector config - use base config if provided, otherwise empty config
    if ($SupervisorBaseConfig) {
        Write-Log "Using custom base config from: $SupervisorBaseConfig"
        Copy-Item -Path $SupervisorBaseConfig -Destination $SUPERVISOR_COLLECTOR_CONFIG_FILE -Force
        Write-Log "Base config will be merged with remote configuration from Fleet Manager"
    }
    else {
        Get-EmptyCollectorConfig | Out-File -FilePath $SUPERVISOR_COLLECTOR_CONFIG_FILE -Encoding utf8 -Force
    }
    
    $serviceDisplayName = "OpenTelemetry OpAMP Supervisor"
    $serviceDescription = "OpenTelemetry Collector OpAMP Supervisor - Manages collector configuration remotely"
    
    Write-Log "Configuring supervisor service..."
    
    # Check if MSI already created the service
    $existingService = Get-Service -Name $SUPERVISOR_SERVICE_NAME -ErrorAction SilentlyContinue
    if ($existingService) {
        Write-Log "Service already exists, reconfiguring..."
        Stop-Service -Name $SUPERVISOR_SERVICE_NAME -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        
        # Update service configuration
        # Note: Set-Service -Description is not available in PowerShell 5.1, use sc.exe instead
        & sc.exe description $SUPERVISOR_SERVICE_NAME "$serviceDescription" | Out-Null
        $serviceBinPath = "`"$supervisorBinary`" --config `"$SUPERVISOR_CONFIG_FILE`""
        
        # Update ImagePath directly in registry (more reliable than sc.exe with complex paths)
        $serviceRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$SUPERVISOR_SERVICE_NAME"
        Set-ItemProperty -Path $serviceRegPath -Name "ImagePath" -Value $serviceBinPath -ErrorAction Stop
        Write-Log "Service binary path updated to: $serviceBinPath"
    }
    else {
        # Create service using native Windows service management
        Write-Log "Creating Windows Service for supervisor..."
        $serviceBinPath = "`"$supervisorBinary`" --config `"$SUPERVISOR_CONFIG_FILE`""
        try {
            New-Service -Name $SUPERVISOR_SERVICE_NAME `
                -BinaryPathName $serviceBinPath `
                -DisplayName $serviceDisplayName `
                -Description $serviceDescription `
                -StartupType Automatic `
                -ErrorAction Stop | Out-Null
            Write-Log "Service created successfully"
        }
        catch {
            Write-Error "Failed to create supervisor service: $_"
        }
    }
    
    # Set environment variables via registry
    Write-Log "Setting service environment variables..."
    $serviceRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$SUPERVISOR_SERVICE_NAME"
    $envVars = @(
        "CORALOGIX_PRIVATE_KEY=$($env:CORALOGIX_PRIVATE_KEY)",
        "OTEL_MEMORY_LIMIT_MIB=$MemoryLimit",
        "OTEL_LISTEN_INTERFACE=$ListenInterface"
    )
    if ($env:CORALOGIX_DOMAIN) {
        $envVars += "CORALOGIX_DOMAIN=$($env:CORALOGIX_DOMAIN)"
    }
    Set-ItemProperty -Path $serviceRegPath -Name "Environment" -Value $envVars -Type MultiString -ErrorAction SilentlyContinue
    
    Write-Log "Starting supervisor service..."
    Start-Service -Name $SUPERVISOR_SERVICE_NAME -ErrorAction SilentlyContinue
    
    Write-Log "Supervisor configured and started"
    
    Verify-Supervisor
}

function Verify-Supervisor {
    $maxAttempts = 15
    $attempt = 0
    
    Write-Log "Verifying supervisor installation..."
    
    while ($attempt -lt $maxAttempts) {
        $service = Get-Service -Name $SUPERVISOR_SERVICE_NAME -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq 'Running') {
            Write-Log "Supervisor service is running"
            break
        }
        Start-Sleep -Seconds 1
        $attempt++
    }
    
    if ($attempt -eq $maxAttempts) {
        Write-Warn "Supervisor service may not be running. Check status with: Get-Service $SUPERVISOR_SERVICE_NAME"
        return
    }
    
    Start-Sleep -Seconds 2
    
    $attempt = 0
    while ($attempt -lt $maxAttempts) {
        $process = Get-Process -Name "otelcol-contrib" -ErrorAction SilentlyContinue
        if ($process) {
            Write-Log "Collector process is running (managed by supervisor)"
            break
        }
        Start-Sleep -Seconds 1
        $attempt++
    }
    
    if ($attempt -eq $maxAttempts) {
        Write-Warn "Collector process may not be running yet. Supervisor will restart it automatically."
    }
    
    Write-Log "Supervisor verification complete"
}

function New-WindowsService {
    Write-Log "Configuring Windows Service..."
    
    $serviceDisplayName = "OpenTelemetry Collector"
    $serviceDescription = "OpenTelemetry Collector - Collects, processes, and exports telemetry data"
    
    # Handle dynamic metadata parsing (e.g., for IIS logs)
    if ($EnableDynamicMetadataParsing) {
        Write-Log "Enabling dynamic metadata parsing for file logs..."
        $storageDir = Join-Path $CONFIG_DIR "storage"
        if (-not (Test-Path $storageDir)) {
            Write-Log "Creating storage directory: $storageDir"
            New-Item -ItemType Directory -Force -Path $storageDir | Out-Null
        }
    }
    
    # Check if service already exists (from MSI installation)
    $existingService = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
    
    # Build service binary path with optional feature gates
    $serviceBinPath = "`"$BINARY_PATH`" --config `"$CONFIG_FILE`""
    if ($EnableDynamicMetadataParsing) {
        $serviceBinPath += " --feature-gates=filelog.allowHeaderMetadataParsing"
        Write-Log "Added feature gate: filelog.allowHeaderMetadataParsing"
    }
    
    if ($existingService) {
        Write-Log "Service already exists, stopping for reconfiguration..."
        Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        
        # Update service configuration
        Write-Log "Configuring service binary path..."
        # Note: Set-Service -Description is not available in PowerShell 5.1, use sc.exe instead
        & sc.exe description $SERVICE_NAME "$serviceDescription" | Out-Null
        
        # Update ImagePath directly in registry (more reliable than sc.exe with complex paths)
        $serviceRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$SERVICE_NAME"
        Set-ItemProperty -Path $serviceRegPath -Name "ImagePath" -Value $serviceBinPath -ErrorAction Stop
        Write-Log "Service binary path updated to: $serviceBinPath"
    }
    else {
        # Create service using New-Service cmdlet
        Write-Log "Creating Windows Service..."
        try {
            New-Service -Name $SERVICE_NAME `
                -BinaryPathName $serviceBinPath `
                -DisplayName $serviceDisplayName `
                -Description $serviceDescription `
                -StartupType Automatic `
                -ErrorAction Stop | Out-Null
            Write-Log "Service created successfully"
        }
        catch {
            Write-Error "Failed to create collector service: $_"
        }
    }
    
    # Register Event Log source for the collector
    Write-Log "Registering Windows Event Log source..."
    $eventLogKey = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application\$SERVICE_NAME"
    if (-not (Test-Path $eventLogKey)) {
        New-Item -Path $eventLogKey -Force | Out-Null
    }
    Set-ItemProperty -Path $eventLogKey -Name "EventMessageFile" -Value "%SystemRoot%\System32\EventCreate.exe" -Type ExpandString -Force
    
    # Set environment variables for the service via registry
    Write-Log "Setting service environment variables..."
    $serviceRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$SERVICE_NAME"
    
    # Build environment variables array
    $envVars = @(
        "CORALOGIX_PRIVATE_KEY=$($env:CORALOGIX_PRIVATE_KEY)",
        "OTEL_MEMORY_LIMIT_MIB=$MemoryLimit",
        "OTEL_LISTEN_INTERFACE=$ListenInterface"
    )
    if ($env:CORALOGIX_DOMAIN) {
        $envVars += "CORALOGIX_DOMAIN=$($env:CORALOGIX_DOMAIN)"
    }
    
    # Set the Environment multi-string value in the registry
    Set-ItemProperty -Path $serviceRegPath -Name "Environment" -Value $envVars -Type MultiString -ErrorAction SilentlyContinue
    
    Write-Log "Starting service..."
    try {
        Start-Service -Name $SERVICE_NAME -ErrorAction Stop
        Start-Sleep -Seconds 2
        
        # Verify service started
        $service = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
        if ($service.Status -ne 'Running') {
            Write-Warn "Service started but status is: $($service.Status)"
            Write-Warn "Check Windows Event Log for details:"
            Write-Warn "  Get-EventLog -LogName System -Source 'Service Control Manager' -Newest 20 | Where-Object {`$_.Message -like '*otelcol*'}"
        }
    }
    catch {
        Write-Error "Failed to start service: $($_.Exception.Message)"
        Write-Host ""
        Write-Host "Troubleshooting steps:"
        Write-Host "1. Check if binary exists: Test-Path '$BINARY_PATH'"
        Write-Host "2. Check if config exists: Test-Path '$CONFIG_FILE'"
        Write-Host "3. Validate config: & '$BINARY_PATH' validate --config '$CONFIG_FILE'"
        Write-Host "4. Check Event Log: Get-EventLog -LogName System -Source 'Service Control Manager' -Newest 20"
        Write-Host "5. Check service path: Get-CimInstance Win32_Service -Filter \"Name='$SERVICE_NAME'\" | Select-Object PathName"
        Write-Host ""
        throw
    }
}

function Test-Service {
    $maxAttempts = 10
    $attempt = 0
    
    Write-Log "Verifying service is running..."
    
    while ($attempt -lt $maxAttempts) {
        $service = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq 'Running') {
            Write-Log "Service is running"
            return
        }
        Start-Sleep -Seconds 1
        $attempt++
    }
    
    Write-Warn "Service may not be running. Check status with: Get-Service $SERVICE_NAME"
}

function Test-SupervisorMode {
    $service = Get-Service -Name $SUPERVISOR_SERVICE_NAME -ErrorAction SilentlyContinue
    if ($service) {
        return $true
    }
    if (Test-Path $SUPERVISOR_BINARY_PATH) {
        return $true
    }
    return $false
}

function Stop-ServiceWindows {
    if ($Supervisor) {
        $service = Get-Service -Name $SUPERVISOR_SERVICE_NAME -ErrorAction SilentlyContinue
        if ($service) {
            Write-Log "Stopping and removing OpAMP Supervisor service..."
            Stop-Service -Name $SUPERVISOR_SERVICE_NAME -Force -ErrorAction SilentlyContinue
            
            # Wait for service to fully stop (max 30 seconds)
            $timeout = 30
            $waited = 0
            while ($waited -lt $timeout) {
                $service = Get-Service -Name $SUPERVISOR_SERVICE_NAME -ErrorAction SilentlyContinue
                if (-not $service -or $service.Status -eq 'Stopped') { break }
                Start-Sleep -Seconds 1
                $waited++
            }
            
            & sc.exe delete $SUPERVISOR_SERVICE_NAME | Out-Null
        }
        
        # Also kill any remaining otelcol-contrib processes (managed by supervisor)
        Get-Process -Name "otelcol-contrib" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    else {
        # For regular mode, just stop the service - MSI uninstall will remove it
        $service = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
        if ($service) {
            Write-Log "Stopping service..."
            Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
            
            # Wait for service to fully stop (max 30 seconds)
            $timeout = 30
            $waited = 0
            while ($waited -lt $timeout) {
                $service = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
                if (-not $service -or $service.Status -eq 'Stopped') { break }
                Start-Sleep -Seconds 1
                $waited++
            }
            
            # Kill the process if still running (service stop may not kill immediately)
            Get-Process -Name "otelcol-contrib" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        
        # Remove Event Log source registration (in case of manual uninstall)
        $eventLogKey = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application\$SERVICE_NAME"
        if (Test-Path $eventLogKey) {
            Write-Log "Removing Event Log source registration..."
            Remove-Item -Path $eventLogKey -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-MsiProductInfo {
    # Search for OpenTelemetry Collector in the registry (MSI installations)
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    
    foreach ($path in $uninstallPaths) {
        if (Test-Path $path) {
            $products = Get-ChildItem $path -ErrorAction SilentlyContinue | 
                Get-ItemProperty -ErrorAction SilentlyContinue | 
                Where-Object { $_.DisplayName -like "*OpenTelemetry*Collector*" -or $_.DisplayName -like "*otelcol*" }
            
            if ($products) {
                foreach ($product in $products) {
                    return @{
                        DisplayName = $product.DisplayName
                        UninstallString = $product.UninstallString
                        ProductCode = $product.PSChildName
                        InstallLocation = $product.InstallLocation
                    }
                }
            }
        }
    }
    
    return $null
}

function Uninstall-MsiPackage {
    $msiInfo = Get-MsiProductInfo
    
    if ($msiInfo) {
        Write-Log "Found MSI installation: $($msiInfo.DisplayName)"
        Write-Log "Product Code: $($msiInfo.ProductCode)"
        
        # Use msiexec to uninstall
        $productCode = $msiInfo.ProductCode
        Write-Log "Uninstalling via MSI..."
        
        # Add /l*v for verbose logging in case of issues, and use a timeout
        $logFile = Join-Path $env:TEMP "otelcol-uninstall-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        $msiArgs = "/x `"$productCode`" /qn /norestart /l*v `"$logFile`""
        Write-Log "MSI log file: $logFile"
        
        $msiProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -PassThru -NoNewWindow
        
        # Wait with timeout (5 minutes should be more than enough for uninstall)
        $timeout = 300  # seconds
        $completed = $msiProcess.WaitForExit($timeout * 1000)
        
        if (-not $completed) {
            Write-Warn "MSI uninstallation timed out after $timeout seconds"
            Write-Warn "Attempting to kill msiexec process..."
            try {
                $msiProcess.Kill()
                # Also kill any child msiexec processes
                Get-Process -Name "msiexec" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-Warn "Failed to kill msiexec: $_"
            }
            Write-Warn "Check log file for details: $logFile"
            return $false
        }
        
        if ($msiProcess.ExitCode -eq 0 -or $msiProcess.ExitCode -eq 3010) {
            Write-Log "MSI uninstallation completed successfully"
            # Clean up log file on success
            Remove-Item -Path $logFile -Force -ErrorAction SilentlyContinue
            return $true
        }
        else {
            Write-Warn "MSI uninstallation returned exit code: $($msiProcess.ExitCode)"
            Write-Warn "Check log file for details: $logFile"
            return $false
        }
    }
    else {
        Write-Log "No MSI installation found in registry"
        return $false
    }
}

function Remove-PackageWindows {
    if ($Supervisor) {
        # Remove supervisor binary (manual install)
        if (Test-Path $SUPERVISOR_BINARY_PATH) {
            Write-Log "Removing supervisor binary: $SUPERVISOR_BINARY_PATH"
            Remove-Item -Path $SUPERVISOR_BINARY_PATH -Force -ErrorAction SilentlyContinue
        }
        
        # Remove collector via MSI uninstaller (same install method as regular mode)
        $msiUninstalled = Uninstall-MsiPackage
        if (-not $msiUninstalled) {
            # Fallback to manual removal if MSI uninstall failed
            if (Test-Path $BINARY_PATH) {
                Write-Log "Removing collector binary: $BINARY_PATH"
                Remove-Item -Path $BINARY_PATH -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Clean up install directory if empty
        if (Test-Path $INSTALL_DIR) {
            $remainingFiles = Get-ChildItem -Path $INSTALL_DIR -ErrorAction SilentlyContinue
            if (-not $remainingFiles) {
                Write-Log "Removing install directory: $INSTALL_DIR"
                Remove-Item -Path $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        if ($Purge) {
            if (Test-Path $SUPERVISOR_DATA_DIR) {
                Write-Log "Removing supervisor data: $SUPERVISOR_DATA_DIR"
                Remove-Item -Path $SUPERVISOR_DATA_DIR -Recurse -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path $SUPERVISOR_INSTALL_DIR) {
                Write-Log "Removing supervisor install directory: $SUPERVISOR_INSTALL_DIR"
                Remove-Item -Path $SUPERVISOR_INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    else {
        # Regular mode - use MSI uninstallation
        $msiUninstalled = Uninstall-MsiPackage
        
        if (-not $msiUninstalled) {
            # Fallback to manual removal if MSI uninstall failed or not found
            Write-Log "Falling back to manual file removal..."
            
            if (Test-Path $BINARY_PATH) {
                Write-Log "Removing binary: $BINARY_PATH"
                Remove-Item -Path $BINARY_PATH -Force -ErrorAction SilentlyContinue
            }
            
            if (Test-Path $INSTALL_DIR) {
                $remainingFiles = Get-ChildItem -Path $INSTALL_DIR -ErrorAction SilentlyContinue
                if (-not $remainingFiles) {
                    Write-Log "Removing install directory: $INSTALL_DIR"
                    Remove-Item -Path $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

function Remove-Data {
    if ($Purge) {
        Write-Log "Removing configuration and log directories..."
        
        if (Test-Path $CONFIG_DIR) {
            Remove-Item -Path $CONFIG_DIR -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Removed: $CONFIG_DIR"
        }
        
        if (Test-Path $LOG_DIR) {
            Remove-Item -Path $LOG_DIR -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Removed: $LOG_DIR"
        }
        
        # Clean up empty parent folder (C:\ProgramData\OpenTelemetry)
        $parentDir = "${env:ProgramData}\OpenTelemetry"
        if (Test-Path $parentDir) {
            $remainingItems = Get-ChildItem -Path $parentDir -ErrorAction SilentlyContinue
            if (-not $remainingItems) {
                Remove-Item -Path $parentDir -Force -ErrorAction SilentlyContinue
                Write-Log "Removed empty parent directory: $parentDir"
            }
        }
    }
    else {
        Write-Log "Configuration and logs preserved (use -Purge to remove):"
        if (Test-Path $CONFIG_DIR) {
            Write-Log "  $CONFIG_DIR"
        }
        if (Test-Path $LOG_DIR) {
            Write-Log "  $LOG_DIR"
        }
    }
}

function Uninstall-Main {
    Write-Log "Coralogix OpenTelemetry Collector Uninstaller"
    Write-Log "=============================================="
    
    Test-Administrator
    
    # Detect if supervisor mode is installed
    $isSupervisor = Test-SupervisorMode
    if ($isSupervisor) {
        $script:Supervisor = $true
    }
    
    Stop-ServiceWindows
    Remove-PackageWindows
    Remove-Data
    
    $message = @"

Uninstall complete!

$(if ($Purge) {
    "All files, configuration, and logs have been removed."
} else {
    "Binary and service have been removed.`nConfiguration and logs have been preserved."
})

To reinstall, run the installer script again.

"@
    Write-Host $message
    exit 0
}

# Main execution
function Main {
    if ($Help) {
        Show-Usage
        exit 0
    }
    
    Write-Log "Coralogix OpenTelemetry Collector Installer"
    Write-Log "============================================"
    
    if ($Uninstall) {
        Uninstall-Main
        return
    }
    
    if ($Purge -and -not $Uninstall) {
        Write-Error "-Purge must be used with -Uninstall"
    }
    
    if (-not $env:CORALOGIX_PRIVATE_KEY) {
        Write-Error "CORALOGIX_PRIVATE_KEY environment variable is required."
    }
    
    Test-Administrator
    
    if ($Supervisor -and $Config) {
        Write-Error "-Config cannot be used with -Supervisor. Supervisor mode uses default config and receives configuration from the OpAMP server."
    }
    
    if ($Supervisor -and $EnableDynamicMetadataParsing) {
        Write-Error "-EnableDynamicMetadataParsing cannot be used with -Supervisor. This feature is only available in regular mode."
    }
    
    # Validate SupervisorBaseConfig
    if ($SupervisorBaseConfig) {
        if (-not $Supervisor) {
            Write-Error "-SupervisorBaseConfig can only be used with -Supervisor"
        }
        if (-not (Test-Path $SupervisorBaseConfig)) {
            Write-Error "Supervisor base config file not found: $SupervisorBaseConfig"
        }
        # Check that config doesn't contain opamp extension
        $baseConfigContent = Get-Content $SupervisorBaseConfig -Raw
        if ($baseConfigContent -match '(?m)^\s*opamp:') {
            Write-Error "Supervisor base config cannot contain 'opamp' extension. The supervisor manages the OpAMP connection.`nRemove the 'opamp' extension from your config file: $SupervisorBaseConfig"
        }
        Write-Log "Using custom base config for supervisor: $SupervisorBaseConfig"
    }
    
    if ($Supervisor) {
        if (-not $env:CORALOGIX_DOMAIN) {
            Write-Error "CORALOGIX_DOMAIN environment variable is required for supervisor mode"
        }
    }
    else {
        if ($SupervisorVersion) {
            Write-Error "-SupervisorVersion can only be used with -Supervisor"
        }
        if ($CollectorVersion) {
            Write-Error "-CollectorVersion can only be used with -Supervisor"
        }
        if ($SupervisorMsi) {
            Write-Error "-SupervisorMsi can only be used with -Supervisor"
        }
    }
    
    if ($SupervisorMsi -and -not (Test-Path $SupervisorMsi)) {
        Write-Error "Supervisor MSI file not found: $SupervisorMsi"
    }
    
    if ($Config -and -not (Test-Path $Config)) {
        Write-Error "Config file not found: $Config"
    }
    
    $arch = Get-Architecture
    Write-Log "Detected architecture: $arch"
    
    # Detect if user explicitly set MemoryLimit or ListenInterface
    if ($PSBoundParameters.ContainsKey('MemoryLimit')) {
        $script:UserSetMemoryLimit = $true
    }
    if ($PSBoundParameters.ContainsKey('ListenInterface')) {
        $script:UserSetListenInterface = $true
    }
    Write-Log "Memory limit: $MemoryLimit MiB"
    Write-Log "Listen interface: $ListenInterface"
    
    $version = Get-Version
    Write-Log "Installing version: $version"
    
    # Auto-detect if this is an upgrade or fresh install
    if (Test-Installed) {
        Write-Log "Existing installation detected - will upgrade"
        
        # Check for mode mismatch - regular and supervisor modes use different binaries
        # In supervisor mode, both collector and supervisor binaries exist
        # In regular mode, only the collector binary exists (no supervisor)
        $isSupervisorInstalled = Test-SupervisorMode
        
        if ($Supervisor -and -not $isSupervisorInstalled -and (Test-Path $BINARY_PATH)) {
            Write-Error "Cannot upgrade: Regular mode is installed. Please uninstall first, then install supervisor mode."
        }
        
        if (-not $Supervisor -and $isSupervisorInstalled) {
            Write-Error "Cannot upgrade: Supervisor mode is installed. Please uninstall first, then install regular mode."
        }
        
        # Skip port checks on upgrade (service is already running)
    }
    else {
        Write-Log "No existing installation detected - fresh install"
        
        # Check for port conflicts only on fresh install
        Test-Ports
    }
    
    if ($Supervisor) {
        # Determine supervisor and collector versions
        # MSI is only available from version 0.144.0 onwards
        # Skip version check if local MSI is provided
        if ($SupervisorMsi) {
            # User provided local MSI - use their specified versions or detected version
            $supervisorVer = if ($SupervisorVersion) { $SupervisorVersion } else { $version }
            $collectorVer = if ($CollectorVersion) { $CollectorVersion } else { $version }
            Write-Log "Using local supervisor MSI - skipping version minimum check"
        }
        elseif ($SupervisorVersion -or $CollectorVersion) {
            # User explicitly specified versions - use them
            $supervisorVer = if ($SupervisorVersion) { $SupervisorVersion } else { $version }
            $collectorVer = if ($CollectorVersion) { $CollectorVersion } else { $version }
        }
        else {
            # No explicit versions - enforce minimum version for MSI availability
            # Use detected version if >= minimum, otherwise use minimum
            if ([version]$version -ge [version]$SUPERVISOR_MIN_VERSION) {
                $supervisorVer = $version
                $collectorVer = $version
                Write-Log "Supervisor mode: Using detected version $version (>= minimum $SUPERVISOR_MIN_VERSION)"
            }
            else {
                $supervisorVer = $SUPERVISOR_MIN_VERSION
                $collectorVer = $SUPERVISOR_MIN_VERSION
                Write-Log "Supervisor mode: Detected version $version is below minimum for MSI"
                Write-Warn "Note: Supervisor MSI is only available from version $SUPERVISOR_MIN_VERSION onwards"
                Write-Warn "      Using minimum version $SUPERVISOR_MIN_VERSION instead of $version"
                Write-Warn "      Use -SupervisorVersion/-CollectorVersion to override, or -SupervisorMsi for local MSI"
            }
        }
        
        if ($CollectorVersion -and $collectorVer -ne $version) {
            Write-Log "Validating collector version: $collectorVer"
            if (-not (Test-Version -Version $collectorVer)) {
                Write-Error "Invalid collector version: $collectorVer"
            }
        }
        
        # Validate supervisor version (has different release path than collector)
        if ($SupervisorVersion) {
            Write-Log "Validating supervisor version: $supervisorVer"
            if (-not (Test-SupervisorVersion -Version $supervisorVer)) {
                Write-Error "Invalid supervisor version: $supervisorVer"
            }
        }
        
        Write-Log "Supervisor version: $supervisorVer"
        Write-Log "Collector version: $collectorVer"
        
        Install-Supervisor -SupervisorVer $supervisorVer -CollectorVer $collectorVer -Arch $arch -MsiPath $SupervisorMsi
        
        $baseConfigInfo = if ($SupervisorBaseConfig) {
            "`nCustom Base Config:`n  Source: $SupervisorBaseConfig`n  Installed: $SUPERVISOR_COLLECTOR_CONFIG_FILE`n  The base config is merged with remote configuration from Fleet Manager.`n"
        } else { "" }
        
        $summary = @"

Installation complete with supervisor mode!

Supervisor Version: $supervisorVer
Collector Version: $collectorVer
Supervisor Service: $SUPERVISOR_SERVICE_NAME
Collector Binary: $BINARY_PATH
Supervisor Config: $SUPERVISOR_CONFIG_FILE
Collector Config: $SUPERVISOR_COLLECTOR_CONFIG_FILE
Effective Config: $SUPERVISOR_STATE_DIR\effective.yaml
$baseConfigInfo
Useful commands:
  Supervisor status:      Get-Service $SUPERVISOR_SERVICE_NAME
  Collector process:      Get-Process otelcol-contrib
  Supervisor logs:        Get-EventLog -LogName Application -Source $SUPERVISOR_SERVICE_NAME -Newest 50 | Format-List
  View supervisor config: Get-Content "$SUPERVISOR_CONFIG_FILE"
  View collector config:  Get-Content "$SUPERVISOR_COLLECTOR_CONFIG_FILE"
  View effective config:  Get-Content "$SUPERVISOR_STATE_DIR\effective.yaml"
  Restart supervisor:     Restart-Service $SUPERVISOR_SERVICE_NAME
  Stop supervisor:        Stop-Service $SUPERVISOR_SERVICE_NAME
  Start supervisor:       Start-Service $SUPERVISOR_SERVICE_NAME

Note: The collector is managed by the supervisor. Configuration updates
will be received from the OpAMP server automatically. The effective.yaml
shows the actual merged configuration after applying Fleet Management settings.

"@
        Write-Host $summary
        exit 0
    }
    
    Install-CollectorMSI -Version $version -Arch $arch
    
    if ($Config) {
        Write-Log "Using custom config from: $Config"
        New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null
        Copy-Item -Path $Config -Destination $CONFIG_FILE -Force
    }
    elseif (Test-Path $CONFIG_FILE) {
        Write-Log "Using existing config at: $CONFIG_FILE"
    }
    else {
        New-EmptyConfig
    }
    
    # Validate that config references the env vars if user set them
    Test-ConfigEnvVars -ConfigPath $CONFIG_FILE
    
    New-WindowsService
    Test-Service
    
    $summary = @"

Installation complete!

Service: $SERVICE_NAME
Binary: $BINARY_PATH
Config: $CONFIG_FILE
$(if ($EnableDynamicMetadataParsing) { "Dynamic Metadata Parsing: Enabled (filelog.allowHeaderMetadataParsing)`nStorage Directory: $CONFIG_DIR\storage" })

Useful commands:
  Check status:  Get-Service $SERVICE_NAME
  View config:   Get-Content "$CONFIG_FILE"
  View logs:     Get-EventLog -LogName Application -Source $SERVICE_NAME -Newest 50
  Restart:       Restart-Service $SERVICE_NAME
  Stop:          Stop-Service $SERVICE_NAME
  Start:         Start-Service $SERVICE_NAME

"@
    Write-Host $summary
    exit 0
}

# Run main function
Main

