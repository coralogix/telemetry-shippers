# Changelog

All notable changes to the OTel Installer scripts will be documented in this file.

## [0.1.1] - 2024-12-23

### Added
- `--enable-process-metrics` flag for Linux to grant Linux capabilities (`CAP_SYS_PTRACE`, `CAP_DAC_READ_SEARCH`) for comprehensive process metrics collection without running as root
- Support for Service Discovery preset: automatic monitoring of PostgreSQL, MySQL, Redis, MongoDB, NGINX, Apache, RabbitMQ, Memcached, Elasticsearch, Kafka, and Cassandra
- Credential management via environment variables (e.g., `POSTGRES_PASSWORD`, `MYSQL_PASSWORD`)

### Notes
- Discovery can be enabled in OpenTelemetry configuration (via UI or config file)

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

### Supported Platforms
- Linux (x86_64, arm64) - systemd service
- macOS (x86_64, arm64) - launchd service
- Docker (any platform with Docker installed)
