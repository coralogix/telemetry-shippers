# Changelog

All notable changes to the Standalone OTel Installer script (Linux/macOS) will be documented in this file.

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
- Supervisor mode support (OpAMP remote configuration) for Linux
- Custom configuration file support via `-c` flag
- Upgrade support with automatic config backup and restore
- Uninstall support with optional `--purge` flag
- Version pinning with `--collector-version` and `--supervisor-version`
- Foreground mode for debugging
- SHA256 checksum verification for downloaded packages (when available from upstream)
- Port conflict detection with interactive prompts
- Automatic addition of `otelcol-contrib` user to `systemd-journal` group for journald access

### Supported Platforms
- Linux (x86_64, arm64) - systemd service
- macOS (x86_64, arm64) - launchd service

