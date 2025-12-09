# otel-macos-standalone (WIP)

Standalone macOS OpenTelemetry Collector configuration and packaging workflow modeled after `otel-linux-standalone`. This chart renders a collector config tailored for macOS hosts using the upstream presets (host metrics, OTLP receive, Coralogix exporter) and the `filelogMulti` preset to read `/var/log/system.log` with a macOS-friendly regex parser.

## Usage (render config)

```bash
cd otel-macos-standalone
make otel-config  # writes build/otel-config.yaml using helm + yq
```

## Install (launchd)

```bash
cd otel-macos-standalone
sudo CORALOGIX_PRIVATE_KEY=<YOUR_CORALOGIX_PRIVATE_KEY> \
  OTELCOL_VERSION=0.141.0 INSTALL_PREFIX=/opt/otelcol PLIST_LABEL=com.coralogix.otelcol \
  ./scripts/install-macos.sh build/otel-config.yaml
```

## Full Command

Render your config (with Coralogix exporter enabled) to `build/otel-config.yaml`, then:

```bash
cd otel-macos-standalone
make otel-config
sudo CORALOGIX_PRIVATE_KEY=<YOUR_CORALOGIX_PRIVATE_KEY> \
  OTELCOL_VERSION=0.141.0 INSTALL_PREFIX=/opt/otelcol PLIST_LABEL=com.coralogix.otelcol \
  ./scripts/install-macos.sh build/otel-config.yaml
sudo launchctl print system/com.coralogix.otelcol
tail -n 50 /var/log/otelcol.log /var/log/otelcol.err
```

Options (env): `OTEL_VERSION` (default 0.141.0), `INSTALL_PREFIX` (default /opt/otelcol), `PLIST_LABEL` (default com.coralogix.otelcol).
