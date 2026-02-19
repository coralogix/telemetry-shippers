#!/bin/bash
# Coralogix OpenTelemetry Collector - Docker Installation Script
#
# One-line installation:
#   CORALOGIX_PRIVATE_KEY="your-key" bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/docker-install.sh)" -- -c /path/to/config.yaml
#
# Supervisor mode:
#   CORALOGIX_DOMAIN="your-domain" CORALOGIX_PRIVATE_KEY="your-key" bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/docker-install.sh)" -- --supervisor
#
# Environment Variables:
#   CORALOGIX_PRIVATE_KEY   Coralogix private key (required)
#   CORALOGIX_DOMAIN        Coralogix domain (required for supervisor mode)

set -euo pipefail


COLLECTOR_IMAGE="otel/opentelemetry-collector-contrib"
SUPERVISOR_IMAGE="coralogixrepo/otel-supervised-collector"

CONTAINER_NAME="coralogix-otel-collector"
CONFIG_HOST_DIR="${HOME}/.coralogix-otel-collector"
CONFIG_CONTAINER_DIR="/etc/otelcol-contrib"

OTLP_GRPC_PORT="${OTLP_GRPC_PORT:-4317}"
OTLP_HTTP_PORT="${OTLP_HTTP_PORT:-4318}"
HEALTH_CHECK_PORT="${HEALTH_CHECK_PORT:-13133}"

VERSION=""
SUPERVISOR_VERSION=""
COLLECTOR_VERSION=""
SUPERVISOR_MODE=false
CUSTOM_CONFIG_PATH=""
SUPERVISOR_BASE_CONFIG_PATH=""
DETACHED=true

MEMORY_LIMIT_MIB="${MEMORY_LIMIT_MIB:-512}"
USER_SET_MEMORY_LIMIT=false

CHART_YAML_URL="https://raw.githubusercontent.com/coralogix/opentelemetry-helm-charts/main/charts/opentelemetry-collector/Chart.yaml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

fetch_default_version() {
    local chart_yaml
    local version
    
    chart_yaml=$(curl -fsSL "$CHART_YAML_URL" 2>/dev/null || echo "")
    
    if [ -z "$chart_yaml" ]; then
        warn "Unable to fetch Chart.yaml from $CHART_YAML_URL"
        echo ""
        echo "To proceed, please specify the version manually using the --version flag:"
        echo "  $0 --version 0.XXX.X"
        echo ""
        return 1
    fi
    
    version=$(echo "$chart_yaml" | grep -E "^appVersion:" | sed -E 's/^appVersion:[[:space:]]*//' | tr -d '[:space:]' || echo "")
    
    if [ -z "$version" ]; then
        warn "Could not parse appVersion from Chart.yaml"
        return 1
    fi
    
    echo "$version"
}

get_version() {
    local version=""
    
    if [ -n "$VERSION" ]; then
        version="$VERSION"
    elif version=$(fetch_default_version); then
        log "Using version from Helm chart: ${version}" >&2
    else
        fail "Version not specified and unable to fetch default version. Use --version to specify."
    fi
    
    echo "$version"
}

usage() {
    cat <<EOF
Coralogix OpenTelemetry Collector - Docker Installation

Usage: $0 [OPTIONS]

Options:
    -v, --version <version>     Default version for images (default: from Helm chart)
    --collector-version <ver>   Collector image version (regular mode)
    --supervisor-version <ver>  Supervisor image version (supervisor mode)
    -c, --config <path>         Path to custom configuration file
    -s, --supervisor            Use supervisor mode (requires CORALOGIX_DOMAIN)
    --memory-limit <MiB>        Total memory in MiB to allocate to the collector (default: 512)
                                Config must reference: ${env:OTEL_MEMORY_LIMIT_MIB}
                                (ignored in supervisor mode)
    --supervisor-base-config <path>  Path to base collector config for supervisor mode
                                      Merged with remote config from Fleet Manager
                                      (supervisor mode only)
    -f, --foreground            Run in foreground (default: detached)
    --uninstall                 Stop and remove the container
    -h, --help                  Show this help message

Environment Variables (Required):
    CORALOGIX_PRIVATE_KEY   Coralogix private key
    CORALOGIX_DOMAIN        Coralogix domain (required for supervisor mode)

Environment Variables (Optional):
    OTLP_GRPC_PORT          Host port for OTLP gRPC (default: 4317)
    OTLP_HTTP_PORT          Host port for OTLP HTTP (default: 4318)
    HEALTH_CHECK_PORT       Host port for health check (default: 13133)
    MEMORY_LIMIT_MIB        Memory limit in MiB (default: 512)
                            Config must reference: \${env:OTEL_MEMORY_LIMIT_MIB}
                            (can also be set via --memory-limit flag)

Examples:
    # Basic installation with custom config
    CORALOGIX_PRIVATE_KEY="your-key" $0 -c /path/to/config.yaml

    # Supervisor mode (config managed remotely)
    CORALOGIX_DOMAIN="us1.coralogix.com" CORALOGIX_PRIVATE_KEY="your-key" $0 -s

    # Gateway mode with custom memory
    CORALOGIX_PRIVATE_KEY="your-key" $0 -c config.yaml --memory-limit 2048

    # Custom ports
    OTLP_GRPC_PORT=14317 OTLP_HTTP_PORT=14318 CORALOGIX_PRIVATE_KEY="your-key" $0 -c config.yaml

    # Install specific version
    CORALOGIX_PRIVATE_KEY="your-key" $0 -c config.yaml --version 0.140.1

    # Stop the container
    $0 --stop
EOF
    exit 0
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            --collector-version)
                COLLECTOR_VERSION="$2"
                shift 2
                ;;
            --supervisor-version)
                SUPERVISOR_VERSION="$2"
                shift 2
                ;;
            -c|--config)
                if [ "$SUPERVISOR_MODE" = true ]; then
                    fail "--config cannot be used with --supervisor. Supervisor mode uses default config and receives configuration from the OpAMP server."
                fi
                if [ -f "$2" ]; then
                CUSTOM_CONFIG_PATH="$(realpath "$2")"
                else
                    fail "Config file not found: $2"
                fi
                shift 2
                ;;
            -s|--supervisor)
                if [ -n "$CUSTOM_CONFIG_PATH" ]; then
                    fail "--supervisor cannot be used with --config. Supervisor mode uses default config and receives configuration from the OpAMP server."
                fi
                SUPERVISOR_MODE=true
                shift
                ;;
            --memory-limit)
                MEMORY_LIMIT_MIB="$2"
                USER_SET_MEMORY_LIMIT=true
                shift 2
                ;;
            -f|--foreground)
                DETACHED=false
                shift
                ;;
            --supervisor-base-config)
                if [ -f "$2" ]; then
                SUPERVISOR_BASE_CONFIG_PATH="$(realpath "$2")"
                else
                    fail "Supervisor base config file not found: $2"
                fi
                shift 2
                ;;
            --stop|--uninstall)
                stop_container
                exit 0
                ;;
            -h|--help)
                usage
                ;;
            --)
                shift
                ;;
            *)
                fail "Unknown option: $1. Use --help for usage."
                ;;
        esac
    done
}

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        fail "Docker is not installed. Please install Docker first."
    fi
    
    if ! docker info >/dev/null 2>&1; then
        fail "Docker daemon is not running or you don't have permission to access it."
    fi
}

validate_config_env_vars() {
    local config_file="$1"
    
    if [ "$SUPERVISOR_MODE" = true ]; then
        if [ "$USER_SET_MEMORY_LIMIT" = true ]; then
            warn "Note: --memory-limit is ignored in supervisor mode"
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
}

check_port() {
    local port="$1"
    local name="$2"
    
    if docker ps -q --filter "name=^${CONTAINER_NAME}$" | grep -q .; then
        return 0
    fi
    
    if command -v lsof >/dev/null 2>&1; then
        if lsof -i ":${port}" >/dev/null 2>&1; then
            fail "Port ${port} (${name}) is already in use. Set ${name}_PORT environment variable to use a different port."
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
            fail "Port ${port} (${name}) is already in use. Set ${name}_PORT environment variable to use a different port."
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -tuln 2>/dev/null | grep -q ":${port} "; then
            fail "Port ${port} (${name}) is already in use. Set ${name}_PORT environment variable to use a different port."
        fi
    fi
}

check_ports() {
    check_port "$OTLP_GRPC_PORT" "OTLP_GRPC"
    check_port "$OTLP_HTTP_PORT" "OTLP_HTTP"
    check_port "$HEALTH_CHECK_PORT" "HEALTH_CHECK"
}

stop_container() {
    log "Stopping container: ${CONTAINER_NAME}"
    docker stop "${CONTAINER_NAME}" 2>/dev/null || true
    docker rm "${CONTAINER_NAME}" 2>/dev/null || true
    log "Container stopped and removed"
}

get_default_config() {
    cat <<'EOF'
receivers:
  nop:

exporters:
  nop:

extensions:
  health_check:
    endpoint: 0.0.0.0:13133

processors:
  memory_limiter:
    check_interval: 5s
    limit_mib: ${env:OTEL_MEMORY_LIMIT_MIB:-512}

service:
  extensions: [health_check]
  pipelines:
    traces:
      receivers: [nop]
      processors: [memory_limiter]
      exporters: [nop]
    metrics:
      receivers: [nop]
      processors: [memory_limiter]
      exporters: [nop]
    logs:
      receivers: [nop]
      processors: [memory_limiter]
      exporters: [nop]
EOF
}

create_config_dir() {
    mkdir -p "$CONFIG_HOST_DIR"
    
    if [ -n "$CUSTOM_CONFIG_PATH" ]; then
        if [ ! -f "$CUSTOM_CONFIG_PATH" ]; then
            fail "Config file not found: $CUSTOM_CONFIG_PATH"
        fi
        cp "$CUSTOM_CONFIG_PATH" "${CONFIG_HOST_DIR}/config.yaml"
        log "Config copied to: ${CONFIG_HOST_DIR}/config.yaml"
    elif [ ! -f "${CONFIG_HOST_DIR}/config.yaml" ]; then
        get_default_config > "${CONFIG_HOST_DIR}/config.yaml"
        log "Created default config at: ${CONFIG_HOST_DIR}/config.yaml"
    else
        log "Using existing config at: ${CONFIG_HOST_DIR}/config.yaml"
    fi
}

run_regular_mode() {
    local default_version
    default_version=$(get_version)
    local image_tag="${COLLECTOR_VERSION:-${default_version}}"
    local image="${COLLECTOR_IMAGE}:${image_tag}"
    
    log "Pulling image: ${image}"
    docker pull "$image"
    
    # Create persistent config directory
    create_config_dir
    
    log "Starting collector container..."
    
    local docker_args=(
        --name "${CONTAINER_NAME}"
        --restart unless-stopped
        -e "CORALOGIX_PRIVATE_KEY=${CORALOGIX_PRIVATE_KEY}"
        -e "OTEL_MEMORY_LIMIT_MIB=${MEMORY_LIMIT_MIB}"
        -v "${CONFIG_HOST_DIR}/config.yaml:${CONFIG_CONTAINER_DIR}/config.yaml:ro"
        -p "${OTLP_GRPC_PORT}:4317"
        -p "${OTLP_HTTP_PORT}:4318"
        -p "${HEALTH_CHECK_PORT}:13133"
    )
    
    if [ -n "${CORALOGIX_DOMAIN:-}" ]; then
        docker_args+=(-e "CORALOGIX_DOMAIN=${CORALOGIX_DOMAIN}")
    fi
    
    if [ "$DETACHED" = true ]; then
        docker_args+=(-d)
    fi
    
    # Remove existing container if present
    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
    
    docker run "${docker_args[@]}" "$image"
    
    if [ "$DETACHED" = true ]; then
        log "Container started successfully"
        print_summary
    fi
}

get_supervisor_config() {
    local domain="$1"
    cat <<EOF
server:
  endpoint: "https://ingress.${domain}/opamp/v1"
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
  executable: /otelcol-contrib
  passthrough_logs: true

  description:
    non_identifying_attributes:
      service.name: "opentelemetry-collector"
      cx.agent.type: "docker"

  config_files:
    - /etc/otelcol-contrib/config.yaml

  args: []

  env:
    CORALOGIX_PRIVATE_KEY: "\${env:CORALOGIX_PRIVATE_KEY}"
    OTEL_MEMORY_LIMIT_MIB: "\${env:OTEL_MEMORY_LIMIT_MIB}"

storage:
  directory: /etc/otelcol-contrib/supervisor-data/

telemetry:
  logs:
    level: info
EOF
}

run_supervisor_mode() {
    local default_version
    default_version=$(get_version)
    local image_tag="${SUPERVISOR_VERSION:-${default_version}}"
    local image="${SUPERVISOR_IMAGE}:${image_tag}"
    
    log "Pulling image: ${image}"
    docker pull "$image"
    
    # Create persistent config directory
    mkdir -p "$CONFIG_HOST_DIR"
    
    # Create supervisor config
    get_supervisor_config "${CORALOGIX_DOMAIN}" > "${CONFIG_HOST_DIR}/supervisor.yaml"
    log "Supervisor config at: ${CONFIG_HOST_DIR}/supervisor.yaml"
    
    # Create collector config
    if [ -n "$SUPERVISOR_BASE_CONFIG_PATH" ]; then
        cp "$SUPERVISOR_BASE_CONFIG_PATH" "${CONFIG_HOST_DIR}/config.yaml"
        log "Using custom base config: $SUPERVISOR_BASE_CONFIG_PATH"
    else
        get_default_config > "${CONFIG_HOST_DIR}/config.yaml"
        log "Using default base config"
    fi
    log "Collector config at: ${CONFIG_HOST_DIR}/config.yaml"
    
    log "Starting supervisor container..."
    
    local docker_args=(
        --name "${CONTAINER_NAME}"
        --restart unless-stopped
        -e "CORALOGIX_PRIVATE_KEY=${CORALOGIX_PRIVATE_KEY}"
        -e "OTEL_MEMORY_LIMIT_MIB=${MEMORY_LIMIT_MIB}"
        -v "${CONFIG_HOST_DIR}/supervisor.yaml:${CONFIG_CONTAINER_DIR}/supervisor.yaml:ro"
        -v "${CONFIG_HOST_DIR}/config.yaml:${CONFIG_CONTAINER_DIR}/config.yaml:ro"
        -p "${OTLP_GRPC_PORT}:4317"
        -p "${OTLP_HTTP_PORT}:4318"
        -p "${HEALTH_CHECK_PORT}:13133"
    )
    
    if [ "$DETACHED" = true ]; then
        docker_args+=(-d)
    fi
    
    # Remove existing container if present
    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
    
    docker run "${docker_args[@]}" "$image" --config ${CONFIG_CONTAINER_DIR}/supervisor.yaml
    
    if [ "$DETACHED" = true ]; then
        log "Supervisor container started successfully"
        print_summary
    fi
}

print_summary() {
    cat <<EOF

============================================
Installation Complete!
============================================

Container: ${CONTAINER_NAME}
Config Dir: ${CONFIG_HOST_DIR}

Useful Commands:
    # View logs
    docker logs -f ${CONTAINER_NAME}

    # Check status
    docker ps | grep ${CONTAINER_NAME}

    # Health check
    curl -s http://localhost:${HEALTH_CHECK_PORT}/health | jq .

    # Stop container
    docker stop ${CONTAINER_NAME}

    # Remove container
    docker rm ${CONTAINER_NAME}

    # Restart container
    docker restart ${CONTAINER_NAME}

Exposed Ports:
    ${OTLP_GRPC_PORT}  - OTLP gRPC receiver
    ${OTLP_HTTP_PORT}  - OTLP HTTP receiver
    ${HEALTH_CHECK_PORT} - Health check endpoint

EOF

    if [ "$SUPERVISOR_MODE" = true ]; then
        echo "Mode: Supervisor (Fleet Management enabled)"
        echo "Domain: ${CORALOGIX_DOMAIN}"
    else
        echo "Mode: Regular"
        echo "Config: ${CONFIG_HOST_DIR}/config.yaml"
    fi
    echo ""
}

main() {
    log "Coralogix OpenTelemetry Collector - Docker Installer"
    log "===================================================="
    
    parse_args "$@"
    
    if [ -z "${CORALOGIX_PRIVATE_KEY:-}" ]; then
        fail "CORALOGIX_PRIVATE_KEY is required"
    fi
    
    if [ "$SUPERVISOR_MODE" = true ]; then
        if [ -z "${CORALOGIX_DOMAIN:-}" ]; then
            fail "CORALOGIX_DOMAIN is required for supervisor mode"
        fi
        if [ -n "$CUSTOM_CONFIG_PATH" ]; then
            fail "--config cannot be used with --supervisor. Supervisor mode uses default config and receives configuration from the OpAMP server."
        fi
        if [ -n "$COLLECTOR_VERSION" ]; then
            warn "--collector-version is ignored in supervisor mode (collector is bundled in supervisor image)"
        fi
    else
        if [ -n "$SUPERVISOR_VERSION" ]; then
            fail "--supervisor-version can only be used with -s/--supervisor"
        fi
        if [ -n "$SUPERVISOR_BASE_CONFIG_PATH" ]; then
            fail "--supervisor-base-config can only be used with -s/--supervisor"
        fi
        if [ -z "$CUSTOM_CONFIG_PATH" ]; then
            warn "No config provided. Using placeholder config (nop receivers/exporters)."
            warn "Use -c to provide your own config file for actual data collection."
        fi
    fi
    
    # Validate supervisor-base-config
    if [ -n "$SUPERVISOR_BASE_CONFIG_PATH" ]; then
        if [ ! -f "$SUPERVISOR_BASE_CONFIG_PATH" ]; then
            fail "Supervisor base config file not found: $SUPERVISOR_BASE_CONFIG_PATH"
        fi
        # Check for opamp extension
        if grep -vE '^\s*#' "$SUPERVISOR_BASE_CONFIG_PATH" | grep -qE '^\s*opamp:'; then
            fail "Supervisor base config cannot contain 'opamp' extension. The supervisor manages the OpAMP connection.
Remove the 'opamp' extension from your config file: $SUPERVISOR_BASE_CONFIG_PATH"
        fi
    fi
    
    # Validate config references env vars if user set them
    if [ -n "$CUSTOM_CONFIG_PATH" ]; then
        validate_config_env_vars "$CUSTOM_CONFIG_PATH"
    elif [ "$SUPERVISOR_MODE" = false ] && [ -f "${CONFIG_HOST_DIR}/config.yaml" ]; then
        validate_config_env_vars "${CONFIG_HOST_DIR}/config.yaml"
    fi
    
    check_docker
    check_ports
    
    if [ "$SUPERVISOR_MODE" = true ]; then
        run_supervisor_mode
    else
        run_regular_mode
    fi
}

main "$@"

