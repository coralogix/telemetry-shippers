#!/bin/sh
set -eu

DEFAULT_VERSION="${VERSION:-0.140.1}"
SUPERVISOR_VERSION="${SUPERVISOR_VERSION:-$DEFAULT_VERSION}"
COLLECTOR_VERSION="${COLLECTOR_VERSION:-$SUPERVISOR_VERSION}"

ARCH=$(uname -m)
# if arch is aarch64, change to arm64
if [ "$ARCH" = "aarch64" ]; then
  ARCH="arm64"
elif [ "$ARCH" = "x86_64" ]; then
  ARCH="amd64"
fi

log() {
  printf "%s\n" "$*"
}

fail() {
  printf "Error: %s\n" "$*" >&2
  exit 1
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Missing required command: $1"
  fi
}

ensure_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
    return
  fi
  require_cmd sudo
  SUDO="sudo"
}

check_arch() {
  case "$ARCH" in
    x86_64|amd64|arm64) ;;
    *) fail "Unsupported architecture $ARCH. Only x86_64/amd64/arm64 is supported." ;;
  esac
}

detect_pkg_type() {
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    base="${ID_LIKE:-$ID}"
    case "$base" in
      *debian*) echo "deb"; return ;;
      *rhel*|*fedora*|*suse*|*centos*|*amzn*|*rocky*|*almalinux*) echo "rpm"; return ;;
    esac
  fi
  fail "Unsupported Linux distribution. Need Debian/Ubuntu or an RPM-based distro."
}

download() {
  url="$1"
  dest="$2"
  curl -fsSL -o "$dest" "$url" || fail "Download failed: $url"
}

install_supervisor() {
  pkg_type="$1"
  case "$pkg_type" in
    deb)
      pkg_name="opampsupervisor_${SUPERVISOR_VERSION}_linux_${ARCH}.deb"
      pkg_url="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/cmd%2Fopampsupervisor%2Fv${SUPERVISOR_VERSION}/${pkg_name}"
      ;;
    rpm)
      pkg_name="opampsupervisor_${SUPERVISOR_VERSION}_linux_${ARCH}.rpm"
      pkg_url="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/cmd%2Fopampsupervisor%2Fv${SUPERVISOR_VERSION}/${pkg_name}"
      ;;
    *) fail "Unknown package type: $pkg_type" ;;
  esac

  log "Downloading OpAMP Supervisor ${SUPERVISOR_VERSION} (${pkg_type})..."
  download "$pkg_url" "$pkg_name"

  log "Installing OpAMP Supervisor..."
  if [ "$pkg_type" = "deb" ]; then
    $SUDO dpkg -i "$pkg_name"
  else
    $SUDO rpm -i "$pkg_name"
  fi
}

install_collector() {
  tar_name="otelcol-contrib_${COLLECTOR_VERSION}_linux_${ARCH}.tar.gz"
  tar_url="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${COLLECTOR_VERSION}/${tar_name}"

  log "Downloading Otel Collector Contrib ${COLLECTOR_VERSION}..."
  download "$tar_url" "$tar_name"

  log "Extracting Collector..."
  tar -xvf "$tar_name" >/dev/null 2>&1 || fail "Extraction failed for $tar_name"

  if [ ! -x ./otelcol-contrib ]; then
    fail "Expected otelcol-contrib binary after extraction."
  fi

  log "Placing Collector binary into /usr/local/bin (requires root)..."
  $SUDO mv -f ./otelcol-contrib /usr/local/bin/otelcol-contrib
}

configure_supervisor() {
  log "Configuring OpAMP Supervisor..."
  $SUDO mkdir -p /etc/opampsupervisor

  # Create config.yaml
  $SUDO tee /etc/opampsupervisor/config.yaml >/dev/null <<EOF
server:
  endpoint: "https://ingress.${CORALOGIX_DOMAIN}/opamp/v1"
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

  # This passes config files to the Collector.
  config_files:
    - /etc/opampsupervisor/collector.yaml

  # This adds CLI arguments to the Collector.
  args: []

  # This adds env vars to the Collector process.
  env:
    CORALOGIX_PRIVATE_KEY: "\${env:CORALOGIX_PRIVATE_KEY}"

# The storage can be used for many things:
# - It stores configuration sent by the OpAMP server so that new collector
#   processes can start with the most known desired config.
storage:
  directory: /var/lib/opampsupervisor/

telemetry:
  logs:
    level: debug
    output_paths:
      - /var/log/opampsupervisor/opampsupervisor.log
EOF

  # Configure env var for the service
  log "Configuring Supervisor environment variables..."
  # Ensure idempotency: remove existing key if present
  if [ -f /etc/opampsupervisor/opampsupervisor.conf ]; then
    $SUDO sed -i '/CORALOGIX_PRIVATE_KEY/d' /etc/opampsupervisor/opampsupervisor.conf
  fi
  $SUDO tee -a /etc/opampsupervisor/opampsupervisor.conf >/dev/null <<EOF
CORALOGIX_PRIVATE_KEY="${CORALOGIX_PRIVATE_KEY}"
EOF
}

configure_collector() {
  log "Creating default Collector configuration..."
  $SUDO tee /etc/opampsupervisor/collector.yaml >/dev/null <<'EOF'
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

start_service() {
  log "Starting OpAMP Supervisor service..."
  $SUDO systemctl daemon-reload
  $SUDO systemctl enable opampsupervisor
  $SUDO systemctl restart opampsupervisor
}

print_summary() {
  cat <<'SUMMARY'
Installation and configuration complete. Service has been started.

You can check the status and logs with:
    sudo systemctl status opampsupervisor --no-pager
    sudo tail -f /var/log/opampsupervisor/opampsupervisor.log
SUMMARY
}

check_and_remove_installed() {
  pkg_type="$1"
  if [ "$pkg_type" = "deb" ]; then
    if dpkg -s opampsupervisor >/dev/null 2>&1; then
      log "Warning: opampsupervisor is already installed. Removing it..."
      $SUDO dpkg -P opampsupervisor || $SUDO dpkg -r opampsupervisor
    fi
  else
    if rpm -q opampsupervisor >/dev/null 2>&1; then
      log "Warning: opampsupervisor is already installed. Removing it..."
      $SUDO rpm -e opampsupervisor
    fi
  fi
}

main() {
  if [ -z "${CORALOGIX_PRIVATE_KEY:-}" ]; then
    fail "CORALOGIX_PRIVATE_KEY environment variable is required."
  fi
  if [ -z "${CORALOGIX_DOMAIN:-}" ]; then
    fail "CORALOGIX_DOMAIN environment variable is required."
  fi

  require_cmd uname
  require_cmd tar
  require_cmd curl

  check_arch
  ensure_sudo
  pkg_type=$(detect_pkg_type)

  check_and_remove_installed "$pkg_type"

  workdir=$(mktemp -d 2>/dev/null || mktemp -d -t opampsupervisor)
  trap 'rm -rf "$workdir"' EXIT INT HUP TERM
  cd "$workdir"

  install_supervisor "$pkg_type"
  install_collector

  configure_supervisor
  configure_collector
  start_service

  print_summary
}

main "$@"
