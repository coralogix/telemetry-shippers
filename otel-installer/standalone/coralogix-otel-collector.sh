#!/usr/bin/env bash
#
# Coralogix OpenTelemetry Collector Installer
# Supports Linux and macOS
#
# One-line installation (sudo is handled automatically):
#   CORALOGIX_DOMAIN="your-domain" CORALOGIX_PRIVATE_KEY="your-key" bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)"
#
# Or with options:
#   curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh | bash -s -- [OPTIONS]
#
# Note: The script will automatically use sudo when needed. You can run it as root or as a regular user.
#
# Options:
#   -v, --version <version>       OTEL Collector version (default: latest from Coralogix Helm chart)
#   -c, --config <path>           Path to custom configuration file (disabled with --supervisor)
#   -s, --supervisor              Install with OpAMP Supervisor mode
#   -u, --upgrade                 Upgrade existing installation
#   --memory-limit <MiB>          Total memory in MiB to allocate to the collector (default: 512)
#                                  Config must reference: ${env:OTEL_MEMORY_LIMIT_MIB}
#                                  (ignored in supervisor mode)
#   --listen-interface <ip>       Network interface for receivers to listen on (default: 127.0.0.1)
#                                  Config must reference: ${env:OTEL_LISTEN_INTERFACE}
#                                  (ignored in supervisor mode)
#   --enable-process-metrics      Enable Linux capabilities for process metrics collection
#                                  Grants CAP_SYS_PTRACE and CAP_DAC_READ_SEARCH to the collector
#                                  Required only if hostMetrics.process.enabled=true in config
#                                  (Linux only, disabled by default for security)
#   --supervisor-version <ver>    Supervisor version (supervisor mode only, default: same as --version)
#   --collector-version <ver>     Collector version (supervisor mode only, default: same as --version)
#   --uninstall                   Uninstall the collector (use --purge to remove all data)
#   --purge                       Remove all data when uninstalling (configuration, state, and logs)
#   -h, --help                    Show this help message
#
# Environment Variables:
#   CORALOGIX_PRIVATE_KEY   Coralogix private key (required)
#   CORALOGIX_DOMAIN        Coralogix domain (required for supervisor mode)
#   CORALOGIX_MACOS_USER_AGENT  Set to "true" to install as user-level LaunchAgent (macOS only)
#                               Default: system-wide LaunchDaemon (requires root)
#

set -euo pipefail

unset VERSION


SCRIPT_NAME="coralogix-otel-collector"
SERVICE_NAME="otelcol-contrib"
BINARY_NAME="otelcol-contrib"
BINARY_PATH_LINUX="/usr/bin/${BINARY_NAME}"

BINARY_PATH_DARWIN="/usr/local/bin/${BINARY_NAME}"
CONFIG_DIR="/etc/otelcol-contrib"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
LOG_DIR="/var/log/otel-collector"

OTEL_RELEASES_BASE_URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases"
OTEL_COLLECTOR_CHECKSUMS_FILE="opentelemetry-collector-releases_otelcol-contrib_checksums.txt"
OTEL_SUPERVISOR_CHECKSUMS_FILE="checksums.txt"
CHART_YAML_URL="https://raw.githubusercontent.com/coralogix/opentelemetry-helm-charts/main/charts/opentelemetry-collector/Chart.yaml"

LAUNCHD_PLIST_DAEMON="/Library/LaunchDaemons/com.coralogix.otelcol.plist"
LAUNCHD_PLIST_AGENT="${HOME}/Library/LaunchAgents/com.coralogix.otelcol.plist"
LAUNCHD_PLIST=""


VERSION="" 
CUSTOM_CONFIG_PATH=""
SUPERVISOR_MODE=false
SUPERVISOR_BASE_CONFIG_PATH=""
UPGRADE_MODE=false
UNINSTALL_MODE=false
PURGE=false
BACKUP_DIR=""
MACOS_INSTALL_TYPE="daemon"
SUPERVISOR_VERSION_FLAG=""
COLLECTOR_VERSION_FLAG=""
MEMORY_LIMIT_MIB="${MEMORY_LIMIT_MIB:-512}"
LISTEN_INTERFACE="${LISTEN_INTERFACE:-127.0.0.1}"
USER_SET_MEMORY_LIMIT=false
USER_SET_LISTEN_INTERFACE=false
ENABLE_PROCESS_METRICS=false

if [ "$UID" = "0" ] || [ "$(id -u)" -eq 0 ]; then
    SUDO_CMD=""
else
    SUDO_CMD="sudo"
fi

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

log() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    exit 1
}

fail() {
    error "$@"
}

check_port() {
    local port="$1"
    local name="$2"
    
    if command -v lsof >/dev/null 2>&1; then
        if lsof -i ":${port}" -sTCP:LISTEN >/dev/null 2>&1; then
            return 1
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
            return 1
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -tuln 2>/dev/null | grep -q ":${port} "; then
            return 1
        fi
    fi
    return 0
}

check_ports() {
    local ports_in_use=""
    
    if ! check_port 4317 "OTLP gRPC"; then
        ports_in_use="${ports_in_use}  - Port 4317 (OTLP gRPC)\n"
    fi
    if ! check_port 4318 "OTLP HTTP"; then
        ports_in_use="${ports_in_use}  - Port 4318 (OTLP HTTP)\n"
    fi
    if ! check_port 13133 "Health Check"; then
        ports_in_use="${ports_in_use}  - Port 13133 (Health Check)\n"
    fi
    
    if [ -n "$ports_in_use" ]; then
        echo ""
        warn "The following ports are already in use:"
        echo -e "$ports_in_use"
        echo "This may cause the collector to fail to start."
        echo ""
        echo "Common causes:"
        echo "  - Another collector instance is running (Docker or standalone)"
        echo "  - Another service is using these ports"
        echo ""
        echo "To check what's using a port: lsof -i :PORT"
        echo ""
        
        if [ ! -t 0 ]; then
            fail "Port conflict detected. Stop conflicting services and retry."
        fi
        
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            fail "Installation cancelled due to port conflicts"
        fi
    fi
}

validate_config_env_vars() {
    local config_file="$1"
    
    if [ "$SUPERVISOR_MODE" = true ]; then
        if [ "$USER_SET_MEMORY_LIMIT" = true ] || [ "$USER_SET_LISTEN_INTERFACE" = true ]; then
            warn "Note: --memory-limit and --listen-interface are ignored in supervisor mode"
            warn "Configuration is managed by the OpAMP server"
        fi
        return 0
    fi
    
    if [ ! -f "$config_file" ] || [ ! -r "$config_file" ]; then
        return 0
    fi
    
    if [ "$USER_SET_MEMORY_LIMIT" = true ]; then
        if ! grep -q "OTEL_MEMORY_LIMIT_MIB" "$config_file"; then
            warn "You specified --memory-limit but the config doesn't reference \${env:OTEL_MEMORY_LIMIT_MIB}"
            warn "The --memory-limit flag will have no effect."
            warn "Update your config to use: limit_mib: \${env:OTEL_MEMORY_LIMIT_MIB}"
        fi
    fi
    
    if [ "$USER_SET_LISTEN_INTERFACE" = true ]; then
        if ! grep -q "OTEL_LISTEN_INTERFACE" "$config_file"; then
            warn "You specified --listen-interface but the config doesn't reference \${env:OTEL_LISTEN_INTERFACE}"
            warn "The --listen-interface flag will have no effect."
            warn "Update your config to use: endpoint: \${env:OTEL_LISTEN_INTERFACE}:<port>"
        fi
    fi
}

usage() {
    cat <<EOF
Coralogix OpenTelemetry Collector Installer

Usage:
    $0 [OPTIONS]

Options:
    -v, --version <version>       OTEL Collector version to install
                                  (default: latest from Coralogix Helm chart)
    -c, --config <path>           Path to custom configuration file
                                  (not available with -s/--supervisor)
    -s, --supervisor              Install with OpAMP Supervisor mode
                                  (config is managed by the OpAMP server)
    -u, --upgrade                 Upgrade existing installation
    --memory-limit <MiB>          Total memory in MiB to allocate to the collector
                                  Sets OTEL_MEMORY_LIMIT_MIB environment variable
                                  Config must reference: \${env:OTEL_MEMORY_LIMIT_MIB}
                                  (default: 512, ignored in supervisor mode)
    --listen-interface <ip>       Network interface for receivers to listen on
                                  Sets OTEL_LISTEN_INTERFACE environment variable
                                  Config must reference: \${env:OTEL_LISTEN_INTERFACE}
                                  (default: 127.0.0.1 for localhost only,
                                   use 0.0.0.0 for all interfaces)
                                  (ignored in supervisor mode)
    --enable-process-metrics      Enable Linux capabilities for process metrics collection
                                  Grants CAP_SYS_PTRACE and CAP_DAC_READ_SEARCH to the collector
                                  Required only if hostMetrics.process.enabled=true in config
                                  (Linux only, disabled by default for security)
    --supervisor-version <ver>    Supervisor version (supervisor mode only)
                                  (default: same as --version)
    --collector-version <ver>     Collector version (supervisor mode only)
                                  (default: same as --version)
    --uninstall                   Uninstall the collector
                                  (use --purge to remove all data)
    --purge                       Remove all data when uninstalling
                                  (must be used with --uninstall)
    -h, --help                    Show this help message

Environment Variables:
    CORALOGIX_PRIVATE_KEY   Coralogix private key (required)
    CORALOGIX_DOMAIN        Coralogix domain (required for supervisor mode)
    CORALOGIX_MACOS_USER_AGENT  Set to "true" to install as user-level LaunchAgent (macOS only)
                                Default: system-wide LaunchDaemon (requires root)

Examples:
    # One-line installation (recommended)
    CORALOGIX_DOMAIN="your-domain" CORALOGIX_PRIVATE_KEY="your-key" bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)"

    # Install specific version
    CORALOGIX_PRIVATE_KEY="your-key" bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" -- -v 0.140.1

    # Install with custom config
    CORALOGIX_PRIVATE_KEY="your-key" bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" -- -c /path/to/config.yaml

    # Install with supervisor
    CORALOGIX_DOMAIN="your-domain" CORALOGIX_PRIVATE_KEY="your-key" bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" -- -s

    # Install with supervisor using specific versions
    CORALOGIX_DOMAIN="your-domain" CORALOGIX_PRIVATE_KEY="your-key" bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" -- -s --supervisor-version 0.140.1 --collector-version 0.140.0

    # Install with external network access (gateway mode - listen on all interfaces)
    CORALOGIX_PRIVATE_KEY="your-key" bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" -- --listen-interface 0.0.0.0

    # Install with custom memory limit and external access
    CORALOGIX_PRIVATE_KEY="your-key" bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" -- --memory-limit 2048 --listen-interface 0.0.0.0

    # Install with process metrics enabled (requires hostMetrics.process.enabled=true in config)
    CORALOGIX_PRIVATE_KEY="your-key" bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" -- --enable-process-metrics

    # Install as user-level LaunchAgent on macOS (runs at login, logs to user directory)
    CORALOGIX_MACOS_USER_AGENT=true bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)"

    # Upgrade existing installation
    CORALOGIX_PRIVATE_KEY="your-key" bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" -- -u

    # Uninstall (keep config/logs)
    bash coralogix-otel-collector.sh --uninstall

    # Uninstall and remove all data
    bash coralogix-otel-collector.sh --uninstall --purge
EOF
}

detect_os() {
    case "$(uname)" in
        Linux)
            echo "linux"
            ;;
        Darwin)
            echo "darwin"
            ;;
        *)
            fail "Unsupported OS: $(uname). Only Linux and macOS are supported."
            ;;
    esac
}

detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            fail "Unsupported architecture: $arch. Only amd64 and arm64 are supported."
            ;;
    esac
}

check_root() {
    if [ "$(id -u)" -eq 0 ]; then
        return 0
    fi
    
    if ! command -v sudo >/dev/null 2>&1; then
        fail "This script requires root privileges. Please run as root or install sudo."
    fi
    
    if sudo -n true 2>/dev/null; then
        return 0
    fi
    
    log "This script requires root privileges. You will be prompted for your password once."
    if ! sudo -v; then
        fail "Unable to obtain sudo privileges. Please ensure you have sudo access."
    fi
}

check_dependencies() {
    local missing=()
    
    for cmd in curl tar; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        fail "Missing required commands: ${missing[*]}. Please install them first."
    fi
}

fetch_default_version() {
    local chart_yaml
    local version
    
    chart_yaml=$(curl -fsSL "$CHART_YAML_URL" 2>/dev/null || echo "")
    
    if [ -z "$chart_yaml" ]; then
        warn "Unable to fetch Chart.yaml from $CHART_YAML_URL"
        echo ""
        echo "This may be due to network connectivity issues or GitHub being unavailable."
        echo ""
        echo "To proceed, please specify the version manually using the --version flag:"
        echo "  $0 --version 0.XXX.X"
        echo ""
        echo "You can find the latest version at appVersion field in the Chart.yaml file:"
        echo "  https://github.com/coralogix/opentelemetry-helm-charts/blob/main/charts/opentelemetry-collector/Chart.yaml"
        echo ""
        return 1
    fi
    
    version=$(echo "$chart_yaml" | grep -E "^appVersion:" | sed -E 's/^appVersion:[[:space:]]*//' | tr -d '[:space:]' || echo "")
    
    if [ -z "$version" ]; then
        warn "Unable to extract appVersion from Chart.yaml"
        echo ""
        echo "Please specify the version manually using the --version flag:"
        echo "  $0 --version 0.XXX.X"
        echo ""
        echo "You can find the latest version at appVersion field in the Chart.yaml file:"
        echo "  https://github.com/coralogix/opentelemetry-helm-charts/blob/main/charts/opentelemetry-collector/Chart.yaml"
        echo ""
        return 1
    fi
    
    echo "$version"
}

validate_version() {
    local version="$1"
    local release_url="${OTEL_RELEASES_BASE_URL}/tag/v${version}"
    local http_code
    
    http_code=$(curl -fsSL -o /dev/null -w "%{http_code}" "$release_url" 2>/dev/null || echo "000")
    
    if [ "$http_code" != "200" ]; then
        warn "Version v${version} not found in OpenTelemetry Collector releases"
        echo ""
        echo "Please verify the version exists at:"
        echo "  ${release_url}"
        echo ""
        echo "You can find available versions at:"
        echo "  ${OTEL_RELEASES_BASE_URL}"
        echo ""
        return 1
    fi
    
    return 0
}

get_version() {
    local version
    
    if [ -n "$VERSION" ]; then
        version="$VERSION"
    elif version=$(fetch_default_version); then
        :
    else
        fail "Version not specified and unable to fetch default version."
    fi
    
    if ! validate_version "$version"; then
        fail "Invalid version: $version"
    fi
    
    echo "$version"
}

detect_pkg_type() {
    if [ ! -r /etc/os-release ]; then
        fail "Cannot detect Linux distribution. /etc/os-release not found."
    fi
    
    . /etc/os-release
    local base="${ID_LIKE:-$ID}"
    local distro_id="${ID:-}"
    
    case "$base" in
        *debian*|*ubuntu*)
            echo "deb"
            ;;
        *rhel*|*fedora*|*centos*|*amzn*|*rocky*|*almalinux*|*ol*|*suse*)
            echo "rpm"
            ;;
        *)
            case "$distro_id" in
                *sles*|*opensuse*|*suse*|*ol*)
                    echo "rpm"
                    ;;
                *)
                    fail "Unsupported Linux distribution: $base ($distro_id). Only Debian/Ubuntu and RPM-based distros (RHEL, CentOS, Fedora, Amazon Linux, Rocky, AlmaLinux, Oracle Linux, SUSE) are supported."
                    ;;
            esac
            ;;
    esac
}

get_timestamp() {
    date '+%Y%m%d-%H%M%S'
}

verify_checksum() {
    local file="$1"
    local expected_checksum="$2"
    local actual_checksum
    
    if [ ! -f "$file" ]; then
        fail "File not found for checksum verification: $file"
    fi
    
    if command -v sha256sum >/dev/null 2>&1; then
        actual_checksum=$(sha256sum "$file" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        actual_checksum=$(shasum -a 256 "$file" | awk '{print $1}')
    else
        warn "Neither sha256sum nor shasum found - skipping checksum verification"
        return 0
    fi
    
    if [ "$expected_checksum" != "$actual_checksum" ]; then
        fail "Checksum verification failed for $(basename "$file")
Expected: $expected_checksum
Actual:   $actual_checksum
The downloaded file may be corrupted or tampered with."
    fi
    
    log "✓ Checksum verified: $(basename "$file")"
    return 0
}

get_otel_checksum() {
    local version="$1"
    local filename="$2"
    local checksums_url="${OTEL_RELEASES_BASE_URL}/download/v${version}/${OTEL_COLLECTOR_CHECKSUMS_FILE}"
    local checksum
    
    checksum=$(curl -fsSL "$checksums_url" 2>/dev/null | grep "  ${filename}$" | awk '{print $1}')
    echo "$checksum"
}

get_supervisor_checksum() {
    local version="$1"
    local filename="$2"
    local checksums_url="${OTEL_RELEASES_BASE_URL}/download/cmd%2Fopampsupervisor%2Fv${version}/${OTEL_SUPERVISOR_CHECKSUMS_FILE}"
    local checksum
    
    checksum=$(curl -fsSL "$checksums_url" 2>/dev/null | grep "  ${filename}$" | awk '{print $1}')
    echo "$checksum"
}

download() {
    local url="$1"
    local dest="$2"
    local expected_checksum="${3:-}"
    
    log "Downloading: $url"
    if ! curl -fL --progress-bar --retry 3 --retry-delay 2 -o "$dest" "$url"; then
        fail "Failed to download: $url"
    fi
    
    if [ -n "$expected_checksum" ]; then
        verify_checksum "$dest" "$expected_checksum"
    fi
}

is_installed() {
    local os
    os=$(detect_os)
    
    case "$os" in
        linux)
            if [ -f "$BINARY_PATH_LINUX" ]; then
                return 0
            fi
            if [ -f "/usr/local/bin/otelcol-contrib" ]; then
                return 0
            fi
            ;;
        darwin)
            if [ -f "$BINARY_PATH_DARWIN" ]; then
                return 0
            fi
            if [ -f "/Library/LaunchDaemons/com.coralogix.otelcol.plist" ]; then
                return 0
            fi
            if [ -f "${HOME}/Library/LaunchAgents/com.coralogix.otelcol.plist" ]; then
                return 0
            fi
            ;;
    esac
    return 1
}

backup_config() {
    if [ -f "$CONFIG_FILE" ] || [ -d "$CONFIG_DIR" ]; then
        local timestamp
        timestamp=$(get_timestamp)
        BACKUP_DIR="/tmp/${SERVICE_NAME}-backup-${timestamp}"
        log "Backing up existing configuration to: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        $SUDO_CMD cp -r "$CONFIG_DIR" "$BACKUP_DIR/" 2>/dev/null || true
        log "Backup created at: $BACKUP_DIR"
    fi
}

restore_config() {
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        if [ -f "${BACKUP_DIR}/$(basename "$CONFIG_DIR")/config.yaml" ]; then
            log "Restoring configuration from backup"
            $SUDO_CMD cp "${BACKUP_DIR}/$(basename "$CONFIG_DIR")/config.yaml" "$CONFIG_FILE" 2>/dev/null || true
        fi
    fi
}

get_empty_collector_config() {
    cat <<'EOF'
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
EOF
}

create_empty_config() {
    log "Creating empty baseline configuration"
    $SUDO_CMD mkdir -p "$CONFIG_DIR"
    
    get_empty_collector_config | $SUDO_CMD tee "$CONFIG_FILE" >/dev/null
    
    $SUDO_CMD chmod 644 "$CONFIG_FILE"
}

install_collector_linux() {
    local version="$1"
    local arch="$2"
    local pkg_type="$3"
    
    local pkg_name
    local pkg_url
    case "$pkg_type" in
        deb)
            pkg_name="${BINARY_NAME}_${version}_linux_${arch}.deb"
            ;;
        rpm)
            pkg_name="${BINARY_NAME}_${version}_linux_${arch}.rpm"
            ;;
        *)
            fail "Unsupported package type: $pkg_type"
            ;;
    esac
    
    pkg_url="${OTEL_RELEASES_BASE_URL}/download/v${version}/${pkg_name}"
    
    log "Downloading OpenTelemetry Collector ${version} (${pkg_type})..."
    local checksum
    checksum=$(get_otel_checksum "$version" "$pkg_name")
    if [ -n "$checksum" ]; then
        download "$pkg_url" "$pkg_name" "$checksum"
    else
        log "Checksum not available - downloading without verification"
        download "$pkg_url" "$pkg_name"
    fi
    
    log "Installing OpenTelemetry Collector package..."
    if [ "$pkg_type" = "deb" ]; then
        $SUDO_CMD dpkg -i "$pkg_name" || $SUDO_CMD apt-get install -f -y
    else
        if [ "$UPGRADE_MODE" = true ]; then
            $SUDO_CMD rpm -U --replacepkgs "$pkg_name" || fail "Failed to upgrade package. Please install dependencies manually."
        else
            if command -v zypper >/dev/null 2>&1; then
                $SUDO_CMD zypper --non-interactive --no-gpg-checks install "$pkg_name"
            elif command -v dnf >/dev/null 2>&1; then
                $SUDO_CMD dnf install -y "$pkg_name"
            elif command -v yum >/dev/null 2>&1; then
                $SUDO_CMD yum install -y "$pkg_name"
            else
                $SUDO_CMD rpm -i "$pkg_name" || fail "Failed to install package. Please install dependencies manually."
            fi
        fi
    fi
    
    if [ ! -x "$BINARY_PATH_LINUX" ]; then
        fail "Binary not found at expected location: $BINARY_PATH_LINUX"
    fi
    
    if ! "$BINARY_PATH_LINUX" --version >/dev/null 2>&1; then
        fail "Installation verification failed"
    fi
    
    if getent group systemd-journal >/dev/null 2>&1; then
        if id otelcol-contrib >/dev/null 2>&1; then
            log "Adding otelcol-contrib user to systemd-journal group for journald log access"
            $SUDO_CMD usermod -a -G systemd-journal otelcol-contrib || warn "Failed to add user to systemd-journal group"
        fi
    fi
    
    if [ "$ENABLE_PROCESS_METRICS" = true ]; then
        configure_process_metrics_permissions "$BINARY_PATH_LINUX" || true
    fi
    
    log "Collector installed successfully: $($BINARY_PATH_LINUX --version)"
}

configure_process_metrics_permissions() {
    local binary_path="$1"
    
    if ! command -v setcap >/dev/null 2>&1; then
        warn "setcap not found. Process metrics may not work correctly."
        warn "Install libcap2-bin (Debian/Ubuntu) or libcap (RHEL/CentOS) to enable process metrics."
        return 1
    fi
    
    log "Configuring Linux capabilities for process metrics..."
    log "This allows the collector to read /proc/[pid]/io for all processes"
    
    # CAP_SYS_PTRACE: Required to read /proc/[pid]/io for other users' processes
    # CAP_DAC_READ_SEARCH: Required to bypass file read permission checks
    # +ep: Effective and Permitted (not Inherited, for security)
    if $SUDO_CMD setcap cap_sys_ptrace,cap_dac_read_search=+ep "$binary_path" 2>/dev/null; then
        log "✓ Linux capabilities configured successfully"
        log "  Process metrics will be able to monitor all system processes"
        return 0
    else
        warn "Failed to set Linux capabilities on $binary_path"
        warn "Process metrics will only monitor processes owned by otelcol-contrib user"
        warn "To enable full process metrics, run: sudo setcap cap_sys_ptrace,cap_dac_read_search=+ep $binary_path"
        return 1
    fi
}

install_collector_darwin() {
    local version="$1"
    local arch="$2"
    
    local darwin_arch
    case "$arch" in
        amd64) darwin_arch="darwin_amd64" ;;
        arm64) darwin_arch="darwin_arm64" ;;
    esac
    
    local tar_name="${BINARY_NAME}_${version}_${darwin_arch}.tar.gz"
    local tar_url="${OTEL_RELEASES_BASE_URL}/download/v${version}/${tar_name}"
    
    local checksum
    checksum=$(get_otel_checksum "$version" "$tar_name")
    if [ -n "$checksum" ]; then
        download "$tar_url" "$tar_name" "$checksum"
    else
        log "Checksum not available - downloading without verification"
        download "$tar_url" "$tar_name"
    fi
    
    log "Extracting collector..."
    tar -xzf "$tar_name" || fail "Failed to extract $tar_name"
    
    if [ ! -x "./${BINARY_NAME}" ]; then
        fail "Binary ${BINARY_NAME} not found in archive"
    fi
    
    log "Installing binary to $BINARY_PATH_DARWIN"
    $SUDO_CMD install -m 0755 "./${BINARY_NAME}" "$BINARY_PATH_DARWIN"
    
    if ! "$BINARY_PATH_DARWIN" --version >/dev/null 2>&1; then
        fail "Installation verification failed"
    fi
    
    log "Collector installed successfully: $($BINARY_PATH_DARWIN --version)"
}


create_launchd_service() {
    local install_type="${MACOS_INSTALL_TYPE:-daemon}"
    local plist_path="$LAUNCHD_PLIST"
    local plist_label="com.coralogix.otelcol"
    
    if [ "$install_type" = "agent" ]; then
        log "Creating user-level LaunchAgent"
        mkdir -p "$(dirname "$plist_path")"
    else
        log "Creating system-wide LaunchDaemon"
    fi
    
    local env_vars="        <key>CORALOGIX_PRIVATE_KEY</key>
        <string>${CORALOGIX_PRIVATE_KEY}</string>
        <key>OTEL_MEMORY_LIMIT_MIB</key>
        <string>${MEMORY_LIMIT_MIB}</string>
        <key>OTEL_LISTEN_INTERFACE</key>
        <string>${LISTEN_INTERFACE}</string>"
    
    if [ -n "${CORALOGIX_DOMAIN:-}" ]; then
        env_vars="${env_vars}
        <key>CORALOGIX_DOMAIN</key>
        <string>${CORALOGIX_DOMAIN}</string>"
    fi

    local temp_plist
    temp_plist="$(mktemp)"
    cat > "$temp_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${plist_label}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BINARY_PATH}</string>
        <string>--config</string>
        <string>${CONFIG_FILE}</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
${env_vars}
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/otel-collector.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/otel-collector.log</string>
</dict>
</plist>
EOF
    
    # Install plist with correct permissions (644, owned by root:wheel for daemon)
    if [ "$install_type" = "agent" ]; then
        install -m 0644 "$temp_plist" "$plist_path"
    else
        $SUDO_CMD install -m 0644 "$temp_plist" "$plist_path"
    fi
    
    # Cleanup temp file
    rm -f "$temp_plist"
}

install_supervisor() {
    local supervisor_ver="$1"
    local collector_ver="$2"
    local arch="$3"
    local pkg_type
    pkg_type=$(detect_pkg_type)
    
    log "Installing OpenTelemetry Collector binary (required for supervisor)..."
    local tar_name="otelcol-contrib_${collector_ver}_linux_${arch}.tar.gz"
    local tar_url="${OTEL_RELEASES_BASE_URL}/download/v${collector_ver}/${tar_name}"
    
    log "Downloading OpenTelemetry Collector ${collector_ver}..."
    local checksum
    checksum=$(get_otel_checksum "$collector_ver" "$tar_name")
    if [ -n "$checksum" ]; then
        download "$tar_url" "$tar_name" "$checksum"
    else
        log "Checksum not available - downloading without verification"
        download "$tar_url" "$tar_name"
    fi
    
    log "Extracting Collector..."
    tar -xzf "$tar_name" >/dev/null 2>&1 || fail "Extraction failed for $tar_name"
    
    if [ ! -x ./otelcol-contrib ]; then
        fail "Expected otelcol-contrib binary after extraction."
    fi
    
    log "Placing Collector binary into /usr/local/bin..."
    $SUDO_CMD install -m 0755 ./otelcol-contrib /usr/local/bin/otelcol-contrib
    
    if [ "$ENABLE_PROCESS_METRICS" = true ]; then
        configure_process_metrics_permissions "/usr/local/bin/otelcol-contrib" || true
    fi

    log "Creating required directories for supervisor..."
    $SUDO_CMD mkdir -p /etc/opampsupervisor
    

    local pkg_name
    local pkg_url
    
    case "$pkg_type" in
        deb)
            pkg_name="opampsupervisor_${supervisor_ver}_linux_${arch}.deb"
            ;;
        rpm)
            pkg_name="opampsupervisor_${supervisor_ver}_linux_${arch}.rpm"
            ;;
        *)
            fail "Unsupported package type: $pkg_type"
            ;;
    esac
    
    pkg_url="${OTEL_RELEASES_BASE_URL}/download/cmd%2Fopampsupervisor%2Fv${supervisor_ver}/${pkg_name}"
    
    local supervisor_checksum
    supervisor_checksum=$(get_supervisor_checksum "$supervisor_ver" "$pkg_name")
    if [ -n "$supervisor_checksum" ]; then
        download "$pkg_url" "$pkg_name" "$supervisor_checksum"
    else
        log "Checksum not available - downloading without verification"
        download "$pkg_url" "$pkg_name"
    fi
    
    log "Installing OpAMP Supervisor ${supervisor_ver}..."
    if [ "$pkg_type" = "deb" ]; then
        $SUDO_CMD dpkg -i "$pkg_name" || $SUDO_CMD apt-get install -f -y
    else
        if [ "$UPGRADE_MODE" = true ]; then
            $SUDO_CMD rpm -U --replacepkgs "$pkg_name" || fail "Failed to upgrade supervisor package. Please install dependencies manually."
        elif command -v zypper >/dev/null 2>&1; then
            $SUDO_CMD zypper --non-interactive --no-gpg-checks install "$pkg_name"
        elif command -v yum >/dev/null 2>&1; then
            $SUDO_CMD yum install -y "$pkg_name"
        elif command -v dnf >/dev/null 2>&1; then
            $SUDO_CMD dnf install -y "$pkg_name"
        else
            $SUDO_CMD rpm -i "$pkg_name" || fail "Failed to install supervisor package. Please install dependencies manually."
        fi
    fi
    
    if getent group systemd-journal >/dev/null 2>&1; then
        if id opampsupervisor >/dev/null 2>&1; then
            log "Adding opampsupervisor user to systemd-journal group for journald log access"
            $SUDO_CMD usermod -a -G systemd-journal opampsupervisor || warn "Failed to add user to systemd-journal group"
        fi
    fi
    
    $SUDO_CMD systemctl stop opampsupervisor 2>/dev/null || true
    
    configure_supervisor
}

configure_supervisor() {
    log "Configuring OpAMP Supervisor..."
    
    local domain="${CORALOGIX_DOMAIN}"
    
    local endpoint_url="https://ingress.${domain}/opamp/v1"

    $SUDO_CMD tee /etc/opampsupervisor/config.yaml >/dev/null <<EOF
server:
  endpoint: "${endpoint_url}"
  headers:
    Authorization: "Bearer \${env:CORALOGIX_PRIVATE_KEY}"
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
  config_files:
    - /etc/opampsupervisor/collector.yaml
  args: []
  env:
    CORALOGIX_PRIVATE_KEY: "\${env:CORALOGIX_PRIVATE_KEY}"
    OTEL_MEMORY_LIMIT_MIB: "\${env:OTEL_MEMORY_LIMIT_MIB}"
    OTEL_LISTEN_INTERFACE: "\${env:OTEL_LISTEN_INTERFACE}"

storage:
  directory: /var/lib/opampsupervisor/

telemetry:
  logs:
    level: debug
    output_paths:
      - /var/log/opampsupervisor/opampsupervisor.log
EOF
    
    if [ -n "$SUPERVISOR_BASE_CONFIG_PATH" ]; then
        log "Using custom base config from: $SUPERVISOR_BASE_CONFIG_PATH"
        $SUDO_CMD cp "$SUPERVISOR_BASE_CONFIG_PATH" /etc/opampsupervisor/collector.yaml
        $SUDO_CMD chmod 644 /etc/opampsupervisor/collector.yaml
        log "Base config will be merged with remote configuration from Fleet Manager"
    else
        log "Using default empty base config"
        get_empty_collector_config | $SUDO_CMD tee /etc/opampsupervisor/collector.yaml >/dev/null
    fi

    if id opampsupervisor >/dev/null 2>&1; then
        log "Setting ownership for supervisor config directory..."
        $SUDO_CMD chown -R opampsupervisor:opampsupervisor /etc/opampsupervisor
        $SUDO_CMD chmod 755 /etc/opampsupervisor
    fi
    
    if [ -f /etc/opampsupervisor/opampsupervisor.conf ]; then
        $SUDO_CMD sed -i '/CORALOGIX_PRIVATE_KEY/d' /etc/opampsupervisor/opampsupervisor.conf
        $SUDO_CMD sed -i '/OTEL_MEMORY_LIMIT_MIB/d' /etc/opampsupervisor/opampsupervisor.conf
        $SUDO_CMD sed -i '/OTEL_LISTEN_INTERFACE/d' /etc/opampsupervisor/opampsupervisor.conf
        $SUDO_CMD sed -i '/OPAMP_OPTIONS/d' /etc/opampsupervisor/opampsupervisor.conf
    fi
    {
        echo "CORALOGIX_PRIVATE_KEY=${CORALOGIX_PRIVATE_KEY}"
        echo "OTEL_MEMORY_LIMIT_MIB=${MEMORY_LIMIT_MIB}"
        echo "OTEL_LISTEN_INTERFACE=${LISTEN_INTERFACE}"
        echo "OPAMP_OPTIONS=--config /etc/opampsupervisor/config.yaml"
    } | $SUDO_CMD tee -a /etc/opampsupervisor/opampsupervisor.conf >/dev/null

    $SUDO_CMD systemctl daemon-reload
    $SUDO_CMD systemctl enable opampsupervisor
    $SUDO_CMD systemctl restart opampsupervisor
    
    log "Supervisor configured and started"
    
    verify_supervisor
}

verify_supervisor() {
    local max_attempts=15
    local attempt=0
    
    log "Verifying supervisor installation..."
    
    while [ $attempt -lt $max_attempts ]; do
        if $SUDO_CMD systemctl is-active --quiet opampsupervisor.service 2>/dev/null; then
            log "Supervisor service is running"
            break
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        warn "Supervisor service may not be running. Check status with: sudo systemctl status opampsupervisor"
        return 1
    fi
    
    sleep 2
    
    attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if pgrep -f "/usr/local/bin/otelcol-contrib.*effective.yaml" >/dev/null 2>&1; then
            log "Collector process is running (managed by supervisor)"
            break
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        warn "Collector process may not be running yet. Supervisor will restart it automatically."
    fi
    
    log "Supervisor verification complete"
}

verify_service() {
    local os="$1"
    local max_attempts=10
    local attempt=0
    
    log "Verifying service is running..."
    
    case "$os" in
        linux)
            while [ $attempt -lt $max_attempts ]; do
                if $SUDO_CMD systemctl is-active --quiet "${SERVICE_NAME}.service" 2>/dev/null; then
                    log "Service is running"
                    return 0
                fi
                sleep 1
                attempt=$((attempt + 1))
            done
            warn "Service may not be running. Check status with: sudo systemctl status ${SERVICE_NAME}"
            ;;
        darwin)
            while [ $attempt -lt $max_attempts ]; do
                if [ "${MACOS_INSTALL_TYPE:-daemon}" = "agent" ]; then
                    if launchctl list 2>/dev/null | grep -q "com.coralogix.otelcol"; then
                        log "Service is running"
                        return 0
                    fi
                else
                    if $SUDO_CMD launchctl list 2>/dev/null | grep -q "com.coralogix.otelcol"; then
                        log "Service is running"
                        return 0
                    fi
                fi
                sleep 1
                attempt=$((attempt + 1))
            done
            if [ "${MACOS_INSTALL_TYPE:-daemon}" = "agent" ]; then
                warn "Service may not be running. Check status with: launchctl list | grep otelcol"
            else
                warn "Service may not be running. Check status with: sudo launchctl list | grep otelcol"
            fi
            ;;
    esac
}

# Uninstall functions
is_supervisor_mode() {
    # Check if opampsupervisor package is installed (most reliable)
    if command -v dpkg >/dev/null 2>&1 && dpkg -s opampsupervisor >/dev/null 2>&1; then
        return 0
    fi
    if command -v rpm >/dev/null 2>&1 && rpm -q opampsupervisor >/dev/null 2>&1; then
        return 0
    fi
    # Fallback: check if supervisor service is active
    if command -v systemctl >/dev/null 2>&1 && systemctl is-active opampsupervisor.service >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

stop_service_linux() {
    if command -v systemctl >/dev/null 2>&1; then
        if is_supervisor_mode; then
            log "Stopping and disabling OpAMP Supervisor service..."
            $SUDO_CMD systemctl stop opampsupervisor.service 2>/dev/null || true
            $SUDO_CMD systemctl disable opampsupervisor.service 2>/dev/null || true
            $SUDO_CMD systemctl daemon-reload
        elif systemctl list-unit-files | grep -q "^${SERVICE_NAME}.service" 2>/dev/null; then
            log "Stopping and disabling service..."
            $SUDO_CMD systemctl stop "${SERVICE_NAME}.service" 2>/dev/null || true
            $SUDO_CMD systemctl disable "${SERVICE_NAME}.service" 2>/dev/null || true
            if [ -f "/etc/systemd/system/${SERVICE_NAME}.service.d/override.conf" ]; then
                log "Removing systemd override file"
                $SUDO_CMD rm -f "/etc/systemd/system/${SERVICE_NAME}.service.d/override.conf"
                $SUDO_CMD rmdir "/etc/systemd/system/${SERVICE_NAME}.service.d" 2>/dev/null || true
            fi
            $SUDO_CMD systemctl daemon-reload
        fi
    fi
}

detect_macos_install_type() {
    if [ -f "$LAUNCHD_PLIST_AGENT" ]; then
        echo "agent"
    elif [ -f "$LAUNCHD_PLIST_DAEMON" ]; then
        echo "daemon"
    else
        if launchctl list 2>/dev/null | grep -q "com.coralogix.otelcol"; then
            echo "agent"
        elif [ -n "$SUDO_CMD" ]; then
            if $SUDO_CMD launchctl print system 2>/dev/null | grep -q "com.coralogix.otelcol"; then
                echo "daemon"
            else
                echo "unknown"
            fi
        else
            if launchctl print system 2>/dev/null | grep -q "com.coralogix.otelcol"; then
                echo "daemon"
            else
                echo "unknown"
            fi
        fi
    fi
}

stop_service_darwin() {
    # Stop LaunchAgent (user-level) using modern bootout
    if [ -f "$LAUNCHD_PLIST_AGENT" ]; then
        log "Stopping LaunchAgent..."
        launchctl bootout "gui/$(id -u)" "$LAUNCHD_PLIST_AGENT" 2>/dev/null || true
    fi
    
    # Stop LaunchDaemon (system-wide) using modern bootout
    if [ -f "$LAUNCHD_PLIST_DAEMON" ]; then
        log "Stopping LaunchDaemon..."
        $SUDO_CMD launchctl bootout system "$LAUNCHD_PLIST_DAEMON" 2>/dev/null || true
    fi
}

remove_package_linux() {
    local pkg_type="$1"
    
    case "$pkg_type" in
        deb)
            if $SUDO_CMD dpkg -s opampsupervisor >/dev/null 2>&1; then
                log "Removing OpAMP Supervisor package..."
                $SUDO_CMD dpkg -r opampsupervisor >/dev/null 2>&1 || warn "Failed to remove opampsupervisor package"
            fi
            ;;
        rpm)
            if $SUDO_CMD rpm -q opampsupervisor >/dev/null 2>&1; then
                log "Removing OpAMP Supervisor package..."
                $SUDO_CMD rpm -e opampsupervisor >/dev/null 2>&1 || warn "Failed to remove opampsupervisor package"
            fi
            ;;
    esac
    
    if [ -f "/usr/local/bin/otelcol-contrib" ]; then
        log "Removing supervisor binary: /usr/local/bin/otelcol-contrib"
        $SUDO_CMD rm -f "/usr/local/bin/otelcol-contrib"
    fi
    
    if [ -d "/etc/systemd/system/opampsupervisor.service.d" ]; then
        log "Removing supervisor systemd override directory"
        $SUDO_CMD rm -rf "/etc/systemd/system/opampsupervisor.service.d"
    fi
    
    if [ "$PURGE" = true ]; then
        if [ -d "/etc/opampsupervisor" ]; then
            log "Removing supervisor config: /etc/opampsupervisor"
            $SUDO_CMD rm -rf "/etc/opampsupervisor"
        fi
        if [ -d "/var/log/opampsupervisor" ]; then
            log "Removing supervisor logs: /var/log/opampsupervisor"
            $SUDO_CMD rm -rf "/var/log/opampsupervisor"
        fi
        if [ -d "/var/lib/opampsupervisor" ]; then
            log "Removing supervisor state: /var/lib/opampsupervisor"
            $SUDO_CMD rm -rf "/var/lib/opampsupervisor"
        fi
    fi
    
    case "$pkg_type" in
        deb)
            if $SUDO_CMD dpkg -s "${SERVICE_NAME}" >/dev/null 2>&1; then
                if [ "$PURGE" = true ]; then
                    log "Removing ${SERVICE_NAME} package and configuration (purge)..."
                    $SUDO_CMD apt-get purge -y "${SERVICE_NAME}" >/dev/null 2>&1 || warn "Failed to purge ${SERVICE_NAME} package"
                else
                    log "Removing ${SERVICE_NAME} package (keeping configuration)..."
                    $SUDO_CMD dpkg -r "${SERVICE_NAME}" >/dev/null 2>&1 || warn "Failed to remove ${SERVICE_NAME} package"
                fi
            else
                warn "${SERVICE_NAME} package not installed (dpkg)"
            fi
            ;;
        rpm)
            if $SUDO_CMD rpm -q "${SERVICE_NAME}" >/dev/null 2>&1; then
                log "Removing ${SERVICE_NAME} package..."
                if command -v zypper >/dev/null 2>&1; then
                    $SUDO_CMD zypper --non-interactive remove "${SERVICE_NAME}" >/dev/null 2>&1 || warn "Failed to remove ${SERVICE_NAME} package (zypper)"
                elif command -v dnf >/dev/null 2>&1; then
                    $SUDO_CMD dnf remove -y "${SERVICE_NAME}" >/dev/null 2>&1 || warn "Failed to remove ${SERVICE_NAME} package (dnf)"
                elif command -v yum >/dev/null 2>&1; then
                    $SUDO_CMD yum remove -y "${SERVICE_NAME}" >/dev/null 2>&1 || warn "Failed to remove ${SERVICE_NAME} package (yum)"
                else
                    $SUDO_CMD rpm -e "${SERVICE_NAME}" >/dev/null 2>&1 || warn "Failed to remove ${SERVICE_NAME} package (rpm)"
                fi
            else
                warn "${SERVICE_NAME} package not installed (rpm)"
            fi
            ;;
        *)
            if [ -f "$BINARY_PATH_LINUX" ]; then
                log "Removing binary directly: $BINARY_PATH_LINUX"
                $SUDO_CMD rm -f "$BINARY_PATH_LINUX"
            fi
            ;;
    esac
    
    if [ -f "/usr/local/bin/otelcol-contrib" ]; then
        log "Removing supervisor binary (leftover from supervisor mode): /usr/local/bin/otelcol-contrib"
        $SUDO_CMD rm -f "/usr/local/bin/otelcol-contrib"
    fi
}

remove_binary() {
    local os="$1"
    
    case "$os" in
        linux)
            return 0
            ;;
        darwin)
            if [ -f "$BINARY_PATH_DARWIN" ]; then
                log "Removing binary: $BINARY_PATH_DARWIN"
                $SUDO_CMD rm -f "$BINARY_PATH_DARWIN"
            else
                warn "Binary not found at: $BINARY_PATH_DARWIN"
            fi
            ;;
    esac
}

remove_launchd_plist() {
    if [ -f "$LAUNCHD_PLIST_AGENT" ]; then
        log "Removing LaunchAgent plist: $LAUNCHD_PLIST_AGENT"
        rm -f "$LAUNCHD_PLIST_AGENT"
    fi
    
    if [ -f "$LAUNCHD_PLIST_DAEMON" ]; then
        log "Removing LaunchDaemon plist: $LAUNCHD_PLIST_DAEMON"
        $SUDO_CMD rm -f "$LAUNCHD_PLIST_DAEMON"
    fi
}

purge_data() {
    if [ "$PURGE" = true ]; then
        log "Removing configuration and log directories..."
        
        if [ -d "$CONFIG_DIR" ]; then
            $SUDO_CMD rm -rf "$CONFIG_DIR"
            log "Removed: $CONFIG_DIR"
        fi
        
        if [ -d "$LOG_DIR" ]; then
            $SUDO_CMD rm -rf "$LOG_DIR"
            log "Removed: $LOG_DIR"
        fi
    else
        log "Configuration and logs preserved (use --purge to remove):"
        [ -d "$CONFIG_DIR" ] && log "  $CONFIG_DIR" || true
        [ -d "$LOG_DIR" ] && log "  $LOG_DIR" || true
    fi
}

uninstall_main() {
    local os
    
    log "Coralogix OpenTelemetry Collector Uninstaller"
    log "=============================================="
    
    check_root
    os=$(detect_os)
    log "Detected OS: $os"
    
    case "$os" in
        linux)
            local pkg_type
            stop_service_linux
            pkg_type=$(detect_pkg_type)
            remove_package_linux "$pkg_type"
            ;;
        darwin)
            stop_service_darwin
            remove_launchd_plist
            remove_binary "$os"
            ;;
    esac
    
    purge_data
    
    cat <<EOF

Uninstall complete!

$(if [ "$PURGE" = true ]; then
    echo "All files, configuration, and logs have been removed."
else
    echo "Binary and service have been removed."
    echo "Configuration and logs have been preserved."
fi)

To reinstall, run the installer script again.

EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -c|--config)
                if [ "$SUPERVISOR_MODE" = true ]; then
                    fail "--config cannot be used with --supervisor. Supervisor mode uses default config and receives configuration from the OpAMP server."
                fi
                CUSTOM_CONFIG_PATH="$2"
                if [ "${CUSTOM_CONFIG_PATH#/}" = "$CUSTOM_CONFIG_PATH" ]; then
                    CUSTOM_CONFIG_PATH="${PWD}/${CUSTOM_CONFIG_PATH}"
                fi
                CUSTOM_CONFIG_PATH=$(cd "$(dirname "$CUSTOM_CONFIG_PATH")" 2>/dev/null && pwd)/$(basename "$CUSTOM_CONFIG_PATH") 2>/dev/null || CUSTOM_CONFIG_PATH="$2"
                shift 2
                ;;
            -s|--supervisor)
                if [ -n "$CUSTOM_CONFIG_PATH" ]; then
                    fail "--supervisor cannot be used with --config. Supervisor mode uses default config and receives configuration from the OpAMP server."
                fi
                SUPERVISOR_MODE=true
                shift
                ;;
            -u|--upgrade)
                UPGRADE_MODE=true
                shift
                ;;
            --memory-limit)
                MEMORY_LIMIT_MIB="$2"
                USER_SET_MEMORY_LIMIT=true
                shift 2
                ;;
            --listen-interface)
                LISTEN_INTERFACE="$2"
                USER_SET_LISTEN_INTERFACE=true
                shift 2
                ;;
            --enable-process-metrics)
                ENABLE_PROCESS_METRICS=true
                shift
                ;;
            --supervisor-version)
                SUPERVISOR_VERSION_FLAG="$2"
                shift 2
                ;;
            --collector-version)
                COLLECTOR_VERSION_FLAG="$2"
                shift 2
                ;;
            --supervisor-base-config)
                SUPERVISOR_BASE_CONFIG_PATH="$2"
                if [ "${SUPERVISOR_BASE_CONFIG_PATH#/}" = "$SUPERVISOR_BASE_CONFIG_PATH" ]; then
                    SUPERVISOR_BASE_CONFIG_PATH="${PWD}/${SUPERVISOR_BASE_CONFIG_PATH}"
                fi
                SUPERVISOR_BASE_CONFIG_PATH=$(cd "$(dirname "$SUPERVISOR_BASE_CONFIG_PATH")" 2>/dev/null && pwd)/$(basename "$SUPERVISOR_BASE_CONFIG_PATH") 2>/dev/null || SUPERVISOR_BASE_CONFIG_PATH="$2"
                shift 2
                ;;
            --uninstall)
                UNINSTALL_MODE=true
                shift
                ;;
            --purge)
                PURGE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

main() {
    local os
    local arch
    local version
    local workdir
    local timestamp
    
    if [ -t 0 ] && [ ! -f "$0" ]; then
        if ! command -v bash >/dev/null 2>&1; then
            fail "bash is required to run this script"
        fi
    fi
    
    log "Coralogix OpenTelemetry Collector Installer"
    log "============================================"
    
    parse_args "$@"
    
    if [ "$UNINSTALL_MODE" = true ]; then
        uninstall_main
        return 0
    fi
    
    if [ "$PURGE" = true ]; then
        fail "--purge must be used with --uninstall"
    fi
    
    if [ -z "${CORALOGIX_PRIVATE_KEY:-}" ]; then
        fail "CORALOGIX_PRIVATE_KEY is required."
    fi
    
    timestamp=$(get_timestamp)
    workdir="/tmp/${SERVICE_NAME}-install-${timestamp}-$$"
    mkdir -p "$workdir"
    trap "rm -rf '${workdir}'" EXIT INT TERM HUP
    cd "$workdir"
    
    os=$(detect_os)
    arch=$(detect_arch)
    
    case "$os" in
        linux)
            BINARY_PATH="$BINARY_PATH_LINUX"
            ;;
        darwin)
            BINARY_PATH="$BINARY_PATH_DARWIN"
            if [ "${CORALOGIX_MACOS_USER_AGENT:-}" = "true" ]; then
                MACOS_INSTALL_TYPE="agent"
                LAUNCHD_PLIST="$LAUNCHD_PLIST_AGENT"
                LOG_DIR="${HOME}/Library/Logs/otel-collector"
                log "macOS: Installing as user-level LaunchAgent (runs at login)"
            else
                MACOS_INSTALL_TYPE="daemon"
                LAUNCHD_PLIST="$LAUNCHD_PLIST_DAEMON"
                log "macOS: Installing as system-wide LaunchDaemon (runs at boot, requires root)"
            fi
            ;;
    esac
    
    log "Detected OS: $os"
    log "Detected architecture: $arch"
    
    if [ "$SUPERVISOR_MODE" = true ] && [ -n "$CUSTOM_CONFIG_PATH" ]; then
        fail "--config cannot be used with --supervisor. Supervisor mode uses default config and receives configuration from the OpAMP server."
    fi
    
    if [ "$SUPERVISOR_MODE" = true ]; then
        if [ "$os" != "linux" ]; then
            fail "Supervisor mode is currently only supported on Linux"
        fi
        if [ -z "${CORALOGIX_DOMAIN:-}" ]; then
            fail "CORALOGIX_DOMAIN is required for supervisor mode"
        fi
    else
        # --supervisor-version and --collector-version only valid with --supervisor
        if [ -n "$SUPERVISOR_VERSION_FLAG" ]; then
            fail "--supervisor-version can only be used with -s/--supervisor"
        fi
        if [ -n "$COLLECTOR_VERSION_FLAG" ]; then
            fail "--collector-version can only be used with -s/--supervisor"
        fi
        if [ -n "$SUPERVISOR_BASE_CONFIG_PATH" ]; then
            fail "--supervisor-base-config can only be used with -s/--supervisor"
        fi
    fi
    
    if [ -n "$CUSTOM_CONFIG_PATH" ] && [ ! -f "$CUSTOM_CONFIG_PATH" ]; then
        fail "Config file not found: $CUSTOM_CONFIG_PATH"
    fi
    
    if [ -n "$SUPERVISOR_BASE_CONFIG_PATH" ]; then
        if [ ! -f "$SUPERVISOR_BASE_CONFIG_PATH" ]; then
            fail "Supervisor base config file not found: $SUPERVISOR_BASE_CONFIG_PATH"
        fi
        
        if grep -vE '^\s*#' "$SUPERVISOR_BASE_CONFIG_PATH" | grep -qE '^\s*opamp:'; then
            fail "Supervisor base config cannot contain 'opamp' extension. The supervisor manages the OpAMP connection.
Remove the 'opamp' extension from your config file: $SUPERVISOR_BASE_CONFIG_PATH"
        fi
        
        log "Using custom base config for supervisor: $SUPERVISOR_BASE_CONFIG_PATH"
    fi
    
    check_root
    check_dependencies
    
    version=$(get_version)
    log "Installing version: $version"
    
    if is_installed && [ "$UPGRADE_MODE" != true ]; then
        warn "Collector is already installed. Use --upgrade to upgrade, or uninstall first."
        exit 1
    fi
    
    if [ "$UPGRADE_MODE" != true ]; then
        check_ports
    fi
    
    if [ "$UPGRADE_MODE" = true ] && is_installed; then
        if [ "$SUPERVISOR_MODE" != true ]; then
            backup_config
        fi
        
        if command -v systemctl >/dev/null 2>&1; then
            if [ "$SUPERVISOR_MODE" != true ] && [ -f "/usr/local/bin/otelcol-contrib" ]; then
                fail "Cannot upgrade: Supervisor mode is installed. Please uninstall first, then install regular mode."
            fi
            
            if [ "$SUPERVISOR_MODE" = true ] && [ -f "$BINARY_PATH_LINUX" ]; then
                fail "Cannot upgrade: Regular mode is installed. Please uninstall first, then install supervisor mode."
            fi
        fi
    fi
    
    if [ "$SUPERVISOR_MODE" = true ]; then
        # Compute supervisor and collector versions
        # Both default to VERSION (from --version or Helm chart)
        # --supervisor-version overrides supervisor version only
        # --collector-version overrides collector version only
        local supervisor_ver="${SUPERVISOR_VERSION_FLAG:-$version}"
        local collector_ver="${COLLECTOR_VERSION_FLAG:-$version}"
        
        # Note: Supervisor version is not validated here as it has a different release path
        # Invalid supervisor versions will fail at download time
        if [ -n "$COLLECTOR_VERSION_FLAG" ] && [ "$collector_ver" != "$version" ]; then
            log "Validating collector version: $collector_ver"
            if ! validate_version "$collector_ver"; then
                fail "Invalid collector version: $collector_ver"
            fi
        fi
        
        log "Supervisor version: $supervisor_ver"
        log "Collector version: $collector_ver"
        
        install_supervisor "$supervisor_ver" "$collector_ver" "$arch"
        
        cat <<EOF

Installation complete with supervisor mode!

Supervisor Version: $supervisor_ver
Collector Version: $collector_ver
Supervisor Service: opampsupervisor
Collector Binary: /usr/local/bin/otelcol-contrib
Supervisor Config: /etc/opampsupervisor/config.yaml
Collector Config: /etc/opampsupervisor/collector.yaml
Effective Config: /var/lib/opampsupervisor/effective.yaml

Useful commands:
  Supervisor status:    systemctl status opampsupervisor
  Collector process:    ps aux | grep otelcol-contrib
  Supervisor logs:      journalctl -u opampsupervisor -f
  Supervisor log file:  tail -f /var/log/opampsupervisor/opampsupervisor.log
  View supervisor config: cat /etc/opampsupervisor/config.yaml
  View collector config: cat /etc/opampsupervisor/collector.yaml
  View effective config: cat /var/lib/opampsupervisor/effective.yaml
  Restart supervisor:    systemctl restart opampsupervisor
  Stop supervisor:       systemctl stop opampsupervisor
  Start supervisor:      systemctl start opampsupervisor

Note: The collector is managed by the supervisor. Configuration updates
will be received from the OpAMP server automatically.
EOF
        
        if [ -n "$SUPERVISOR_BASE_CONFIG_PATH" ]; then
            cat <<EOF

Custom Base Config:
  Source: $SUPERVISOR_BASE_CONFIG_PATH
  Installed: /etc/opampsupervisor/collector.yaml
  
The base config is merged with remote configuration from Fleet Manager.
The effective merged configuration is at: /var/lib/opampsupervisor/effective.yaml

EOF
        else
            echo ""
        fi
        
        return 0
    fi
    
    case "$os" in
        linux)
            local pkg_type
            pkg_type=$(detect_pkg_type)
            install_collector_linux "$version" "$arch" "$pkg_type"
            ;;
        darwin)
            install_collector_darwin "$version" "$arch"
            ;;
    esac
    
    if [ -n "$CUSTOM_CONFIG_PATH" ]; then
        log "Using custom config from: $CUSTOM_CONFIG_PATH"
        $SUDO_CMD mkdir -p "$CONFIG_DIR"
        $SUDO_CMD cp "$CUSTOM_CONFIG_PATH" "$CONFIG_FILE"
        $SUDO_CMD chmod 644 "$CONFIG_FILE"
    elif [ -f "$CONFIG_FILE" ]; then
        log "Using existing config at: $CONFIG_FILE"
    elif [ "$UPGRADE_MODE" = true ] && [ -n "${BACKUP_DIR:-}" ] && [ -d "$BACKUP_DIR" ]; then
        restore_config
        if [ ! -f "$CONFIG_FILE" ]; then
            log "Backup restore failed or backup was empty, creating default config"
            create_empty_config
        fi
    else
        create_empty_config
    fi
    
    # Validate that config references the env vars if user set them
    validate_config_env_vars "$CONFIG_FILE"
    
    case "$os" in
        linux)
            $SUDO_CMD mkdir -p /var/lib/otelcol
            $SUDO_CMD chown otelcol-contrib:otelcol-contrib /var/lib/otelcol 2>/dev/null || true
            
            log "Configuring service environment variables"
            $SUDO_CMD mkdir -p "/etc/systemd/system/${SERVICE_NAME}.service.d"
            
            # Build environment lines
            local env_lines="Environment=\"OTELCOL_OPTIONS=--config ${CONFIG_FILE}\""
            env_lines="${env_lines}
Environment=\"CORALOGIX_PRIVATE_KEY=${CORALOGIX_PRIVATE_KEY}\""
            env_lines="${env_lines}
Environment=\"OTEL_MEMORY_LIMIT_MIB=${MEMORY_LIMIT_MIB}\""
            env_lines="${env_lines}
Environment=\"OTEL_LISTEN_INTERFACE=${LISTEN_INTERFACE}\""
            
            if [ -n "${CORALOGIX_DOMAIN:-}" ]; then
                env_lines="${env_lines}
Environment=\"CORALOGIX_DOMAIN=${CORALOGIX_DOMAIN}\""
            fi
            
            $SUDO_CMD tee "/etc/systemd/system/${SERVICE_NAME}.service.d/override.conf" >/dev/null <<EOF
[Service]
${env_lines}
EOF
            
            $SUDO_CMD systemctl daemon-reload
            $SUDO_CMD systemctl enable "${SERVICE_NAME}.service"
            log "Starting service..."
            $SUDO_CMD systemctl restart "${SERVICE_NAME}.service"
            ;;
        darwin)
            if [ "$MACOS_INSTALL_TYPE" = "agent" ]; then
                mkdir -p "$LOG_DIR"
            else
                $SUDO_CMD mkdir -p "$LOG_DIR"
            fi
            create_launchd_service
            log "Starting service..."
            if [ "$MACOS_INSTALL_TYPE" = "agent" ]; then
                launchctl bootout "gui/$(id -u)" "$LAUNCHD_PLIST" 2>/dev/null || true
                launchctl bootstrap "gui/$(id -u)" "$LAUNCHD_PLIST"
            else
                $SUDO_CMD launchctl bootout system "$LAUNCHD_PLIST" 2>/dev/null || true
                $SUDO_CMD launchctl bootstrap system "$LAUNCHD_PLIST"
            fi
            ;;
    esac
    
    verify_service "$os"
    
    cat <<EOF

Installation complete!

Service: ${SERVICE_NAME}
Binary: ${BINARY_PATH}
Config: ${CONFIG_FILE}

EOF
    
    case "$os" in
        linux)
            cat <<EOF
Useful commands:
  Check status:  systemctl status ${SERVICE_NAME}
  View config:   cat ${CONFIG_FILE}
  View logs:     journalctl -u ${SERVICE_NAME} -f
  Restart:       systemctl restart ${SERVICE_NAME}
  Stop:          systemctl stop ${SERVICE_NAME}
  Start:         systemctl start ${SERVICE_NAME}

EOF
            ;;
        darwin)
            if [ "${MACOS_INSTALL_TYPE:-daemon}" = "agent" ]; then
                cat <<EOF
Useful commands (LaunchAgent - user-level):
  Check status:  launchctl list | grep otelcol
  View config:   cat ${CONFIG_FILE}
  View logs:     tail -f ${LOG_DIR}/otel-collector.log
  Stop:          launchctl bootout gui/\$(id -u) ${LAUNCHD_PLIST_AGENT}
  Start:         launchctl bootstrap gui/\$(id -u) ${LAUNCHD_PLIST_AGENT}
  Restart:       launchctl bootout gui/\$(id -u) ${LAUNCHD_PLIST_AGENT}; launchctl bootstrap gui/\$(id -u) ${LAUNCHD_PLIST_AGENT}

EOF
            else
                cat <<EOF
Useful commands (LaunchDaemon - system-wide):
  Check status:  sudo launchctl list | grep otelcol
  View config:   cat ${CONFIG_FILE}
  View logs:     tail -f ${LOG_DIR}/otel-collector.log
  Stop:          sudo launchctl bootout system ${LAUNCHD_PLIST_DAEMON}
  Start:         sudo launchctl bootstrap system ${LAUNCHD_PLIST_DAEMON}
  Restart:       sudo launchctl bootout system ${LAUNCHD_PLIST_DAEMON}; sudo launchctl bootstrap system ${LAUNCHD_PLIST_DAEMON}

EOF
            fi
            ;;
    esac
}

main "$@"

