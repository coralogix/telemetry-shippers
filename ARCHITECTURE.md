# Architecture

This repository is the downstream validation surface for OpenTelemetry Collector Helm chart upgrades.

## Repo roles

### This repository

Owns:

- downstream integration chart wiring under `otel-integration/k8s-helm`
- downstream e2e coverage and validation workflow
- harness docs and references for agent-driven upgrades

Does not own:

- upstream `charts/opentelemetry-collector` source of truth
- OpenTelemetry Collector core code
- OpenTelemetry Collector contrib code

### Upstream repositories used during upgrades

- chart repo clone:
  - `git@github.com:coralogix/opentelemetry-helm-charts.git`
- Collector core:
  - `https://github.com/open-telemetry/opentelemetry-collector`
- Collector contrib:
  - `https://github.com/open-telemetry/opentelemetry-collector-contrib`

## Validation topology

Normal flow:

1. clone the upstream chart repo outside this repository
2. upgrade and validate the chart in that upstream clone
3. temporarily point `otel-integration/k8s-helm/Chart.yaml` to the local upgraded chart with `file://`
4. refresh Helm dependencies
5. run downstream e2e from this repository
6. revert temporary dependency rewiring

## Temporary vs committable changes

### Committable here

- harness docs
- explicit downstream compatibility changes approved by the user
- flaky-test fixes approved or requested by the user

### Temporary only

- local `file://` dependency rewiring for test runs
- local scratch logs, notes, port-forwards, kubeconfigs

### Approval boundary

Do not change downstream tests, fixtures, or expected outputs unless explicitly requested.

If an upstream release changes emitted metrics, scope names, or semantics, treat that as a real compatibility decision, not an automatic local test tweak.
