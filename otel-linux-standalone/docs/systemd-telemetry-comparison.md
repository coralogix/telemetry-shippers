# Systemd Telemetry Comparison

## Environment

- Terraform + cloud-init bootstrap renders `build/otel-config.yaml`, compresses it with `base64gzip`, and installs the collector plus helper systemd units.
- Sample workloads:
  - `demo-logger.service` emits single-line and multiline records via journald (and consequently `/var/log/messages`).
  - `demo-mysql-metrics.service` and `demo-backend-metrics.service` expose Prometheus endpoints on `127.0.0.1:9101` and `127.0.0.1:9102`.
  - `demo-otlp-app.service` pushes spans and metrics to `127.0.0.1:4317`.

Provisioning command (replace credentials as needed):

```
CORALOGIX_API_KEY=<key> AWS_PROFILE=research \
  SSH_KEY_NAME=povilas-linux-demo-key \
  SSH_PUBLIC_KEY_PATH=$PWD/build/keys/otel-demo.pub \
  SSH_PRIVATE_KEY_PATH=$PWD/build/keys/otel-demo \
  make terraform-apply
```

## Logging

### journald receiver

- Journald ingestion preserves structured metadata as part of the log body. For example:

```
sudo journalctl -u demo-logger.service -n 1 -o json-pretty
```

produces keys such as `_SYSTEMD_UNIT`, `_PID`, `_HOSTNAME`, `SYSLOG_IDENTIFIER`, etc. Collector processors can promote these fields into resource attributes via OTTL, e.g.:

```yaml
transform/logs_journald:
  error_mode: ignore
  log_statements:
    - context: log
      statements:
        - set(resource.attributes["systemd.unit"], log.body["_SYSTEMD_UNIT"]) where log.body["_SYSTEMD_UNIT"] != nil
        - set(resource.attributes["service.name"], log.body["_SYSTEMD_UNIT"]) where resource.attributes["service.name"] == nil and log.body["_SYSTEMD_UNIT"] != nil
```

- Because the journald stanza emits the entire entry as a map (`Body: Map({...})`), the transform must read from `log.body[...]` rather than plain attributes.
- Journald batches each record atomically, so multiline sequences (stack traces, JSON payloads) are already preserved—no extra multiline stanza configuration is required for this receiver.

### filelog receiver

- `/var/log/messages` contains traditional syslog-formatted lines (e.g. `Oct 15 10:42:15 ip-172-31-22-73 demo-logger[2649]: demo logger single line …`) interleaved with JSON-formatted journald diagnostics. The receiver now routes entries to specialised parsers so both formats are accepted without error spam:

```yaml
filelog/system:
  include: [/var/log/messages]
  start_at: end
  include_file_name: true
  include_file_path: true
  multiline:
    line_start_pattern: '^[A-Z][a-z]{2}\s+[0-9]{1,2}\s+[0-9]{2}:[0-9]{2}:[0-9]{2}'
  operators:
    - id: detect_json
      type: router
      drop_on_match: true
      routes:
        - expr: body matches '^{'
          output: parse_filelog_json
    - id: parse_syslog
      type: regex_parser
      regex: '^(?P<timestamp>\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(?P<host>\S+)\s+(?P<app>[^\[:]+)(?:\[[^\]]*\])?:\s+(?P<message>.*)$'
      parse_from: body
      on_error: drop
    - id: move_syslog_body
      type: move
      from: attributes.message
      to: body
      optional: true
    - id: syslog_appname
      type: move
      from: attributes.app
      to: attributes.appname
      optional: true
    - id: parse_filelog_json
      type: json_parser
      parse_from: body
      on_error: send
    - id: json_message_to_body
      type: move
      from: attributes.MESSAGE
      to: body
      optional: true
    - id: json_identifier_to_appname
      type: move
      from: attributes.SYSLOG_IDENTIFIER
      to: attributes.appname
      optional: true
```

- Both branches populate `attributes.appname`, which downstream OTTL promotes to `resource.attributes["systemd.unit"]` and `service.name`. Mixed-format logs no longer trigger the previous `syslog_parser` priority errors.

### Multiline handling

- The `multiline.line_start_pattern` ensures stack traces or JSON blobs that do not start with a timestamp stay attached to the previous record. Adjust the regex to match the actual log format if the distro alters syslog prefixes.

### Journald vs `/var/log/messages`

- Journald keeps rich metadata (e.g. `_SYSTEMD_UNIT`, `_PID`, `_HOSTNAME`) inside the log body. The OTTL statements lift `_SYSTEMD_UNIT` to `systemd.unit`/`service.name`, while other keys remain available for future transforms.
- `/var/log/messages` relies on the forwarded identifier—either the parsed `app` field or the JSON `SYSLOG_IDENTIFIER`. The new router guarantees both formats populate `attributes.appname`, which is then promoted to the same resource attributes.
- Example debug exporter entry produced by the filelog pipeline:

```
Oct 15 10:42:20 ip-172-31-22-73 otelcol-contrib[2498]: {"level":"info","ts":"2025-10-15T10:42:20.396Z","msg":"ResourceLog #0",
  "Attributes":{"log.file.name":"messages","log.file.path":"/var/log/messages","systemd.unit":"demo-mysql-metrics.service","service.name":"demo-mysql"},
  "Body":"Oct 15 10:42:20 ip-172-31-22-73 demo-mysql-metrics[2701]: demo logger single line 2025-10-15T10:42:20+00:00"
}
```

- The equivalent journald debug entry contains the same `service.name` plus additional journald metadata (e.g. `_SYSTEMD_INVOCATION_ID`) supplied via `log.body`.

## Metrics

- Two local Prometheus targets are scraped via the collector’s `prometheus` receiver; resource enrichment occurs in `transform/metrics_workloads`:

```yaml
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: demo-mysql
          scrape_interval: 15s
          static_configs:
            - targets: [127.0.0.1:9101]
              labels:
                workload: mysql
        - job_name: demo-backend
          scrape_interval: 15s
          static_configs:
            - targets: [127.0.0.1:9102]
              labels:
                workload: backend
processors:
  transform/metrics_workloads:
    error_mode: ignore
    metric_statements:
      - context: resource
        statements:
          - set(attributes["service.name"], "demo-mysql") where attributes["job"] == "demo-mysql"
          - set(attributes["service.name"], "demo-backend") where attributes["job"] == "demo-backend"
```

- Validation:

```
ssh ... curl -s http://127.0.0.1:9101/metrics | head
# demo_service_up{service="mysql"} 1.0

ssh ... curl -s http://127.0.0.1:9102/metrics | head
# demo_service_up{service="backend"} 1.0
```

- Collector debug exporter confirms `service.name: Str(demo-mysql)` and `service.name: Str(demo-backend)` in `ResourceMetrics`, showing the transform succeeded.

- **Preset suggestion:** encapsulate the scrape configuration and transform in a reusable Helm values fragment, e.g.

```yaml
opentelemetry-agent:
  presets:
    systemdMetrics:
      enabled: true
      workloads:
        - name: mysql
          port: 9101
        - name: backend
          port: 9102
```

and template it into `prometheus` + `transform/metrics_workloads`.

## OTLP Spans and Metrics

- The Python OTLP app runs without setting `service.name`, so the collector enforces naming via `transform/otlp_enrich`:

```yaml
transform/otlp_enrich:
  error_mode: ignore
  metric_statements:
    - context: resource
      statements:
        - set(attributes["service.name"], "demo-otlp") where attributes["demo.workload"] == "demo-otlp"
  trace_statements:
    - context: resource
      statements:
        - set(attributes["service.name"], "demo-otlp") where attributes["demo.workload"] == "demo-otlp"
```

- Debug exporter excerpts show `ResourceMetrics` and `ResourceSpans` annotated with `service.name: Str(demo-otlp)` alongside the original `demo.workload` tag.
- For production, a `resource` processor with include/exclude statements or attribute routing by `service.instance.id` can extend this pattern to additional OTLP workloads.

## OTLP SDK environment overrides

- You can avoid collector-side enrichment by letting the application set environment variables understood by OTel SDKs:

```
python3 -m pip install --user opentelemetry-sdk==1.25.0 opentelemetry-api==1.25.0
OTEL_SERVICE_NAME=test-env \
  OTEL_RESOURCE_ATTRIBUTES="cx.application.name=myapp" \
  python3 -c "from opentelemetry.sdk.resources import OTELResourceDetector; print(OTELResourceDetector().detect().attributes)"
# Output: {'cx.application.name': 'myapp', 'service.name': 'test-env'}
```

- Adding `Environment=OTEL_SERVICE_NAME=demo-otlp` and `Environment=OTEL_RESOURCE_ATTRIBUTES=cx.application.name=demo` to the systemd unit ensures the SDK emits those attributes, even if collector transforms are removed.

## Observations & Caveats

- Journald retains rich metadata in `log.body`; the OTTL statements now promote `_SYSTEMD_UNIT` into both `systemd.unit` and `service.name`, but additional keys (`_PID`, `_HOSTNAME`) can be lifted the same way if needed.
- File-based ingestion relies on either the regex-derived `appname` or the JSON `SYSLOG_IDENTIFIER`. Keep those identifiers aligned with desired service names to avoid manual mapping later.
- The router + dual parsers eliminate the previous `syslog_parser` priority errors, yet the regex still assumes the classic `Oct 15 …` syslog prefix—custom formats may require tweaks.
- Multiline rules remain essential for structured payloads; review the regex if downstream services emit different timestamp formats.
- Resource detection defaults assume Kubernetes; restricting detectors to `ec2` avoids spurious failures on bare EC2 hosts.

## Next Steps

1. Lift additional journald metadata (e.g., `_PID`, `_HOSTNAME`) into resource attributes to enrich troubleshooting context.
2. Promote the filelog parsing pattern into a reusable Helm preset or include list so multiple services can adopt it without duplicating YAML.
3. Extend `transform/otlp_enrich` with a configurable mapping (values file list) for workloads beyond the hard-coded `demo-otlp`.
4. Package the Prometheus scrape/transform bundle as a preset (see suggestion above) so future systemd workloads only need to define name/port pairs.

## Terraform reference

- The Terraform bootstrap script `terraform/templates/user_data.sh.tmpl` already provisions:
  - `demo-logger.service`
  - `demo-mysql-metrics.service`
  - `demo-backend-metrics.service`
  - `demo-otlp-app.service`
- Running `make terraform-apply` installs these units on the same EC2 host alongside the collector, enabling immediate replication of the comparisons described here.
