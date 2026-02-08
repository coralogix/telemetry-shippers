# Changelog

## otel-windows-standalone

### v0.0.1 / 2026-02-09

- [Feat] Initial Windows standalone chart release
- [Feat] Windows Event Log receiver support (System, Application, Security channels)
- [Feat] IIS metrics receiver
- [Feat] IIS logs collection with W3C format parsing:
  - Header metadata parsing for dynamic field detection
  - CSV parsing with automatic header detection
  - Checkpoint storage enabled for resuming after collector restarts
  - Default path: `C:\inetpub\logs\LogFiles\W3SVC*\*.log`
  - IIS log fields mapped to OpenTelemetry semantic conventions:
    - `client.address`, `http.request.method`, `http.response.status_code`
    - `user_agent.original`, `url.path`, `url.query`
    - Custom attributes: `http.request.header.referer`, `http.server.request.duration_ms`
- [Feat] Host metrics with Windows-specific configurations:
  - Process metrics with Windows error suppression
  - Paging scraper enabled
  - Filesystem mount point exclusions for Windows
- [Feat] Host entity events for Windows Server
- [Feat] Fleet management (OpAMP) support
- [Feat] Resource detection and metadata collection
- [Feat] Collector metrics and telemetry endpoints (zpages, pprof)
