# OpenTelemetry eBPF Instrumentation (OBI) — Linux standalone

[OBI](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation) is
zero-code, eBPF-based instrumentation that captures application spans and metrics
(HTTP, gRPC, SQL, Redis, Kafka, GenAI, …) without touching your application code.

On a standalone Linux host it runs as a **systemd unit (`obi.service`) as root**,
alongside the `otelcol-contrib` collector installed by this integration. OBI
exports over OTLP to the local collector (`127.0.0.1:4317` gRPC for traces,
`127.0.0.1:4318` HTTP for metrics), which forwards to Coralogix. This keeps OBI
coupled to the shipper: same host, same install flow, one place to configure.

This mirrors the k8s-helm OBI integration
(`otel-integration/k8s-helm`, chart `opentelemetry-ebpf-instrumentation`), reusing
the same OBI version and config, with the Kubernetes-only pieces removed
(K8s metadata attributes, the K8s metadata cache, K8s owner-name network filters)
and **host-process discovery** (`open_ports` / `exe_path`) replacing the
Kubernetes namespace selector.

## Enabling OBI

OBI is **disabled by default**. Enable it via the Terraform variable (or the
`ENABLE_OBI` make variable):

```bash
# from otel-linux-standalone/
AWS_PROFILE=research \
AWS_REGION=eu-west-1 \
CORALOGIX_API_KEY="$API_KEY" \
ENABLE_OBI=true \
make deploy
```

On boot, the instance's user-data:

1. Downloads the OBI release tarball for the host architecture
   (`obi-<version>-linux-<amd64|arm64>.tar.gz`) and installs the `obi` binary to
   `/usr/local/bin/obi`.
2. Writes the OBI config (`obi/obi-config.yaml`) to `/etc/obi/obi-config.yml`.
3. Installs and starts an `obi.service` systemd unit running as root, with
   `OTEL_EBPF_CONFIG_PATH` pointing at that config and
   `OTEL_EBPF_BPF_CONTEXT_PROPAGATION` set from `obi_context_propagation`.

`obi.service` is ordered `After=`/`Requires=` the collector service.

## Configuration

The config is authored in the chart's `values.yaml` (`obi.config`) and rendered
into `obi/obi-config.yaml`:

```bash
make obi-config
```

(`make deploy` runs `obi-config` automatically.)

Make / Terraform variables:

| Make var | Terraform var | Default | Purpose |
| --- | --- | --- | --- |
| `ENABLE_OBI` | `enable_obi` | `false` | Install & run the OBI systemd unit. |
| `OBI_VERSION` | `obi_version` | `v0.10.0` | OBI release tag (kept in sync with k8s-helm). |
| `OBI_CONTEXT_PROPAGATION` | `obi_context_propagation` | `headers,tcp` | eBPF context propagation mode; `disabled` to turn off. |
| — | `obi_config_path` | rendered `obi/obi-config.yaml` | Path to the OBI config injected into the host. |

### Scoping what gets instrumented

The default discovery instruments **every process with a listening port**,
excluding the collector and OBI itself:

```yaml
discovery:
  instrument:
    - open_ports: "1-65535"
  exclude_instrument:
    - exe_path: "*ebpf-instrument*"
    - exe_path: "*otelcol*"
    - exe_path: "*obi*"
```

To narrow it, edit `obi.config.discovery` in `values.yaml` and re-run
`make obi-config` before deploying.

## Verifying

```bash
# on the host
systemctl status obi.service
journalctl -u obi.service -n 50
```

The bootstrap does **not** fail if OBI cannot start (eBPF support is
kernel-dependent); check the journal if spans/metrics do not appear in Coralogix.
