#!/usr/bin/env bash
set -euo pipefail

# macOS installer for otelcol-contrib as a launchd daemon with Coralogix key injection.
# Usage: sudo CORALOGIX_PRIVATE_KEY=... ./install-macos.sh /path/to/rendered/otel-config.yaml
# Env vars: OTELCOL_VERSION (default 0.141.0), INSTALL_PREFIX (default /opt/otelcol), PLIST_LABEL (default com.coralogix.otelcol)

CONFIG_PATH="${1:-}"
OTELCOL_VERSION="${OTELCOL_VERSION:-0.141.0}"
ARCH="$(uname -m)"
OTEL_ARCH="${ARCH/x86_64/amd64}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/opt/otelcol}"
PLIST_LABEL="${PLIST_LABEL:-com.coralogix.otelcol}"
PLIST="/Library/LaunchDaemons/${PLIST_LABEL}.plist"

if [[ -z "${CONFIG_PATH}" ]]; then
  echo "Usage: $0 <rendered-otel-config.yaml>" >&2
  exit 1
fi
if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "Config file not found: ${CONFIG_PATH}" >&2
  exit 1
fi
if [[ -z "${CORALOGIX_PRIVATE_KEY:-}" ]]; then
  echo "CORALOGIX_PRIVATE_KEY env var is required for the Coralogix exporter." >&2
  exit 1
fi

sudo mkdir -p "${INSTALL_PREFIX}"
WORKDIR="$(mktemp -d /tmp/otelcol-macos-XXXXXX)"
cleanup() { rm -rf "${WORKDIR}"; }
trap cleanup EXIT

echo "Downloading otelcol-contrib v${OTELCOL_VERSION} (${OTEL_ARCH})..."
curl -fL "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTELCOL_VERSION}/otelcol-contrib_${OTELCOL_VERSION}_darwin_${OTEL_ARCH}.tar.gz" -o "${WORKDIR}/otelcol-contrib.tar.gz"
tar -xzf "${WORKDIR}/otelcol-contrib.tar.gz" -C "${WORKDIR}"

echo "Installing binary and config to ${INSTALL_PREFIX}..."
sudo install -m 0755 "${WORKDIR}/otelcol-contrib" "${INSTALL_PREFIX}/otelcol-contrib"
sudo install -m 0644 "${CONFIG_PATH}" "${INSTALL_PREFIX}/config.yaml"

echo "Writing launchd plist..."
cat > "${WORKDIR}/${PLIST_LABEL}.plist" <<EOF2
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key><string>${PLIST_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
      <string>${INSTALL_PREFIX}/otelcol-contrib</string>
      <string>--config</string>
      <string>${INSTALL_PREFIX}/config.yaml</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
      <key>CORALOGIX_PRIVATE_KEY</key><string>${CORALOGIX_PRIVATE_KEY}</string>
    </dict>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>/var/log/otelcol.log</string>
    <key>StandardErrorPath</key><string>/var/log/otelcol.err</string>
  </dict>
</plist>
EOF2

sudo install -m 0644 "${WORKDIR}/${PLIST_LABEL}.plist" "${PLIST}"

echo "Loading service..."
sudo launchctl bootout system "${PLIST}" >/dev/null 2>&1 || true
sudo launchctl bootstrap system "${PLIST}"
sudo launchctl enable "system/${PLIST_LABEL}"
sudo launchctl kickstart -k "system/${PLIST_LABEL}"

echo "Installation complete. Collector config: ${INSTALL_PREFIX}/config.yaml"
