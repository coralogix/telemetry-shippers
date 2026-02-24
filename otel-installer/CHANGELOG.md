# Changelog

All notable changes to the OTel Installer scripts will be documented in this file.

## [0.1.7] - 2026-02-22

### Added
- Windows: On service start failure, installer now prints recent collector errors from the Application Event Log (source `otelcol-contrib`) so users see the actual failure (e.g. IIS receiver, config errors) before generic troubleshooting steps

## [0.1.6] - 2026-02-02

### Added
- Service discovery support with automatic credential management
  - Automatic creation of discovery credentials file (`/etc/otelcol-contrib/discovery.env` for regular mode, `/etc/opampsupervisor/opampsupervisor.conf` for supervisor mode)
  - Support for PostgreSQL, MySQL, Redis, MongoDB, RabbitMQ, and Elasticsearch credentials
  - Post-installation instructions for configuring credentials
- Installation summary file (`INSTALLATION_SUMMARY.txt`) with installation details, discovery status, and useful commands
- Automatic Linux capabilities enablement:
  - Enabled by default in supervisor mode (for discovery/process metrics support from OpAMP configs)
  - Auto-enabled in regular mode when service discovery is detected in configuration
  - Auto-enabled in regular mode when process metrics are detected in configuration
- `--disable-capabilities` flag to opt-out of automatic capabilities enablement (supervisor mode only)

## [0.1.5] - 2025-02-02

### Added
- Windows installer script (`coralogix-otel-collector.ps1`) for deploying the collector as a Windows Service
- Windows supervisor mode support (OpAMP remote configuration via Fleet Management)
- Dynamic IIS log parsing support via `-EnableDynamicIISParsing` flag
- Custom OpAMP supervisor config support via `-SupervisorOpampConfig` flag
- Base collector config for supervisor mode via `-SupervisorCollectorBaseConfig` flag
- Local MSI installation support via `-SupervisorMsi` flag
- E2E tests for Windows installer (install, version, config, supervisor, purge)

### Supported Platforms
- Windows 10/11, Windows Server 2016+ (x64, ARM64) - Windows Service

## [0.1.4] - 2024-01-28

### Changed
- Docker installer: Removed `--listen-interface` parameter (Docker port mapping requires binding to `0.0.0.0` inside container)

## [0.1.3] - 2024-01-12

### Changed
- **BREAKING**: Removed `--upgrade` flag from standalone installer
- Installer now automatically detects existing installations and upgrades them

## [0.1.2] - 2024-12-29

### Fixed
- Add `opampsupervisor` user to `systemd-journal` group for journald log access in supervisor mode

## [0.1.1] - 2024-12-23

### Added
- `--enable-process-metrics` flag for Linux to grant Linux capabilities (`CAP_SYS_PTRACE`, `CAP_DAC_READ_SEARCH`) for comprehensive process metrics collection without running as root

## [0.1.0] - 2024-12-18

### Added
- Standalone installer script for Linux and macOS
- Docker installer script with container management
- Supervisor mode support (OpAMP remote configuration) for Linux
- Custom configuration file support via `-c` flag
- Upgrade support with automatic config backup and restore
- Uninstall support with optional `--purge` flag
- Version pinning with `--collector-version` and `--supervisor-version`
- Foreground mode for debugging
- SHA256 checksum verification for downloaded packages (when available from upstream)
- Port conflict detection with interactive prompts
- Automatic addition of `otelcol-contrib` user to `systemd-journal` group for journald access
- GitHub Actions workflow for automated releases
- Docker installer: Memory limit configuration via `--memory-limit` flag

### Supported Platforms
- Linux (x86_64, arm64) - systemd service
- macOS (x86_64, arm64) - launchd service
- Docker (any platform with Docker installed)
