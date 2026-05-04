#!/usr/bin/env bash
#
# Updates the Fleet Manager's chart-version mappings so it knows:
#   - which otel-integration chart version maps to which opentelemetry-collector
#     chart version (otel-integration mapping), and
#   - which opentelemetry-collector chart version maps to which Collector
#     appVersion (collector mapping).
#
# High-level flow:
#   1. Resolves the opentelemetry-collector chart version from the local
#      otel-integration Chart.yaml (or accepts it via --chart-version).
#   2. Looks up the matching appVersion by querying the Coralogix Helm repo
#      (or accepts it via --app-version).
#   3. Updates the mapping files in a Fleet Manager Helm Data checkout.
#   4. Reports the result and optionally writes key environment variables to a
#      file (--output-env) for downstream CI consumption.
#
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage: update-fleet-manager-collector-chart-map.sh [options]

Options:
  --chart-file <path>                   Path to otel-integration Chart.yaml
  --integration-chart-version <version> Override otel-integration chart version
  --chart-version <version>             Override opentelemetry-collector chart version (skips reading Chart.yaml)
  --app-version <version>               Override appVersion (skips helm lookup)
  --output-env <path>                   Write environment key/values to this file
  -h, --help                            Show this help text

Set FLEET_MANAGER_HELM_DATA_DIR to the Fleet Manager Helm Data directory to update.
EOF
  exit 1
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$repo_root" ]; then
  repo_root="$(cd "$script_dir/.." && pwd)"
fi

chart_file=""
integration_chart_version=""
chart_version=""
app_version=""
output_env=""

while [ $# -gt 0 ]; do
  case "$1" in
    --chart-file)
      chart_file="${2:-}"
      shift 2
      ;;
    --integration-chart-version)
      integration_chart_version="${2:-}"
      shift 2
      ;;
    --chart-version)
      chart_version="${2:-}"
      shift 2
      ;;
    --app-version)
      app_version="${2:-}"
      shift 2
      ;;
    --output-env)
      output_env="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      ;;
  esac
done


if ! command -v yq >/dev/null 2>&1; then
  echo "yq is required." >&2
  exit 1
fi

resolve_collector_chart_version_script="$script_dir/resolve-collector-chart-version.sh"
resolve_integration_chart_version_script="$script_dir/resolve-integration-chart-version.sh"

if [ -z "$chart_file" ]; then
  chart_file="$repo_root/otel-integration/k8s-helm/Chart.yaml"
fi

if [ -z "$integration_chart_version" ]; then
  integration_chart_version="$("$resolve_integration_chart_version_script" "$chart_file")"
fi

if [ -z "$integration_chart_version" ]; then
  echo "Integration chart version is empty." >&2
  exit 1
fi

if [ -z "$chart_version" ]; then
  chart_version="$("$resolve_collector_chart_version_script" "$chart_file")"
fi

if [ -z "$chart_version" ]; then
  echo "Chart version is empty." >&2
  exit 1
fi

if [ -z "$app_version" ]; then
  if ! command -v helm >/dev/null 2>&1; then
    echo "helm is required to resolve appVersion. Provide --app-version or install helm." >&2
    exit 1
  fi

  helm repo add coralogix https://cgx.jfrog.io/artifactory/coralogix-charts-virtual --force-update >/dev/null
  helm repo update coralogix >/dev/null
  app_version="$(
    helm show chart coralogix/opentelemetry-collector --version "$chart_version" \
      | awk -F': *' '
        $1 == "appVersion" {
          value = $2
          sub(/[[:space:]]*#.*/, "", value)
          gsub(/["'"'"']/, "", value)
          print value
          exit
        }
      '
  )"
fi

if [ -z "$app_version" ]; then
  echo "appVersion is empty for chart version $chart_version." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

map_dir="${FLEET_MANAGER_HELM_DATA_DIR:-}"
if [ -z "$map_dir" ]; then
  echo "Fleet Manager Helm Data directory is required. Set FLEET_MANAGER_HELM_DATA_DIR." >&2
  exit 1
fi

if [ ! -d "$map_dir" ]; then
  echo "Fleet Manager Helm Data directory not found: $map_dir" >&2
  exit 1
fi

mapping_updated="false"
map_dir="${map_dir%/}"

run_add_mapping() {
  local map_type="$1" map_file="$2" from_version="$3" to_version="$4" target_key

  case "$map_type" in
    collector)
      target_key="collector_image_tag"
      ;;
    otel-integration)
      target_key="collector_chart_version"
      ;;
    *)
      echo "Unknown map type: $map_type" >&2
      exit 1
      ;;
  esac

  if [ ! -f "$map_file" ]; then
    echo "Mapping file not found: $map_file" >&2
    exit 1
  fi

  if jq -e --arg cv "$from_version" '.mappings[]? | select(.chart_version == $cv)' "$map_file" >/dev/null 2>&1; then
    echo "Mapping already exists for chart_version=$from_version"
    return 0
  fi

  tmp="$(mktemp "${map_file}.XXXXXX")"
  jq \
    --arg cv "$from_version" \
    --arg key "$target_key" \
    --arg val "$to_version" \
    '.mappings += [{"chart_version": $cv} + {($key): $val}] | .mappings |= (sort_by(.chart_version | split(".") | map(tonumber)) | reverse)' \
    "$map_file" > "$tmp"

  mv "$tmp" "$map_file"
  mapping_updated="true"
  echo "Added: chart_version=$from_version -> $target_key=$to_version"
}

# ── otel-integration mapping ───────────────────────────────────────────
echo "--- otel-integration mapping: $integration_chart_version -> $chart_version ---"
run_add_mapping otel-integration "$map_dir/otel_integration_chart_versions_map.json" "$integration_chart_version" "$chart_version"

# ── collector mapping ──────────────────────────────────────────────────
echo "--- collector mapping: $chart_version -> $app_version ---"
run_add_mapping collector "$map_dir/collector_chart_versions_map.json" "$chart_version" "$app_version"

echo "Fleet Manager Helm Data dir: $map_dir"
if [ "$mapping_updated" = "true" ]; then
  if git -C "$map_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Diff:"
    git -C "$map_dir" --no-pager diff || true
  fi
else
  echo "No changes made."
fi

if [ -n "$output_env" ]; then
  cat > "$output_env" <<EOF
FLEET_MANAGER_HELM_DATA_DIR=$map_dir
INTEGRATION_CHART_VERSION=$integration_chart_version
CHART_VERSION=$chart_version
APP_VERSION=$app_version
MAPPING_UPDATED=$mapping_updated
EOF
fi
