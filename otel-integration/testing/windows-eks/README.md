# EKS Windows Test Plan for otel-integration

This plan is written to be executed by a human or another agent. It is self-contained and describes exactly how to create a mixed Linux/Windows EKS cluster, install `otel-integration` in Windows mode, enable collector debug logging and debug exporter verbosity `detailed`, and verify that Windows workload logs are collected.

This plan assumes the repository root is the working directory and uses assets under `otel-integration/testing/windows-eks/`.

## Purpose / Big Picture

After completing this workflow, you will have:

- A mixed Linux/Windows EKS cluster suitable for testing the Windows daemonset.
- `otel-integration` installed in Windows mode.
- Collector debug logging enabled (`global.logLevel=debug`).
- `debug` exporter enabled with `verbosity: detailed` for the Windows agent.
- Proof that Windows workload logs are ingested by the collector (visible in Windows agent debug-exporter output).

## Context and Orientation

Key files and what they do:

- `otel-integration/testing/windows-eks/Makefile`: entry point for provisioning, install, and verification.
- `otel-integration/testing/windows-eks/eks-windows.yaml`: EKS cluster definition with Linux + Windows node groups.
- `otel-integration/testing/windows-eks/values-windows-debug.yaml`: overrides to enforce debug collector behavior:
  - `global.logLevel: debug`
  - `opentelemetry-agent-windows.config.exporters.debug.verbosity: detailed`
- `otel-integration/testing/windows-eks/windows-log-generator.yaml`: test Windows workload that emits a unique log marker.
- `otel-integration/k8s-helm/values-windows.yaml`: base chart values for mixed OS installation.

## Prerequisites

Install and configure:

- `aws` CLI configured with credentials for EKS.
- `eksctl`
- `kubectl`
- `helm`
- `rg` (ripgrep), used by Makefile verifications.

Required runtime input:

- `CORALOGIX_API_KEY` environment variable (or pass inline to `make`).
- Coralogix domain (default is `eu2.coralogix.com`, override with `CORALOGIX_DOMAIN`).

Defaults used by the Makefile (override as needed):

- AWS profile: `research`
- AWS region: `eu-west-1`
- Cluster name: `otel-integration-windows-cluster`
- Namespace: `coralogix-otel`
- Helm release: `otel-windows`
- Windows log marker: `WINDOWS-OTEL-LOG-CHECK`

## Plan of Work

1. Create the EKS cluster from `eks-windows.yaml`.
2. Create/update the Coralogix API key secret in `coralogix-otel`.
3. Install `otel-integration` using:
   - base Windows values: `../../k8s-helm/values-windows.yaml`
   - debug overrides: `values-windows-debug.yaml`
4. Deploy a Windows workload that continuously emits test logs.
5. Verify:
   - Windows agent config has debug exporter `verbosity: detailed`.
   - Collector log level is `debug`.
   - Collector debug-exporter output contains the Windows log marker.

## Concrete Steps

Run all commands from `otel-integration/testing/windows-eks`.

1. Review targets and defaults:

   make help

2. Create cluster:

   make create-windows-cluster

3. Install integration and deploy test workload:

   CORALOGIX_API_KEY=YOUR_API_KEY make setup-windows

   If your Coralogix domain is not `eu2.coralogix.com`, pass it explicitly:

   CORALOGIX_API_KEY=YOUR_API_KEY CORALOGIX_DOMAIN=ingress.eu1.coralogix.com make setup-windows

4. Verify debug configuration:

   make verify-debug-settings

5. Verify Windows log collection:

   make verify-windows-log-collection

## Validation and Acceptance

Acceptance criteria:

- `make verify-debug-settings` succeeds and confirms:
  - `verbosity: detailed` in `coralogix-opentelemetry-windows-agent` ConfigMap.
  - collector logs level is `debug`.
  - `debug` exporter is part of active pipelines.
- `make verify-windows-log-collection` succeeds and shows the marker:
  - from workload logs (`kubectl logs deployment/windows-log-generator ...`)
  - from Windows agent daemonset logs (`kubectl logs daemonset/coralogix-opentelemetry-windows ...`)

Manual Coralogix check (recommended):

- Query logs for `WINDOWS-OTEL-LOG-CHECK` and confirm records from Windows nodes are present.

## Idempotence and Recovery

- `create-coralogix-secret`, `install-otel-integration-windows`, and `deploy-windows-log-generator` are idempotent and safe to re-run.
- If rollout fails, run:
  - `make write-kubeconfig`
  - `make install-otel-integration-windows`
  - `make deploy-windows-log-generator`
- To reset only workload:
  - `make delete-windows-log-generator`
  - `make deploy-windows-log-generator`

## Cleanup

Run from `otel-integration/testing/windows-eks`:

- Remove workload:

  make delete-windows-log-generator

- Uninstall chart:

  make uninstall-otel-integration

- Delete cluster:

  make delete-windows-cluster

## Notes

- If you use Windows Server 2022 nodes, update the Windows collector image tag in `otel-integration/k8s-helm/values-windows.yaml` to a `-windows2022` tag before running installation.
