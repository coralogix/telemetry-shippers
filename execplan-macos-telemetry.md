# Mac host telemetry collector & Helm research

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds. Maintain this document in accordance with `otel-linux-standalone/.agent/PLANS.md`, which governs structure, tone, and update discipline.

## Purpose / Big Picture

Enable reliable collection of macOS host telemetry (logs, metrics, traces) with the OpenTelemetry Collector and turn that knowledge into a Helm-based configuration and deployment workflow similar to `otel-linux-standalone`. A newcomer should be able to render a mac-ready collector config, run it locally (or on a macOS cloud host), and observe host metrics plus log ingestion and OTLP traffic flowing to debug exporters or Coralogix.

## Progress

- [X] (2025-11-21 12:14Z) Drafted this ExecPlan, aligned it with `otel-linux-standalone/.agent/PLANS.md`, and captured research goals for macOS telemetry and a Helm-based workflow.
- [X] (2025-11-21 12:32Z) Downloaded `otelcol-contrib` v0.140.1 for darwin/arm64, generated `components.txt`, and classified mac-ready coverage (filelog/syslog/journald receivers present; exec receiver absent; hostmetrics, OTLP, and resourcedetection available).
- [X] (2025-11-21 12:32Z) Proved local macOS collection: ran collector with hostmetrics + filelog + OTLP and debug exporter; ingested `/var/log/system.log` plus unified logs via `log stream` piped to `/tmp/macos-unified.log`; validated host metrics, logs, and generated traces/metrics via telemetrygen.
- [X] (2025-11-21 12:45Z) Scaffolded `otel-macos-standalone/` chart (Chart.yaml, values.yaml with mac defaults, Makefile, README, placeholder install/uninstall scripts); pending template validation and launchd helper implementation.
- [X] (2025-11-21 13:05Z) Rendered macOS config via `make otel-config`, fixed values to avoid cloud detectors, and implemented launchd-aware install/uninstall scripts plus README usage; Makefile install target wired.
- [X] (2025-11-21 13:10Z) Surveyed mac-capable cloud offerings (AWS EC2 Mac vs. others), captured detector applicability, and folded guidance into Context; defaults keep `ec2` disabled.
- [X] (2025-12-04 11:15Z) Bumped the chart dependency to `opentelemetry-collector` 0.125.0, switched to the `filelogMulti` preset for `/var/log/system.log`, disabled syslog/logstream, dropped the debug exporter, and rendered a Coralogix-only config with manual `resourcedetection/env` (cloud detectors removed) and hostmetrics rooted at `/`.
- [ ] Finalize retrospective with findings, gaps, and recommended next implementation steps.

## Milestones

1) Baseline validation (done): acquire macOS collector v0.140.1, inventory components, and prove hostmetrics + filelog + OTLP + unified logging ingestion on a local mac with debug exporter.
2) Mac chart scaffold (in progress): rely on upstream presets (hostMetrics, batch, OTLP receiver, Coralogix exporter, filelogMulti) with mac-specific parsing of `/var/log/system.log`, manual `resourcedetection/env`, and launchd scripts; validate rendered config and install flow.
3) Cloud posture and defaults (pending): document AWS EC2 Mac vs. other providers, gate `ec2` detector (opt-in), and finalize values/README guidance for cloud vs. local mac usage.
4) Wrap-up (pending): update retrospective, polish documentation, and ensure artifacts/tests prove behavior without logstream/syslog helpers.

Next steps (immediate):
- Validate the new preset-only render: confirm filelog regex parsing, hostmetrics rooted at `/`, and OTLP reception on macOS with Coralogix-only pipelines (no debug).
- Verify launchd install script on macOS with OTELCOL_VERSION 0.141.0 and configurable API key; document any manual steps for removal/upgrade.
- Decide whether to push a macOS distribution identifier upstream (for Coralogix headers) or keep using `standalone` semantics while avoiding cloud resourcedetection defaults.

## Surprises & Discoveries

- Observation: The `exec` receiver is not built into the v0.140.1 contrib binary; attempting to configure it fails with “unknown type: \"exec\"”.
  Evidence: Collector startup failed with `unknown type: "exec" for id: "exec"` when using an exec-based log stream capture.
- Observation: Filelog’s stanza `multiline` operator is rejected (“unsupported type 'multiline'”) in this build; multiline handling will need to rely on filelog’s native multiline configuration or regex parsers instead.
  Evidence: Collector parse failure when `operators[0].type` was set to `multiline`.
- Observation: Enabling `resourcedetection` with the `ec2` detector on a local mac host fails fast due to missing AWS profile/IMDS access.
  Evidence: Startup error `failed creating detector type "ec2": failed to get shared config profile, resaerch` until the detector list was limited to `[system, env]`.
- Observation: Filelog successfully tailed `/var/log/system.log` and `/tmp/macos-unified.log` (populated by `log stream`), emitting records with `os.type=darwin` and `host.name` after resourcedetection.
  Evidence: `/tmp/otelcol-macos/collector.log` shows debug exporter entries for logs from `system.log` and the injected `manual test log` line, with resourcedetection metadata.
- Observation: Hostmetrics scrapers for cpu, memory, filesystem, disk, load, network, and processes run on macOS without additional privileges.
  Evidence: Debug exporter output in `/tmp/otelcol-macos/collector.log` includes `system.memory.usage`, cpu, filesystem, load, network, and process metrics.
- Observation: Rendering the new mac chart with upstream defaults still emits extra `resourcedetection/region` detectors (gcp/ec2/azure/eks) from the dependency chart.
  Evidence: `otel-macos-standalone/build/otel-config.yaml` contains a `resourcedetection/region` processor with multiple cloud detectors despite mac defaults; needs trimming in follow-up.
- Observation: Applying `syslog_parser` (rfc3164) to `/var/log/system.log` produced parser errors (`expecting a priority value within angle brackets`) because macOS system.log lines omit `<PRI>` prefixes; messages still flowed but without structured syslog fields.
  Evidence: `/tmp/otelcol-macos/run-syslog-parse.log` shows repeated stanza errors and unparsed bodies like `Dec 3 00:05:46 MacBook-Pro syslogd[346]: ASL Sender Statistics`.
- Observation: A `regex_parser` tailored to macOS `system.log` successfully extracted fields (`timestamp`, `host`, `app`, `pid`) while leaving the message in `body`; example parsed line: `timestamp=Dec 3 09:13:42`, `host=MacBook-Pro`, `app=syslogd`, `pid=346`, `body=ASL Sender Statistics`.
  Evidence: `/tmp/otelcol-macos/run-regex.log` shows debug exporter entries with those attributes and no parser errors.
- Observation: Updated values to rely on presets (hostMetrics, batch, resourceDetection, otlpReceiver) and keep only filelog + custom resourcedetection in config; rendered config still builds successfully.
  Evidence: `make otel-config` now renders with only filelog receiver defined in config and preset-provided hostmetrics/otlp receivers.
- Observation: Attempting to fully template log-source toggles inside `values.yaml` caused Helm values parsing failures; current config is static (system.log + logstream file) to keep renders working.
  Evidence: `make otel-config` failed with YAML parse errors until templating was removed; static config now renders cleanly.

## Decision Log

- Decision: Reuse the `otel-linux-standalone` structure (Helm chart to render config, helper Make targets) as the reference pattern for a macOS variant instead of inventing a new workflow.
  Rationale: Keeps the developer experience consistent and leverages existing tooling already curated for single-host deployments.
  Date/Author: 2025-11-21 / Codex
- Decision: Prefer the official `otelcol-contrib` tarball for darwin/arm64 over Homebrew to lock an explicit version and avoid system-wide side effects; target v0.140.1 for this research while keeping notes on the linux chart’s current v0.137.0 baseline.
  Rationale: Deterministic binary acquisition simplifies reproducing component inventories, avoids brew upgrade drift, and testing a newer patch release ensures current macOS component coverage.
  Date/Author: 2025-11-21 / Codex
- Decision: Capture unified logging by running `log stream` externally and tailing its output with filelog, since the contrib binary lacks the exec receiver.
  Rationale: Preserves unified log ingestion without needing non-bundled receivers; keeps config compatible with the shipped component set.
  Date/Author: 2025-11-21 / Codex
- Decision: Guard the `ec2` resourcedetection detector behind environment/provider checks and default to `[system, env]` on local macOS.
  Rationale: The `ec2` detector fails without AWS credentials/IMDS and is unnecessary for local testing; gating it avoids startup failures.
  Date/Author: 2025-11-21 / Codex
- Decision: Create a dedicated chart `otel-macos-standalone/` patterned after `otel-linux-standalone`, vendoring `opentelemetry-collector` and adding launchd-focused artifacts (plist, install script, optional `log stream` helper) rather than systemd/Terraform glue.
  Rationale: Keeps workflows consistent while addressing mac-specific service management and log collection constraints.
  Date/Author: 2025-11-21 / Codex
- Decision: Default log collection to filelog on `/var/log/system.log` plus an optional syslog receiver; expose a toggle to run a bundled `log stream` helper (launched via launchd) that writes NDJSON to a known file for filelog ingestion.
  Rationale: Balances simplicity (system.log is present) with full unified-log coverage via an optional helper without requiring non-bundled collector receivers.
  Date/Author: 2025-11-21 / Codex
- Decision: Keep the mac chart config static (system.log + logstream file) for now to preserve a working Helm render, and revisit templated toggles after stabilizing.
  Rationale: Templating inside values.yaml broke Helm parsing; a static config allows progress while deferring conditional rendering improvements.
  Date/Author: 2025-11-21 / Codex

## Outcomes & Retrospective

- To be filled after component inventory, local validation, and chart design are complete.

## Context and Orientation

The repository currently includes `otel-linux-standalone/`, a Helm chart plus Terraform wrapper that renders a collector config for Ubuntu EC2 hosts, installs `otelcol-contrib` v0.137.0 as a systemd service, and enables journald logs, host metrics presets, and EC2 resource detection. There is no macOS-specific chart or automation yet. Existing ExecPlans under `otel-linux-standalone/.agent/` show how to structure living plans and how the chart integrates presets and custom pipelines. Our goal is to research macOS capabilities (component availability, log sources, host metrics coverage, resource enrichment, and deployment options) and outline a Helm-based approach that mirrors the linux workflow while accounting for mac-specific constraints (launchd instead of systemd, different log storage, limited detector support, and potential cloud-provider differences); testing will use collector v0.140.1 for macOS.

On this mac host, `/var/log/system.log` (symlinked as `/private/var/log/system.log`) is readable by `admin` group, and the BSD syslog socket exists at `/var/run/syslog`, making filelog or syslog receivers viable for system log scraping. Unified logging is accessible via the `log stream` CLI rather than on-disk files, so piping `log stream --style ndjson` into a temporary file and tailing it with filelog is the primary option for full log coverage without adding non-bundled receivers.

Component inventory from `components.txt` (v0.140.1) confirms macOS support for OTLP (grpc/http), hostmetrics (cpu, memory, disk, filesystem, network, load, processes), resourcedetection, filelog, syslog, tcplog/udplog, fluentforward, otlpjsonfile, and log exporters (debug). Journald is bundled but irrelevant on macOS; exec receiver is absent; Windows-specific receivers (windowseventlog, iis) and Linux-only ones (cgroups, docker_stats, kubeletstats) are present in the list but inapplicable here. Helm renders still inject `memory_limiter` and transform processors from the dependency chart; they are acceptable defaults for now but can be trimmed later.

Cloud posture summary: AWS EC2 Mac (mac1=Intel, mac2/3=Apple Silicon) provides IMDSv2 so the `ec2` detector can work if explicitly enabled; hosts are dedicated with 24h minimum billing and limited OS choices. Providers like MacStadium/Scaleway (and likely Azure/GCP pilot programs) expose macOS without a standardized metadata service, so assume `ec2` is unavailable and rely on `system` + `env`/manual resource attributes. Default stance: keep `ec2` disabled unless knowingly running on AWS Mac.

## Plan of Work

First, study the `otel-linux-standalone` chart and its ExecPlans to understand how it renders configuration, which presets and custom receivers it enables, and how Make/Helm/Terraform glue is arranged. Capture reusable patterns (values structure, presets toggles, custom config blocks) and note linux-specific pieces that must be swapped for macOS equivalents.

Next, acquire `otelcol-contrib` v0.140.1 for darwin/arm64 on this workstation, run its `components` subcommand to list receivers/processors/exporters/extensions, and classify which components are relevant for macOS host monitoring. Pay special attention to log receivers (filelog, syslog socket coverage, journald present but unused on mac), host metrics coverage in `hostmetrics` (cpu, memory, disk, load, paging, processes), and enrichment options (resourcedetection with `system`, `env`, potential cloud detectors, `attributes`/`transform` processors, `host_observer` for endpoint discovery). Note that the `exec` receiver is not bundled.

Then, build a minimal macOS-focused collector config that exercises host metrics, local log ingestion, and OTLP ingestion. Use debug/logging exporters to observe data without leaving the host. Validate log capture against macOS logging realities: `/var/log/system.log` availability, unified logging via `log stream --style ndjson` piped into filelog (spawned externally because `exec` is unavailable), and application logs written to files. Confirm resource attributes (os.type=osx, host.id/host.name) are present and enriched via resourcedetection. Use `telemetrygen` or a small OTLP test script to send traces/metrics into the collector.

In parallel, research deployment considerations specific to macOS: how to manage the collector as a launchd service (plist generation, log paths), how to package the binary (tarball download versus Homebrew), and whether the Helm workflow should render launchd artifacts, install scripts, or just the collector config. Plan how to mirror the linux Make targets for rendering configs and optionally provisioning a macOS cloud host.

Finally, survey mac-capable cloud offerings (AWS EC2 Mac, any GCP/others) to understand OS versions, virtualization constraints, networking defaults, and whether cloud detectors like `ec2` are meaningful. Synthesize findings into chart defaults (e.g., enable `resourcedetection` with `system` and optionally `ec2` when running on AWS, fall back to `env`/`file` for manual overrides).

Chart design proposal: create `otel-macos-standalone/` mirroring `otel-linux-standalone` with `opentelemetry-collector` dependency vendored. Values should:
- Configure hostmetrics scrapers (cpu, memory, disk, filesystem, network, load, processes) enabled by default.
- Enable filelog on `/var/log/system.log` (and `/private/var/log/system.log`) with no syslog or logstream helpers by default.
- Allow OTLP receive (grpc/http) and Coralogix exporter wiring consistent with linux chart.
- Gate `resourcedetection` detectors: always `system`, optionally `env`, optionally `ec2` when a value flag is set (default off) to avoid local failures; allow user-specified attributes for `service.name`, region, environment.
- Emit launchd plist and install/uninstall scripts (bash) to place binaries/config under `/opt/otelcol` (or user-provided prefix) and start the collector (no logstream helper needed).
- Preserve linux chart Make targets by adding mac equivalents: `make otel-config` (render config to `build/otel-config.yaml`), `make install-macos` (download binary, write plist/scripts, start services), `make uninstall-macos`.
- Upstream change suggestion for `opentelemetry-helm-charts`: add macOS support knobs to the collector chart itself so downstream wrappers avoid unsupported keys. Specifically, introduce chart values to:
  * Enable a macOS logstream helper preset that renders a sidecar ConfigMap/script path and adds the generated file to filelog includes.
  * Expose filelog include paths and syslog receiver toggles under a platform-neutral key (`logs.filelog.paths`, `logs.syslog.enabled`) instead of ad-hoc `mac.*` keys.
  * Allow resourcedetection detector lists to be set in values (with defaults `system,env` and optional `ec2`) without requiring custom config blocks.
  * Keep these behind optional presets so non-mac platforms remain unaffected. Once upstreamed, the mac standalone chart can drop custom config and rely on the preset fields.
- Static rendered mac config snapshot (current scaffold): filelog includes `/var/log/system.log` and `/private/var/log/system.log`; hostmetrics scrapers cpu/memory/disk/filesystem/network/load/processes; resourcedetection limited to `system,env`; pipelines for logs/metrics/traces all export to `debug`; extra processors from dependency (memory_limiter, transform) remain. This is the target behavior to match when upstream presets are added.

Preset recommendations for upstream `opentelemetry-helm-charts` (to support mac configs without custom keys):
- Reuse the chart’s existing logs preset (filelog) with mac-friendly defaults:
  * Allow overriding filelog include paths (defaults: `/var/log/system.log`, `/private/var/log/system.log`).
  * No syslog or logstream helper by default.
  * If the chart already offers a logsCollection preset with multiline options, reuse it and only override the include paths; no new preset is required beyond a mac-aware include override.
  * For structured parsing on macOS, use a `regex_parser` operator instead of `syslog_parser` (mac system.log lacks `<PRI>`). Suggested stanza operators:
    - type: regex_parser
      regex: '^(?P

      <timestamp>

      [A-Z][a-z]{2}\\s+\\d{1,2}\\s+\\d{2}:\\d{2}:\\d{2})\\s+(?P

      <host>

      [^\\s]+)\\s+(?P

      <app>

      [A-Za-z0-9._-]+)(?:\\[(?P

      <pid>

      \\d+)\\])?:\\s+(?P

      <msg>

      .*)$'
    - type: move
      from: attributes.msg
      to: body
- Reuse existing presets where available: the standard `hostMetrics` preset already works on macOS (cpu, memory, disk, filesystem, network, load, processes); existing `resourceDetection` preset should allow detector overrides (default system/env, opt-in ec2); existing Coralogix preset should be compatible with mac signals once macOS log preset is present.
- Parsing note: macOS `system.log` lines lack `<PRI>` prefixes, so the built-in `syslog_parser` (rfc3164) fails with “expecting a priority value within angle brackets”. Prefer plain filelog ingestion or a custom regex parser if structured fields are required.
- Static collector configs to validate presets:
  * macOS logs (filelog only):
    receivers:
    filelog:
    include:
    - /var/log/system.log
    - /private/var/log/system.log
      start_at: beginning
      processors:
      batch: {}
      resourcedetection:
      detectors: [system, env]
      override: false
      exporters:
      debug:
      verbosity: detailed
      service:
      pipelines:
      logs:
      receivers: [filelog]
      processors: [resourcedetection, batch]
      exporters: [debug]
  * macOS hostmetrics + OTLP:
    receivers:
    hostmetrics:
    collection_interval: 30s
    scrapers:
    cpu: {}
    memory: {}
    disk: {}
    filesystem: {}
    network: {}
    load: {}
    processes: {}
    otlp:
    protocols:
    grpc: {}
    http: {}
    processors:
    batch: {}
    resourcedetection:
    detectors: [system, env]
    override: false
    exporters:
    debug:
    verbosity: detailed
    service:
    pipelines:
    metrics:
    receivers: [hostmetrics, otlp]
    processors: [resourcedetection, batch]
    exporters: [debug]
    traces:
    receivers: [otlp]
    processors: [resourcedetection, batch]
    exporters: [debug]
  * Coralogix toggle (applies to above):
    exporters:
    coralogix:
    endpoint: https://ingress.

    <your-domain>

    private_key: ${env:CORALOGIX_PRIVATE_KEY}
    application_name: "

    <app>

    "
    subsystem_name: "

    <subsystem>

    "
    service:
    pipelines:
    logs:
    exporters: [debug, coralogix]
    metrics:
    exporters: [debug, coralogix]
    traces:
    exporters: [debug, coralogix]
  * EC2 detector opt-in (when on AWS Mac):
    processors:
    resourcedetection:
    detectors: [system, env, ec2]
    override: false

Cloud research summary to fold into design:
- AWS EC2 Mac (mac1 = Intel, mac2 = Apple Silicon) exposes IMDSv2; `resourcedetection` with `ec2` works when allowed; OS images are tied to specific macOS versions and run on dedicated hosts with 24h minimum billing.
- Other providers (MacStadium, Scaleway, maybe Azure/GCP bare-metal labs) offer mac hosts without a standardized metadata service; assume `ec2` detector is unavailable and rely on `system` + `env/file` overrides for resource attributes.
- Default chart should keep `ec2` disabled unless the operator explicitly opts in (e.g., `values.resourcedetection.enableEc2: true`) to avoid failures on local Macs or non-AWS hosts.

Throughout, catalogue macOS log collection options and trade-offs: classic BSD syslog sockets (`/var/run/syslog`) if available, `filelog` against `/var/log/system.log` or app log files, external `log stream` piped to a filelog target when unified logging is required (because exec receiver is absent), and the implications of privacy/SIP restrictions. Note which options support multiline parsing and how to set parsers/`multiline` options in filelog for stack traces.

## Concrete Steps

From the repo root, review the existing linux chart to reuse patterns and spot linux-only pieces:
cd otel-linux-standalone
helm show values . > /tmp/otel-linux-values.yaml
helm template linux-standalone . > /tmp/otel-linux-rendered.yaml
ls .agent to skim prior ExecPlans for structure and reusable validation patterns

Download and unpack a deterministic collector build for macOS (arm64 shown; switch to amd64 if needed):
export OTELCOL_VERSION=0.140.1
mkdir -p /tmp/otelcol-macos
curl -L "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTELCOL_VERSION}/otelcol-contrib_${OTELCOL_VERSION}_darwin_arm64.tar.gz" -o /tmp/otelcol-macos/otelcol-contrib.tar.gz
tar -xzf /tmp/otelcol-macos/otelcol-contrib.tar.gz -C /tmp/otelcol-macos
/tmp/otelcol-macos/otelcol-contrib --version
/tmp/otelcol-macos/otelcol-contrib components > /tmp/otelcol-macos/components.txt
Install telemetry generators locally to avoid missing release artifacts:
GOBIN=/tmp/otelcol-macos go install github.com/open-telemetry/opentelemetry-collector-contrib/cmd/telemetrygen@v0.140.1

Classify macOS-ready components and note gaps by scanning `components.txt`, tagging each receiver/processor/exporter as logs/metrics/traces/both and marking linux-only items (e.g., `journald` present but unusable on mac without systemd, `cgroups`, `docker_stats`, `kubeletstats`) as out-of-scope. Record which log receivers remain viable (filelog, syslog if `/var/run/syslog` exists, TCP/UDP log receivers, fluentforward; `exec` receiver absent) and which enrichment processors are usable.

Craft and run a local macOS test config to exercise host metrics, log capture options, and OTLP ingestion with debug output:
cat > /tmp/otelcol-macos/test.yaml <<'EOF'
receivers:
otlp:
protocols:
grpc:
http:
hostmetrics:
collection_interval: 30s
scrapers:
cpu:
memory:
disk:
filesystem:
network:
load:
processes:
filelog:
include:
- /var/log/system.log
- /private/var/log/system.log
- /tmp/macos-unified.log
  start_at: beginning
  processors:
  batch: {}
  resourcedetection:
  detectors: [system, env]
  override: false
  exporters:
  debug:
  verbosity: detailed
  service:
  pipelines:
  logs:
  receivers: [filelog, otlp]
  processors: [resourcedetection, batch]
  exporters: [debug]
  metrics:
  receivers: [hostmetrics, otlp]
  processors: [resourcedetection, batch]
  exporters: [debug]
  traces:
  receivers: [otlp]
  processors: [resourcedetection, batch]
  exporters: [debug]
  EOF

In another shell, generate test telemetry to verify pipelines:
log stream --style ndjson --type log --predicate 'eventType == logEvent' > /tmp/macos-unified.log 2>/tmp/otelcol-macos/logstream.log &
LOG_PID=$!
OTELCOL_LOG_LEVEL=info /tmp/otelcol-macos/otelcol-contrib --config /tmp/otelcol-macos/test.yaml > /tmp/otelcol-macos/collector.log 2>&1 &
COL_PID=$!
/tmp/otelcol-macos/telemetrygen traces --otlp-endpoint=localhost:4317 --otlp-insecure --duration=15s
/tmp/otelcol-macos/telemetrygen metrics --otlp-endpoint=localhost:4317 --otlp-insecure --duration=15s
echo "mac log smoke test $(date)" >> /tmp/macos-unified.log
kill $COL_PID; kill $LOG_PID
Observe debug exporter output for expected host metrics, the injected log line, and OTLP spans/metrics with resource attributes including `os.type` and `host.name`. If `/var/log/system.log` is sparse or redirects to unified logging, rely on the external `log stream` process populating `/tmp/macos-unified.log`, and confirm filelog tails it correctly. Note any gaps (e.g., privacy prompts, SIP limitations) and propose mitigations (running collector as user with `log` entitlement or ingesting app file logs).

Scaffold and render the macOS chart (new):
cd otel-macos-standalone
make otel-config

# inspect build/otel-config.yaml and verify receivers/processors/exporters match the tested mac config

make helm-template | head -n 50

# install (launchd) once config looks correct; requires sudo

sudo OTELCOL_VERSION=0.140.1 LOGSTREAM_ENABLED=true LOGSTREAM_PATH=/var/log/otel-logstream.ndjson INSTALL_PREFIX=/opt/otelcol ./scripts/install-macos.sh build/otel-config.yaml

Research cloud mac offerings and record detector implications:
- AWS EC2 Mac: note supported macOS versions, bare-metal constraints, network defaults, and confirm `ec2` resource detector behavior on mac instances.
- Check other providers (Google Cloud, Azure, MacStadium, Scaleway) for managed mac hosts, paying attention to access methods (SSH vs console), available OS versions, and metadata services to decide whether cloud detectors apply or if `env`/`file` overrides are needed.
- Document defaults: keep `ec2` detector off unless `values.resourcedetection.enableEc2=true`; when enabled, set `endpoint: http://169.254.169.254` and require IMDSv2 token for AWS-compatible hosts; otherwise rely on `system` + `env` detectors and allow a `values.resourceAttributes` map for overrides.

Draft the macOS Helm chart design: choose location (e.g., `otel-macos-standalone/`), decide whether to vendor the `opentelemetry-collector` dependency or keep it lightweight, and outline values for log sources, hostmetrics scrapers, resource detection defaults, Coralogix exporter wiring, and launchd/unit generation. Compare with linux chart to identify reusable Make targets and templates.
- Plan chart files: `Chart.yaml`, `values.yaml`, `templates/configmap.yaml` for collector config, `templates/launchd-plist.yaml` (rendered to a plist via `helm template` and written by Make), and optional `templates/logstream-helper.yaml` for the NDJSON helper script.
- Build scripts: add `scripts/install-macos.sh` to copy the collector binary/config/plists to `/opt/otelcol`, load launchd services, and start them; add `scripts/uninstall-macos.sh` to unload and remove files.
- Values knobs: `logs.enabled`, `logs.useSyslog`, `logs.useSystemLog`, `logs.logStream.enabled`, `logs.logStream.path` (default `/var/log/otel-logstream.ndjson`), `logs.filelog.include` override, `hostMetrics.enabled`, `hostMetrics.scrapers.*`, `resourcedetection.detectors`, `coralogix.*`, `otlp.receiver` toggles, service user/group override.
- Make targets: `make otel-config` (render `build/otel-config.yaml`), `make install-macos` (downloads v0.140.1, renders config/plists, installs via script), `make uninstall-macos`, `make run-local` (starts collector in foreground with rendered config for quick tests).

## Validation and Acceptance

Validation succeeds when the macOS collector binary runs locally with the test config, emitting host metrics, the injected log line, and generated traces/metrics to the debug exporter with correct resource attributes. Component inventory should clearly state which log/metric/trace receivers are available on macOS and which are excluded. The research should document viable log collection strategies on macOS (filelog, syslog socket, external `log stream` piped to filelog) and enrichment options. A draft Helm design must describe the chart layout, values schema, launchd/service handling, logstream helper, and Make targets. Cloud research must clarify whether `ec2` or other detectors are usable and what fallbacks to apply, with defaults that do not break on local Macs.

## Idempotence and Recovery

Downloading and unpacking the collector to `/tmp/otelcol-macos` is safe to repeat; rerun the curl/tar steps if versions change. Stop the collector process with Ctrl+C (and kill any `log stream` helpers) before re-running configs. Remove `/tmp/otelcol-macos` to clean up. When experimenting with `log stream`, redirect output to a temporary file and delete it afterward to avoid growth. Do not modify system log retention settings.

## Artifacts and Notes

Capture these artifacts for future reference:
/tmp/otelcol-macos/components.txt # macOS component inventory
/tmp/otelcol-macos/test.yaml # working sample config with hostmetrics/filelog/OTLP
/tmp/otelcol-macos/collector.log # debug exporter output proving host metrics, system.log + unified log ingestion, OTLP traces/metrics
/tmp/otelcol-macos/logstream.log # stdout/stderr from the bounded log stream helper
/tmp/otelcol-macos/telemetrygen-*.log # generator outputs used during validation
otel-macos-standalone/build/otel-config.yaml # rendered Helm config from the new chart scaffold
Notes summarizing cloud provider findings and detector applicability
Proposed Helm chart layout and values schema differences vs linux chart
Static macOS config snapshots for upstream preset design (filelog/syslog/logstream variants, hostmetrics+OTLP, coralogix toggle, ec2 opt-in)

## Interfaces and Dependencies

Critical collector components to validate and rely on:
Receivers: hostmetrics (with cpu/memory/disk/filesystem/network/load/processes scrapers), filelog (with data from system.log or externally piped `log stream` output), otlp (grpc/http).
Processors: resourcedetection (detectors system, env, optional ec2), batch, attributes/transform if log parsing is needed for enrichment.
Exporters: debug for local validation, otlphttp/otlp via Coralogix exporter settings for production wiring.
Deployment dependencies:
Helm 3 for templating, values schema patterned after `otel-linux-standalone`.
macOS service management via launchd (plist generation), with optional Homebrew integration kept out-of-band.
Optional cloud metadata access (AWS IMDS for `ec2` detector when running on EC2 Mac); otherwise environment/file overrides for `service.name`, `deployment.environment`, and region metadata.

Revision note (2025-11-21 / Codex): Renamed plan to `execplan-macos-telemetry.md`, bumped collector version to 0.140.1, and expanded macOS log collection research scope (unified logging via `log stream`, syslog/filelog options, multiline handling guidance).
Revision note (2025-11-21 / Codex): Added component inventory results, recorded local macOS collector validation (hostmetrics, filelog with unified logging via external `log stream`, OTLP via telemetrygen), and documented surprises around missing exec receiver, multiline operator rejection, and `ec2` detector failures off-cloud.
Revision note (2025-11-21 / Codex): Scaffolded `otel-macos-standalone`, rendered config, removed cloud detectors, and added launchd install/uninstall scripts plus usage.
