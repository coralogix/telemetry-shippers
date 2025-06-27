# AGENTS: Otel Integration Upgrade

These instructions apply to the `otel-integration` folder.

When you upgrade the opentelemetry-collector chart version used by the Coralogix OpenTelemetry Integration, follow this process:

1. **Check available versions**
   - Review the opentelemetry-collector chart CHANGELOG at:
     https://raw.githubusercontent.com/coralogix/opentelemetry-helm-charts/refs/heads/main/charts/opentelemetry-collector/CHANGELOG.md
   - Only use versions listed in that CHANGELOG.
   - If the user did not specify a target version, ask them which version they want to upgrade to.

2. **Update the chart version**
   - Bump the version in `k8s-helm/Chart.yaml`.
   - Bump the same version under the `global` key in `k8s-helm/values.yaml`.
   - Use semantic versioning. Typically this is a patch bump (`X.Y.Z` becomes `X.Y.Z+1`).
   - If the collector itself has a version bump in the opentelemetry-collector CHANGELOG, bump the minor version (`X.Y.Z` becomes `X.Y+1.0`).

3. **Update dependencies**
   - Update all `opentelemetry-collector` dependencies in `k8s-helm/Chart.yaml` to the new version:
     `opentelemetry-agent`, `opentelemetry-agent-windows`, `opentelemetry-cluster-collector`, `opentelemetry-receiver`, and `opentelemetry-gateway`.

4. **Update the changelog**
   - Add an entry to `CHANGELOG.md` using the format `### vX.Y.Z / YYYY-MM-DD`.
   - Use the current date (`date +%Y-%m-%d`).
   - Copy the relevant entries from the opentelemetry-collector changelog.

## Dependencies Structure
- `opentelemetry-collector`: main collector charts (five variants)
- `coralogix-ebpf-agent`: eBPF agent
- `coralogix-ebpf-profiler`: eBPF profiler

## Important Files
- `k8s-helm/Chart.yaml`: main chart definition
- `CHANGELOG.md`: version history
- `UPGRADING.md`: breaking changes and upgrade notes
