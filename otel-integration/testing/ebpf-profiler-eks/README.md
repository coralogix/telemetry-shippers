# EKS eBPF Profiler Stack Test Plan

This plan is designed to be executed by a person or another agent. It is self-contained and describes exactly how to create an EKS cluster that supports eBPF profiling, deploy the Coralogix agent, cluster collector, and eBPF profiler, run a renamed telemetrygen workload, and verify the two required features: deployment environment name propagation and annotation-based service naming.

This plan assumes the repository root is the working directory and uses the assets under `otel-integration/testing/ebpf-profiler-eks/`.

## Purpose / Big Picture

You will provision an EKS cluster using Amazon Linux 2023 (modern kernel with BTF), deploy the Coralogix OpenTelemetry integration (agent + cluster collector + eBPF profiler), and deploy telemetrygen with a custom name and service annotation. The validation step checks logs to ensure that:

- `deployment.environment.name` equals the expected value.
- `service.name` is derived from the configured pod annotation.

You will manually verify the same in Coralogix.

## Context and Orientation

Key files and what they do:

- `otel-integration/testing/ebpf-profiler-eks/Makefile`: the entry point for cluster creation, installation, and verification targets.
- `otel-integration/testing/ebpf-profiler-eks/eks-ebpf-profiler.yaml`: EKS cluster definition using Amazon Linux 2023 for eBPF support.
- `otel-integration/testing/ebpf-profiler-eks/values-ebpf-profiler.yaml`: Helm values enabling agent + cluster collector + eBPF profiler with annotation discovery.
- `otel-integration/testing/ebpf-profiler-eks/telemetrygen-traces.yaml`: deployment manifest for telemetrygen, renamed and annotated for service name testing.
- `otel-integration/k8s-helm/`: the Coralogix integration chart installed by the Makefile.

Terms used:

- eBPF profiler: the OpenTelemetry Collector distribution that captures CPU profiles via eBPF.
- BTF: kernel metadata required by portable eBPF programs.
- Annotation-based service naming: deriving `service.name` from pod annotations configured in the profiles K8s attributes preset.

## Plan of Work

1) Render chart presets to confirm the templates include resource detection, profiles K8s attributes, and annotation discovery receivers.
2) Create the EKS cluster in the configured region using AL2023 nodes.
3) Create the Coralogix API key secret.
4) Install the stack (agent + cluster collector + eBPF profiler).
5) Deploy telemetrygen (renamed and annotated).
6) Verify:
   - Cluster collector is configured to discover Prometheus-annotated pods.
   - eBPF profiler logs contain deployment environment name and the annotation-derived service name.
   - Manually confirm data in Coralogix.

## Concrete Steps

Run all commands from `otel-integration/testing/ebpf-profiler-eks`.

1) Render preset checks:

    make test-ebpf-profiler-presets

Expected evidence includes lines containing:

    deployment.environment.name=ebpf-eks
    k8sattributes/profiles
    transform/profiles
    receiver_creator
    k8s_observer

2) Create the EKS cluster:

    make create-ebpf-profiler

3) Create the Coralogix secret and install the stack:

    CORALOGIX_API_KEY=... make create-ebpf-secret
    CORALOGIX_API_KEY=... make install-ebpf-profiler

4) Deploy telemetrygen:

    make deploy-telemetrygen

5) Verify config and logs:

    make check-cluster-collector-config
    make check-ebpf-profiler-logs

## Validation and Acceptance

All of the following must be true:

- The preset check output includes `deployment.environment.name=ebpf-eks` and the profiles K8s attributes processors.
- The cluster collector ConfigMap includes receiver_creator with k8s_observer and prometheus_simple, indicating annotation discovery is enabled.
- eBPF profiler logs include:
  - `deployment.environment.name=ebpf-eks`
  - `service.name=ebpf-annotated-service`
- Manual check in Coralogix shows the telemetrygen data under the annotated service name and the deployment environment name set to `ebpf-eks`.

## Idempotence and Recovery

All Makefile targets are safe to re-run. `kubectl apply` is idempotent. Helm uses upgrade/install. To retry from scratch:

- Uninstall the release:

    helm uninstall otel-ebpf-profiler -n coralogix-otel

- Delete the cluster:

    make clean-ebpf-profiler

## Notes

Defaults used by the Makefile (override via environment if needed):

- Region: `eu-central-1`
- Cluster name: `otel-integration-ebpf-profiler`
- Namespace: `coralogix-otel`
- Telemetrygen deployment name: `ebpf-telemetrygen`
- Deployment environment name: `ebpf-eks`
- Coralogix domain: `eu2.coralogix.com`
- Annotation-derived service name: `ebpf-annotated-service`
