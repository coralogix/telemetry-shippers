#!/usr/bin/env bash
set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/opt/otelcol}"
PLIST_LABEL="${PLIST_LABEL:-com.coralogix.otelcol}"
PLIST="/Library/LaunchDaemons/${PLIST_LABEL}.plist"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo) to uninstall services." >&2
  exit 1
fi

echo "Unloading launchd service..."
launchctl bootout system "${PLIST}" >/dev/null 2>&1 || true

echo "Removing plist..."
rm -f "${PLIST}"

echo "Removing installed files under ${INSTALL_PREFIX}..."
rm -rf "${INSTALL_PREFIX}"

echo "Uninstall complete."
