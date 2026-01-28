# Changelog

All notable changes to the Docker OTel Installer script will be documented in this file.

## [0.1.0] - 2024-01-28

### Added
- Docker installer script with container management
- Supervisor mode support (OpAMP remote configuration)
- Custom configuration file support via `-c` flag
- Memory limit configuration via `--memory-limit` flag
- Version pinning with `--collector-version` and `--supervisor-version`
- Foreground mode for debugging
- Port conflict detection
- Automatic container restart policy

### Supported Platforms
- Docker (any platform with Docker installed)

