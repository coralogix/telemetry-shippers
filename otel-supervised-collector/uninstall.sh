#!/bin/sh
set -eu

# Optional: set PURGE_CONFIG=1 to delete config/state/log directories.
PURGE_CONFIG="${PURGE_CONFIG:-0}"

log() {
  printf "%s\n" "$*"
}

warn() {
  printf "Warning: %s\n" "$*" >&2
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

stop_service() {
  if command -v systemctl >/dev/null 2>&1; then
    $SUDO systemctl stop opampsupervisor >/dev/null 2>&1 || true
    $SUDO systemctl disable opampsupervisor >/dev/null 2>&1 || true
  fi
}

remove_package() {
  pkg_type="$1"
  case "$pkg_type" in
    deb)
      if dpkg -s opampsupervisor >/dev/null 2>&1; then
        $SUDO dpkg -r opampsupervisor >/dev/null 2>&1 || warn "Failed to remove opampsupervisor package (dpkg)."
      else
        warn "opampsupervisor package not installed (dpkg)."
      fi
      ;;
    rpm)
      if rpm -q opampsupervisor >/dev/null 2>&1; then
        $SUDO rpm -e opampsupervisor >/dev/null 2>&1 || warn "Failed to remove opampsupervisor package (rpm)."
      else
        warn "opampsupervisor package not installed (rpm)."
      fi
      ;;
    *) fail "Unknown package type: $pkg_type" ;;
  esac
}

remove_collector_binary() {
  if [ -e /usr/local/bin/otelcol-contrib ]; then
    $SUDO rm -f /usr/local/bin/otelcol-contrib || warn "Could not remove /usr/local/bin/otelcol-contrib"
  else
    warn "Collector binary not found at /usr/local/bin/otelcol-contrib"
  fi
}

purge_configs() {
  if [ "$PURGE_CONFIG" -eq 1 ] 2>/dev/null; then
    log "Purging opampsupervisor configuration, state, and logs..."
    $SUDO rm -rf /etc/opampsupervisor /var/lib/opampsupervisor /var/log/opampsupervisor || warn "Failed to purge one or more directories"
    return
  fi
  log "Config/state/logs left in place (set PURGE_CONFIG=1 to remove):"
  log "  /etc/opampsupervisor"
  log "  /var/lib/opampsupervisor"
  log "  /var/log/opampsupervisor"
}

print_summary() {
  cat <<'SUMMARY'
Uninstall completed.

If you set PURGE_CONFIG=1, config/state/log directories were removed.
Otherwise they remain for inspection or backup.

To reinstall later, rerun install.sh (optionally adjusting SUPERVISOR_VERSION/COLLECTOR_VERSION).
SUMMARY
}

main() {
  require_cmd uname
  ensure_sudo

  pkg_type=$(detect_pkg_type)

  stop_service
  remove_package "$pkg_type"
  remove_collector_binary
  purge_configs
  print_summary
}

main "$@"
