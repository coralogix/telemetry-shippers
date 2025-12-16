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
    
.PARAMETER Upgrade
    Upgrade existing installation
    
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
    # Upgrade existing installation
    $env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -Upgrade
    
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
    [Alias("u")]
    [switch]$Upgrade = $false,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [switch]$Uninstall = $false,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [switch]$Purge = $false,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias("h")]
    [switch]$Help = $false
)

# Script constants
$SCRIPT_NAME = "coralogix-otel-collector"
$SERVICE_NAME = "otelcol-contrib"
$SUPERVISOR_SERVICE_NAME = "opampsupervisor"
$BINARY_NAME = "otelcol-contrib.exe"
$INSTALL_DIR = "${env:ProgramFiles}\OpenTelemetry\Collector"
$BINARY_PATH = Join-Path $INSTALL_DIR $BINARY_NAME
$CONFIG_DIR = "${env:ProgramData}\OpenTelemetry\Collector"
$CONFIG_FILE = Join-Path $CONFIG_DIR "config.yaml"
$LOG_DIR = "${env:ProgramData}\OpenTelemetry\Collector\logs"
$SUPERVISOR_INSTALL_DIR = "${env:ProgramFiles}\OpenTelemetry\Supervisor"
$SUPERVISOR_BINARY_NAME = "opampsupervisor.exe"
$SUPERVISOR_BINARY_PATH = Join-Path $SUPERVISOR_INSTALL_DIR $SUPERVISOR_BINARY_NAME
$SUPERVISOR_CONFIG_DIR = "${env:ProgramData}\OpenTelemetry\Supervisor"
$SUPERVISOR_CONFIG_FILE = Join-Path $SUPERVISOR_CONFIG_DIR "config.yaml"
$SUPERVISOR_COLLECTOR_CONFIG_FILE = Join-Path $SUPERVISOR_CONFIG_DIR "collector.yaml"
$SUPERVISOR_STATE_DIR = "${env:ProgramData}\OpenTelemetry\Supervisor\state"
$SUPERVISOR_LOG_DIR = Join-Path $SUPERVISOR_CONFIG_DIR "logs"
$CHART_YAML_URL = "https://raw.githubusercontent.com/coralogix/opentelemetry-helm-charts/refs/heads/main/charts/opentelemetry-collector/Chart.yaml"

# Global variables
$script:BackupDir = ""

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
    -Upgrade                        Upgrade existing installation
    -SupervisorVersion <ver>        Supervisor version (supervisor mode only)
                                    (default: same as -Version)
    -CollectorVersion <ver>         Collector version (supervisor mode only)
                                    (default: same as -Version)
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

    # Upgrade existing installation
    `$env:CORALOGIX_PRIVATE_KEY="your-key"; .\coralogix-otel-collector.ps1 -Upgrade

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
    $arch = (Get-WmiObject Win32_Processor).Architecture
    switch ($arch) {
        0 { return "amd64" }  # x86
        5 { return "arm64" }  # ARM
        9 { return "amd64" }  # x64
        default {
            $machine = $env:PROCESSOR_ARCHITECTURE
            if ($machine -eq "AMD64") {
                return "amd64"
            }
            elseif ($machine -eq "ARM64") {
                return "arm64"
            }
            else {
                Write-Error "Unsupported architecture: $machine. Only amd64 and arm64 are supported."
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

function Backup-Config {
    if (Test-Path $CONFIG_FILE) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $script:BackupDir = Join-Path $env:TEMP "${SERVICE_NAME}-backup-${timestamp}"
        Write-Log "Backing up existing configuration to: $script:BackupDir"
        New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null
        Copy-Item -Path $CONFIG_DIR -Destination $script:BackupDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Backup created at: $script:BackupDir"
    }
}

function Restore-Config {
    if ($script:BackupDir -and (Test-Path $script:BackupDir)) {
        $backupConfig = Join-Path $script:BackupDir (Split-Path $CONFIG_DIR -Leaf) "config.yaml"
        if (Test-Path $backupConfig) {
            Write-Log "Restoring configuration from backup"
            New-Item -ItemType Directory -Path (Split-Path $CONFIG_FILE -Parent) -Force | Out-Null
            Copy-Item -Path $backupConfig -Destination $CONFIG_FILE -Force -ErrorAction SilentlyContinue
        }
    }
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
        [string]$Destination
    )
    
    Write-Log "Downloading: $Url"
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to download: $Url - $($_.Exception.Message)"
    }
}

function Install-Collector {
    param(
        [string]$Version,
        [string]$Arch
    )
    
    $binaryNameWithoutExt = $BINARY_NAME.Replace('.exe', '')
    if ([string]::IsNullOrEmpty($binaryNameWithoutExt)) {
        Write-Error "Failed to determine binary name. BINARY_NAME is: $BINARY_NAME"
    }
    $tarName = "$binaryNameWithoutExt" + "_" + "$Version" + "_windows_" + "$Arch" + ".tar.gz"
    $tarUrl = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v$Version/$tarName"
    $workDir = Join-Path $env:TEMP "${SERVICE_NAME}-install-$(Get-Timestamp)-$PID"
    
    try {
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        Set-Location $workDir
        
        Write-Log "Downloading OpenTelemetry Collector ${Version}..."
        Write-Log "Download URL: $tarUrl"
        Invoke-Download -Url $tarUrl -Destination $tarName
        
        Write-Log "Extracting collector..."
        Expand-Archive -Path $tarName -DestinationPath . -Force
        
        $extractedBinary = Get-ChildItem -Path . -Filter $BINARY_NAME -Recurse | Select-Object -First 1
        if (-not $extractedBinary) {
            Write-Error "Binary $BINARY_NAME not found in archive"
        }
        
        Write-Log "Installing binary to $INSTALL_DIR"
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
        Copy-Item -Path $extractedBinary.FullName -Destination $BINARY_PATH -Force
        
        # Verify installation
        $versionOutput = & $BINARY_PATH --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Installation verification failed"
        }
        
        Write-Log "Collector installed successfully: $versionOutput"
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
        [string]$Arch
    )
    
    $workDir = Join-Path $env:TEMP "${SUPERVISOR_SERVICE_NAME}-install-$(Get-Timestamp)-$PID"
    
    try {
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        Set-Location $workDir
        
        # Install collector binary first
        Write-Log "Installing OpenTelemetry Collector binary (required for supervisor)..."
        $collectorTarName = "otelcol-contrib_${CollectorVer}_windows_${Arch}.tar.gz"
        $collectorTarUrl = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${CollectorVer}/${collectorTarName}"
        
        Write-Log "Downloading OpenTelemetry Collector ${CollectorVer}..."
        Invoke-Download -Url $collectorTarUrl -Destination $collectorTarName
        
        Write-Log "Extracting Collector..."
        Expand-Archive -Path $collectorTarName -DestinationPath . -Force
        
        $extractedBinary = Get-ChildItem -Path . -Filter $BINARY_NAME -Recurse | Select-Object -First 1
        if (-not $extractedBinary) {
            Write-Error "Expected otelcol-contrib binary after extraction."
        }
        
        Write-Log "Placing Collector binary into ${env:ProgramFiles}\OpenTelemetry\Collector..."
        New-Item -ItemType Directory -Path "${env:ProgramFiles}\OpenTelemetry\Collector" -Force | Out-Null
        Copy-Item -Path $extractedBinary.FullName -Destination "${env:ProgramFiles}\OpenTelemetry\Collector\otelcol-contrib.exe" -Force
        
        # Install supervisor
        Write-Log "Creating required directories for supervisor..."
        New-Item -ItemType Directory -Path $SUPERVISOR_INSTALL_DIR -Force | Out-Null
        New-Item -ItemType Directory -Path $SUPERVISOR_CONFIG_DIR -Force | Out-Null
        New-Item -ItemType Directory -Path $SUPERVISOR_STATE_DIR -Force | Out-Null
        New-Item -ItemType Directory -Path $SUPERVISOR_LOG_DIR -Force | Out-Null
        
        $supervisorTarName = "opampsupervisor_${SupervisorVer}_windows_${Arch}.tar.gz"
        $supervisorTarUrl = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/cmd%2Fopampsupervisor%2Fv${SupervisorVer}/${supervisorTarName}"
        
        Write-Log "Downloading OpAMP Supervisor ${SupervisorVer}..."
        Invoke-Download -Url $supervisorTarUrl -Destination $supervisorTarName
        
        Write-Log "Extracting Supervisor..."
        Expand-Archive -Path $supervisorTarName -DestinationPath . -Force
        
        $supervisorBinary = Get-ChildItem -Path . -Filter $SUPERVISOR_BINARY_NAME -Recurse | Select-Object -First 1
        if (-not $supervisorBinary) {
            Write-Error "Expected opampsupervisor binary after extraction."
        }
        
        Write-Log "Installing OpAMP Supervisor ${SupervisorVer}..."
        Copy-Item -Path $supervisorBinary.FullName -Destination $SUPERVISOR_BINARY_PATH -Force
        
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
  executable: ${env:ProgramFiles}\OpenTelemetry\Collector\otelcol-contrib.exe
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

storage:
  directory: $($SUPERVISOR_STATE_DIR -replace '\\', '/')

telemetry:
  logs:
    level: debug
    output_paths:
      - $($SUPERVISOR_LOG_DIR -replace '\\', '/')/opampsupervisor.log
"@
    
    $supervisorConfig | Out-File -FilePath $SUPERVISOR_CONFIG_FILE -Encoding utf8 -Force
    
    Get-EmptyCollectorConfig | Out-File -FilePath $SUPERVISOR_COLLECTOR_CONFIG_FILE -Encoding utf8 -Force
    
    # Create Windows Service
    $existingService = Get-Service -Name $SUPERVISOR_SERVICE_NAME -ErrorAction SilentlyContinue
    if ($existingService) {
        Write-Log "Removing existing supervisor service..."
        Stop-Service -Name $SUPERVISOR_SERVICE_NAME -Force -ErrorAction SilentlyContinue
        & sc.exe delete $SUPERVISOR_SERVICE_NAME | Out-Null
        Start-Sleep -Seconds 2
    }
    
    Write-Log "Creating Windows Service for supervisor..."
    $serviceDisplayName = "OpenTelemetry OpAMP Supervisor"
    $serviceDescription = "OpenTelemetry Collector OpAMP Supervisor - Manages collector configuration remotely"
    
    # Store environment variables securely in registry with restricted ACLs
    $serviceEnvRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$SUPERVISOR_SERVICE_NAME\Environment"
    if (-not (Test-Path $serviceEnvRegistryPath)) {
        $regKey = New-Item -Path $serviceEnvRegistryPath -Force
        # Restrict access: Only SYSTEM and Administrators can read
        $acl = $regKey.GetAccessControl()
        $acl.SetAccessRuleProtection($true, $false)
        $systemSid = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
        $adminSid = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
        $systemRule = New-Object System.Security.AccessControl.RegistryAccessRule($systemSid, "ReadKey", "Allow")
        $adminRule = New-Object System.Security.AccessControl.RegistryAccessRule($adminSid, "ReadKey", "Allow")
        $acl.SetAccessRule($systemRule)
        $acl.SetAccessRule($adminRule)
        $regKey.SetAccessControl($acl)
    }
    Set-ItemProperty -Path $serviceEnvRegistryPath -Name "CORALOGIX_PRIVATE_KEY" -Value $env:CORALOGIX_PRIVATE_KEY -Type String -Force | Out-Null
    
    # Create minimal wrapper script that reads from registry (stored in secure location with restricted ACLs)
    $wrapperScriptDir = Join-Path $env:ProgramData "OpenTelemetry\Supervisor"
    New-Item -ItemType Directory -Path $wrapperScriptDir -Force | Out-Null
    $supervisorWrapperScript = Join-Path $wrapperScriptDir "service-wrapper.ps1"
    
    # Wrapper script reads from registry (no secrets embedded)
    $supervisorWrapperContent = @"
# Service wrapper - reads environment variables from secure registry location
`$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\$SUPERVISOR_SERVICE_NAME\Environment'
`$env:CORALOGIX_PRIVATE_KEY = (Get-ItemProperty -Path `$regPath -Name 'CORALOGIX_PRIVATE_KEY' -ErrorAction SilentlyContinue).CORALOGIX_PRIVATE_KEY
& '$SUPERVISOR_BINARY_PATH' --config '$SUPERVISOR_CONFIG_FILE'
"@
    $supervisorWrapperContent | Out-File -FilePath $supervisorWrapperScript -Encoding utf8 -Force
    
    # Restrict wrapper script ACLs: Only SYSTEM and Administrators can read
    $fileAcl = Get-Acl $supervisorWrapperScript
    $fileAcl.SetAccessRuleProtection($true, $false)
    $fileSystemSid = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
    $fileAdminSid = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
    $fileSystemRule = New-Object System.Security.AccessControl.FileSystemAccessRule($fileSystemSid, "ReadAndExecute", "Allow")
    $fileAdminRule = New-Object System.Security.AccessControl.FileSystemAccessRule($fileAdminSid, "ReadAndExecute", "Allow")
    $fileAcl.SetAccessRule($fileSystemRule)
    $fileAcl.SetAccessRule($fileAdminRule)
    Set-Acl -Path $supervisorWrapperScript -AclObject $fileAcl
    
    # Create service using wrapper script
    $supervisorServiceBinPath = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$supervisorWrapperScript`""
    
    & sc.exe create $SUPERVISOR_SERVICE_NAME binPath= "$supervisorServiceBinPath" start= auto DisplayName= "$serviceDisplayName" | Out-Null
    
    # Set service description
    & sc.exe description $SUPERVISOR_SERVICE_NAME "$serviceDescription" | Out-Null
    
    Write-Log "Starting supervisor service..."
    Start-Service -Name $SUPERVISOR_SERVICE_NAME
    
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
    Write-Log "Creating Windows Service..."
    
    $serviceDisplayName = "OpenTelemetry Collector"
    $serviceDescription = "OpenTelemetry Collector - Collects, processes, and exports telemetry data"
    
    $existingService = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
    if ($existingService) {
        Write-Log "Removing existing service..."
        Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
        & sc.exe delete $SERVICE_NAME | Out-Null
        Start-Sleep -Seconds 2
    }
    
    # Store environment variables securely in registry with restricted ACLs
    $serviceEnvRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$SERVICE_NAME\Environment"
    if (-not (Test-Path $serviceEnvRegistryPath)) {
        $regKey = New-Item -Path $serviceEnvRegistryPath -Force
        # Restrict access: Only SYSTEM and Administrators can read
        $acl = $regKey.GetAccessControl()
        $acl.SetAccessRuleProtection($true, $false)
        $systemSid = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
        $adminSid = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
        $systemRule = New-Object System.Security.AccessControl.RegistryAccessRule($systemSid, "ReadKey", "Allow")
        $adminRule = New-Object System.Security.AccessControl.RegistryAccessRule($adminSid, "ReadKey", "Allow")
        $acl.SetAccessRule($systemRule)
        $acl.SetAccessRule($adminRule)
        $regKey.SetAccessControl($acl)
    }
    Set-ItemProperty -Path $serviceEnvRegistryPath -Name "CORALOGIX_PRIVATE_KEY" -Value $env:CORALOGIX_PRIVATE_KEY -Type String -Force | Out-Null
    
    if ($env:CORALOGIX_DOMAIN) {
        Set-ItemProperty -Path $serviceEnvRegistryPath -Name "CORALOGIX_DOMAIN" -Value $env:CORALOGIX_DOMAIN -Type String -Force | Out-Null
    }
    
    # Create minimal wrapper script that reads from registry (stored in secure location with restricted ACLs)
    $wrapperScriptDir = Join-Path $env:ProgramData "OpenTelemetry\Collector"
    New-Item -ItemType Directory -Path $wrapperScriptDir -Force | Out-Null
    $wrapperScript = Join-Path $wrapperScriptDir "service-wrapper.ps1"
    
    # Wrapper script reads from registry (no secrets embedded)
    $wrapperContent = @"
# Service wrapper - reads environment variables from secure registry location
`$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\$SERVICE_NAME\Environment'
`$env:CORALOGIX_PRIVATE_KEY = (Get-ItemProperty -Path `$regPath -Name 'CORALOGIX_PRIVATE_KEY' -ErrorAction SilentlyContinue).CORALOGIX_PRIVATE_KEY
$(if ($env:CORALOGIX_DOMAIN) { "`$env:CORALOGIX_DOMAIN = (Get-ItemProperty -Path `$regPath -Name 'CORALOGIX_DOMAIN' -ErrorAction SilentlyContinue).CORALOGIX_DOMAIN" })
& '$BINARY_PATH' --config '$CONFIG_FILE'
"@
    $wrapperContent | Out-File -FilePath $wrapperScript -Encoding utf8 -Force
    
    # Restrict wrapper script ACLs: Only SYSTEM and Administrators can read
    $fileAcl = Get-Acl $wrapperScript
    $fileAcl.SetAccessRuleProtection($true, $false)
    $fileSystemSid = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
    $fileAdminSid = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
    $fileSystemRule = New-Object System.Security.AccessControl.FileSystemAccessRule($fileSystemSid, "ReadAndExecute", "Allow")
    $fileAdminRule = New-Object System.Security.AccessControl.FileSystemAccessRule($fileAdminSid, "ReadAndExecute", "Allow")
    $fileAcl.SetAccessRule($fileSystemRule)
    $fileAcl.SetAccessRule($fileAdminRule)
    Set-Acl -Path $wrapperScript -AclObject $fileAcl
    
    # Create service using wrapper script
    $serviceBinPath = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$wrapperScript`""
    
    # Create service
    & sc.exe create $SERVICE_NAME binPath= "$serviceBinPath" start= auto DisplayName= "$serviceDisplayName" | Out-Null
    
    # Set service description
    & sc.exe description $SERVICE_NAME "$serviceDescription" | Out-Null
    
    Write-Log "Starting service..."
    Start-Service -Name $SERVICE_NAME
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
            & sc.exe delete $SUPERVISOR_SERVICE_NAME | Out-Null
        }
    }
    else {
        $service = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
        if ($service) {
            Write-Log "Stopping and removing service..."
            Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
            & sc.exe delete $SERVICE_NAME | Out-Null
        }
    }
}

function Remove-PackageWindows {
    if ($Supervisor) {
        if (Test-Path $SUPERVISOR_BINARY_PATH) {
            Write-Log "Removing supervisor binary: $SUPERVISOR_BINARY_PATH"
            Remove-Item -Path $SUPERVISOR_BINARY_PATH -Force -ErrorAction SilentlyContinue
        }
        
        # Remove environment variables from registry
        $serviceEnvRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$SUPERVISOR_SERVICE_NAME\Environment"
        if (Test-Path $serviceEnvRegistryPath) {
            Remove-ItemProperty -Path $serviceEnvRegistryPath -Name "CORALOGIX_PRIVATE_KEY" -ErrorAction SilentlyContinue
            # Remove the Environment subkey if empty
            $remainingProps = Get-ItemProperty -Path $serviceEnvRegistryPath -ErrorAction SilentlyContinue
            if ($remainingProps -and $remainingProps.PSObject.Properties.Count -eq 1) {
                Remove-Item -Path $serviceEnvRegistryPath -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Remove wrapper script
        $wrapperScriptDir = Join-Path $env:ProgramData "OpenTelemetry\Supervisor"
        $supervisorWrapperScript = Join-Path $wrapperScriptDir "service-wrapper.ps1"
        if (Test-Path $supervisorWrapperScript) {
            Write-Log "Removing supervisor wrapper script"
            Remove-Item -Path $supervisorWrapperScript -Force -ErrorAction SilentlyContinue
        }
        
        if (Test-Path "${env:ProgramFiles}\OpenTelemetry\Collector\otelcol-contrib.exe") {
            Write-Log "Removing supervisor collector binary"
            Remove-Item -Path "${env:ProgramFiles}\OpenTelemetry\Collector\otelcol-contrib.exe" -Force -ErrorAction SilentlyContinue
        }
        
        if ($Purge) {
            if (Test-Path $SUPERVISOR_CONFIG_DIR) {
                Write-Log "Removing supervisor config: $SUPERVISOR_CONFIG_DIR"
                Remove-Item -Path $SUPERVISOR_CONFIG_DIR -Recurse -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path $SUPERVISOR_INSTALL_DIR) {
                Write-Log "Removing supervisor install directory: $SUPERVISOR_INSTALL_DIR"
                Remove-Item -Path $SUPERVISOR_INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    else {
        if (Test-Path $BINARY_PATH) {
            Write-Log "Removing binary: $BINARY_PATH"
            Remove-Item -Path $BINARY_PATH -Force -ErrorAction SilentlyContinue
        }
        
        # Remove environment variables from registry
        $serviceEnvRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$SERVICE_NAME\Environment"
        if (Test-Path $serviceEnvRegistryPath) {
            Remove-ItemProperty -Path $serviceEnvRegistryPath -Name "CORALOGIX_PRIVATE_KEY" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $serviceEnvRegistryPath -Name "CORALOGIX_DOMAIN" -ErrorAction SilentlyContinue
            # Remove the Environment subkey if empty
            $remainingProps = Get-ItemProperty -Path $serviceEnvRegistryPath -ErrorAction SilentlyContinue
            if ($remainingProps -and $remainingProps.PSObject.Properties.Count -eq 1) {
                Remove-Item -Path $serviceEnvRegistryPath -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Remove wrapper script
        $wrapperScriptDir = Join-Path $env:ProgramData "OpenTelemetry\Collector"
        $wrapperScript = Join-Path $wrapperScriptDir "service-wrapper.ps1"
        if (Test-Path $wrapperScript) {
            Write-Log "Removing service wrapper script"
            Remove-Item -Path $wrapperScript -Force -ErrorAction SilentlyContinue
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
    }
    
    if ($Config -and -not (Test-Path $Config)) {
        Write-Error "Config file not found: $Config"
    }
    
    $arch = Get-Architecture
    Write-Log "Detected architecture: $arch"
    
    $version = Get-Version
    Write-Log "Installing version: $version"
    
    if ((Test-Installed) -and -not $Upgrade) {
        Write-Warn "Collector is already installed. Use -Upgrade to upgrade, or uninstall first."
        exit 1
    }
    
    if ($Upgrade -and (Test-Installed)) {
        if (-not $Supervisor) {
            Backup-Config
        }
        
        if ($Supervisor -and (Test-Path $BINARY_PATH)) {
            Write-Error "Cannot upgrade: Regular mode is installed. Please uninstall first, then install supervisor mode."
        }
        
        if (-not $Supervisor -and (Test-Path $SUPERVISOR_BINARY_PATH)) {
            Write-Error "Cannot upgrade: Supervisor mode is installed. Please uninstall first, then install regular mode."
        }
    }
    
    if ($Supervisor) {
        # Compute supervisor and collector versions
        $supervisorVer = if ($SupervisorVersion) { $SupervisorVersion } else { $version }
        $collectorVer = if ($CollectorVersion) { $CollectorVersion } else { $version }
        
        if ($CollectorVersion -and $collectorVer -ne $version) {
            Write-Log "Validating collector version: $collectorVer"
            if (-not (Test-Version -Version $collectorVer)) {
                Write-Error "Invalid collector version: $collectorVer"
            }
        }
        
        Write-Log "Supervisor version: $supervisorVer"
        Write-Log "Collector version: $collectorVer"
        
        Install-Supervisor -SupervisorVer $supervisorVer -CollectorVer $collectorVer -Arch $arch
        
        $summary = @"

Installation complete with supervisor mode!

Supervisor Version: $supervisorVer
Collector Version: $collectorVer
Supervisor Service: $SUPERVISOR_SERVICE_NAME
Collector Binary: ${env:ProgramFiles}\OpenTelemetry\Collector\otelcol-contrib.exe
Supervisor Config: $SUPERVISOR_CONFIG_FILE
Collector Config: $SUPERVISOR_COLLECTOR_CONFIG_FILE
Effective Config: $SUPERVISOR_STATE_DIR\effective.yaml

Useful commands:
  Supervisor status:    Get-Service $SUPERVISOR_SERVICE_NAME
  Collector process:    Get-Process otelcol-contrib
  Supervisor logs:      Get-Content $SUPERVISOR_LOG_DIR\opampsupervisor.log -Tail 50 -Wait
  View supervisor config: Get-Content $SUPERVISOR_CONFIG_FILE
  View collector config: Get-Content $SUPERVISOR_COLLECTOR_CONFIG_FILE
  Restart supervisor:    Restart-Service $SUPERVISOR_SERVICE_NAME
  Stop supervisor:       Stop-Service $SUPERVISOR_SERVICE_NAME
  Start supervisor:      Start-Service $SUPERVISOR_SERVICE_NAME

Note: The collector is managed by the supervisor. Configuration updates
will be received from the OpAMP server automatically.

"@
        Write-Host $summary
        return
    }
    
    Install-Collector -Version $version -Arch $arch
    
    if ($Config) {
        Write-Log "Using custom config from: $Config"
        New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null
        Copy-Item -Path $Config -Destination $CONFIG_FILE -Force
    }
    elseif (Test-Path $CONFIG_FILE) {
        Write-Log "Using existing config at: $CONFIG_FILE"
    }
    elseif ($Upgrade -and $script:BackupDir -and (Test-Path $script:BackupDir)) {
        Restore-Config
        if (-not (Test-Path $CONFIG_FILE)) {
            Write-Log "Backup restore failed or backup was empty, creating default config"
            New-EmptyConfig
        }
    }
    else {
        New-EmptyConfig
    }
    
    New-WindowsService
    Test-Service
    
    $summary = @"

Installation complete!

Service: $SERVICE_NAME
Binary: $BINARY_PATH
Config: $CONFIG_FILE

Useful commands:
  Check status:  Get-Service $SERVICE_NAME
  View config:   Get-Content $CONFIG_FILE
  View logs:     Get-EventLog -LogName Application -Source $SERVICE_NAME -Newest 50
  Restart:       Restart-Service $SERVICE_NAME
  Stop:          Stop-Service $SERVICE_NAME
  Start:         Start-Service $SERVICE_NAME

"@
    Write-Host $summary
}

# Run main function
Main

