# OpenTelemetry eBPF Instrumentation (OBI) — ECS EC2

[OBI](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation) is
zero-code, eBPF-based instrumentation that captures application spans and metrics
(HTTP, gRPC, SQL, Redis, Kafka, GenAI, …) without touching your application code.

On ECS EC2 it runs as a **privileged sidecar** in the same task as the Coralogix
OpenTelemetry collector. Because that task is host-networked, OBI exports over
OTLP to the collector on `127.0.0.1` (`4317` gRPC for traces, `4318` HTTP for
metrics), which forwards to Coralogix. This keeps OBI coupled to the shipper: one
task, one lifecycle, one place to configure.

This mirrors the k8s-helm OBI integration
(`otel-integration/k8s-helm`, chart `opentelemetry-ebpf-instrumentation`), reusing
the same OBI version and config, with the Kubernetes-only pieces removed
(K8s metadata attributes, the K8s metadata cache, K8s owner-name network filters)
and **host-process discovery** (`open_ports` / `exe_path`) replacing the
Kubernetes namespace selector.

## Enabling OBI

OBI is **disabled by default**. Enable it via the Terraform variable:

```hcl
# terraform.tfvars
enable_obi = true
```

Then `terraform apply` as usual. This:

1. Writes the OBI config (`obi/obi-config.yaml`) to the host at
   `/etc/obi/obi-config.yml` via the EC2 launch template's user-data.
2. Adds a privileged `coralogix-obi` sidecar to the collector task definition,
   bind-mounting that config read-only at `OTEL_EBPF_CONFIG_PATH`, and reusing the
   task's existing eBPF host mounts (`/proc`, `/sys/fs/cgroup`, `/sys/kernel/debug`,
   `/sys/fs/bpf`, `/sys/kernel/tracing`).

The instances already set `kernel.perf_event_paranoid=1` (launch-template
user-data), which OBI needs.

## Configuration

The config is authored in the chart's `values.yaml` (`obi.config`) and rendered
into `obi/obi-config.yaml`:

```bash
make obi-config
```

Terraform variables (see `terraform/variables.tf`):

| Variable | Default | Purpose |
| --- | --- | --- |
| `enable_obi` | `false` | Run the OBI sidecar. |
| `obi_image` | `ghcr.io/open-telemetry/opentelemetry-ebpf-instrumentation/ebpf-instrument` | OBI image repository. |
| `obi_image_version` | `v0.10.0` | OBI image tag (kept in sync with k8s-helm). |
| `obi_context_propagation` | `headers,tcp` | eBPF distributed context propagation mode; `disabled` to turn off. |
| `obi_config` | `null` | Full config override. When set, replaces `obi/obi-config.yaml` verbatim. |

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

To narrow it, edit `obi.config.discovery` in `values.yaml`, re-run
`make obi-config`, and `terraform apply` — or pass a complete config via the
`obi_config` Terraform variable.

## Notes

- The sidecar is `essential = false`, so if OBI crashes it does not take down the
  collector; ECS restarts it independently.
- OBI requires a privileged container and host PID/network — all already provided
  by the collector task.
