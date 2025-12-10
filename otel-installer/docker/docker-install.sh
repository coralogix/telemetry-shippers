#!/bin/bash
# Coralogix OpenTelemetry Collector - Docker Installation Script
#
# One-line installation:
#   CORALOGIX_PRIVATE_KEY="your-key" bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/docker/docker-install.sh)"
#
# Supervisor mode:
#   CORALOGIX_DOMAIN="your-domain" CORALOGIX_PRIVATE_KEY="your-key" bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/docker/docker-install.sh)" -- --supervisor
#
# Environment Variables:
#   CORALOGIX_PRIVATE_KEY   Coralogix private key (required)
#   CORALOGIX_DOMAIN        Coralogix domain (required for supervisor mode)

set -euo pipefail

# Images
COLLECTOR_IMAGE="otel/opentelemetry-collector-contrib"
SUPERVISOR_IMAGE="coralogixrepo/otel-supervised-collector"

# Container settings
CONTAINER_NAME="coralogix-otel-collector"
CONFIG_DIR="/etc/otelcol-contrib"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"

# Default values
VERSION=""
SUPERVISOR_VERSION=""
COLLECTOR_VERSION=""
SUPERVISOR_MODE=false
CUSTOM_CONFIG_PATH=""
DETACHED=true

# Helm chart URL for version lookup
CHART_YAML_URL="https://raw.githubusercontent.com/coralogix/opentelemetry-helm-charts/main/charts/opentelemetry-collector/Chart.yaml"

# Colors
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
    -f, --foreground            Run in foreground (default: detached)
    --uninstall                 Stop and remove the container
    -h, --help                  Show this help message

Environment Variables:
    CORALOGIX_PRIVATE_KEY   Coralogix private key (required)
    CORALOGIX_DOMAIN        Coralogix domain (required for supervisor mode)

Examples:
    # With custom config (recommended)
    CORALOGIX_PRIVATE_KEY="your-key" $0 -c /path/to/config.yaml

    # Supervisor mode (config managed remotely)
    CORALOGIX_DOMAIN="us1.coralogix.com" CORALOGIX_PRIVATE_KEY="your-key" $0 -s

    # Specific version
    CORALOGIX_PRIVATE_KEY="your-key" $0 -c /path/to/config.yaml -v 0.140.1

    # Quick start with placeholder config (for testing only)
    CORALOGIX_PRIVATE_KEY="your-key" $0

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
                CUSTOM_CONFIG_PATH="$(realpath "$2")"
                shift 2
                ;;
            -s|--supervisor)
                SUPERVISOR_MODE=true
                shift
                ;;
            -f|--foreground)
                DETACHED=false
                shift
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

service:
  extensions: [health_check]
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

create_config() {
    local config_dir
    config_dir=$(mktemp -d)
    
    if [ -n "$CUSTOM_CONFIG_PATH" ]; then
        if [ ! -f "$CUSTOM_CONFIG_PATH" ]; then
            fail "Config file not found: $CUSTOM_CONFIG_PATH"
        fi
        cp "$CUSTOM_CONFIG_PATH" "${config_dir}/config.yaml"
    else
        get_default_config > "${config_dir}/config.yaml"
    fi
    
    echo "$config_dir"
}

run_regular_mode() {
    local default_version
    default_version=$(get_version)
    local image_tag="${COLLECTOR_VERSION:-${default_version}}"
    local image="${COLLECTOR_IMAGE}:${image_tag}"
    
    log "Pulling image: ${image}"
    docker pull "$image"
    
    # Create config directory
    local config_dir
    config_dir=$(create_config)
    
    log "Starting collector container..."
    
    local docker_args=(
        --name "${CONTAINER_NAME}"
        --restart unless-stopped
        -e "CORALOGIX_PRIVATE_KEY=${CORALOGIX_PRIVATE_KEY}"
        -v "${config_dir}/config.yaml:/etc/otelcol-contrib/config.yaml:ro"
        -p 4317:4317
        -p 4318:4318
        -p 13133:13133
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
    
    # Create config directory
    local config_dir
    config_dir=$(mktemp -d)
    
    # Create supervisor config
    get_supervisor_config "${CORALOGIX_DOMAIN}" > "${config_dir}/supervisor.yaml"
    
    # Create collector config
    get_default_config > "${config_dir}/config.yaml"
    
    log "Starting supervisor container..."
    
    local docker_args=(
        --name "${CONTAINER_NAME}"
        --restart unless-stopped
        -e "CORALOGIX_PRIVATE_KEY=${CORALOGIX_PRIVATE_KEY}"
        -v "${config_dir}/supervisor.yaml:/etc/otelcol-contrib/supervisor.yaml:ro"
        -v "${config_dir}/config.yaml:/etc/otelcol-contrib/config.yaml:ro"
        -p 4317:4317
        -p 4318:4318
        -p 13133:13133
    )
    
    if [ "$DETACHED" = true ]; then
        docker_args+=(-d)
    fi
    
    # Remove existing container if present
    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
    
    docker run "${docker_args[@]}" "$image" --config /etc/otelcol-contrib/supervisor.yaml
    
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

Useful Commands:
    # View logs
    docker logs -f ${CONTAINER_NAME}

    # Check status
    docker ps | grep ${CONTAINER_NAME}

    # Health check
    curl -s http://localhost:13133/health | jq .

    # Stop container
    docker stop ${CONTAINER_NAME}

    # Remove container
    docker rm ${CONTAINER_NAME}

    # Restart container
    docker restart ${CONTAINER_NAME}

Exposed Ports:
    4317  - OTLP gRPC receiver
    4318  - OTLP HTTP receiver
    13133 - Health check endpoint

EOF

    if [ "$SUPERVISOR_MODE" = true ]; then
        echo "Mode: Supervisor (Fleet Management enabled)"
        echo "Domain: ${CORALOGIX_DOMAIN}"
    else
        echo "Mode: Regular"
        echo "Config: Mounted from host"
    fi
    echo ""
}

main() {
    log "Coralogix OpenTelemetry Collector - Docker Installer"
    log "===================================================="
    
    parse_args "$@"
    
    # Validate requirements
    if [ -z "${CORALOGIX_PRIVATE_KEY:-}" ]; then
        fail "CORALOGIX_PRIVATE_KEY is required"
    fi
    
    if [ "$SUPERVISOR_MODE" = true ]; then
        if [ -z "${CORALOGIX_DOMAIN:-}" ]; then
            fail "CORALOGIX_DOMAIN is required for supervisor mode"
        fi
        if [ -n "$CUSTOM_CONFIG_PATH" ]; then
            warn "--config is ignored in supervisor mode (config is managed remotely)"
        fi
        if [ -n "$COLLECTOR_VERSION" ]; then
            warn "--collector-version is ignored in supervisor mode (collector is bundled in supervisor image)"
        fi
    else
        if [ -n "$SUPERVISOR_VERSION" ]; then
            fail "--supervisor-version can only be used with -s/--supervisor"
        fi
        if [ -z "$CUSTOM_CONFIG_PATH" ]; then
            warn "No config provided. Using placeholder config (nop receivers/exporters)."
            warn "Use -c to provide your own config file for actual data collection."
        fi
    fi
    
    check_docker
    
    if [ "$SUPERVISOR_MODE" = true ]; then
        run_supervisor_mode
    else
        run_regular_mode
    fi
}

main "$@"

