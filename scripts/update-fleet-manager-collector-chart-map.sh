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
#   3. Clones (or reuses) a local Fleet Manager checkout.
#   4. Invokes Fleet Manager's own add-chart-version-mapping.sh to insert:
#        a. otel-integration chart version -> collector chart version
#           (into otel_integration_chart_versions_map.json)
#        b. collector chart version -> app version
#           (into collector_chart_versions_map.json)
#   5. Reports the result and optionally writes key environment variables to a
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
  --fleet-manager-dir <path>            Existing Fleet Manager checkout to modify
  --fleet-manager-repo <url>            Fleet Manager git URL (default: https://github.com/coralogix/fleet-manager.git)
  --fleet-manager-branch <name>         Fleet Manager branch to clone (default: master)
  --output-env <path>                   Write environment key/values to this file
  -h, --help                            Show this help text

If --fleet-manager-dir is not provided, a temporary clone is created and left on disk.
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
fleet_manager_dir=""
fleet_manager_repo="https://github.com/coralogix/fleet-manager.git"
fleet_manager_branch="master"
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
    --fleet-manager-dir)
      fleet_manager_dir="${2:-}"
      shift 2
      ;;
    --fleet-manager-repo)
      fleet_manager_repo="${2:-}"
      shift 2
      ;;
    --fleet-manager-branch)
      fleet_manager_branch="${2:-}"
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
  echo "jq is required by Fleet Manager's add-chart-version-mapping.sh script." >&2
  exit 1
fi

if [ -n "$fleet_manager_dir" ]; then
  if [ -d "$fleet_manager_dir" ]; then
    if [ ! -d "$fleet_manager_dir/.git" ]; then
      echo "Fleet Manager directory exists but is not a git repo: $fleet_manager_dir" >&2
      exit 1
    fi
  else
    git clone --depth 1 --branch "$fleet_manager_branch" "$fleet_manager_repo" "$fleet_manager_dir"
  fi
else
  fleet_manager_dir="$(mktemp -d "${TMPDIR:-/tmp}/fleet-manager.XXXXXX")"
  git clone --depth 1 --branch "$fleet_manager_branch" "$fleet_manager_repo" "$fleet_manager_dir"
fi

if [ ! -x "$fleet_manager_dir/scripts/add-chart-version-mapping.sh" ]; then
  echo "Expected script not found in Fleet Manager checkout: $fleet_manager_dir/scripts/add-chart-version-mapping.sh" >&2
  exit 1
fi

add_mapping_script="$fleet_manager_dir/scripts/add-chart-version-mapping.sh"
mapping_updated="false"

# Helper: call add-chart-version-mapping.sh and handle "already exists" gracefully.
# Runs from inside the fleet-manager dir so relative paths resolve correctly.
run_add_mapping() {
  local map_type="$1" from_version="$2" to_version="$3"
  set +e
  output="$(cd "$fleet_manager_dir" && "$add_mapping_script" --map "$map_type" "$from_version" "$to_version" 2>&1)"
  status=$?
  set -e

  if [ $status -ne 0 ]; then
    if echo "$output" | grep -q "mapping already exists"; then
      echo "$output"
    else
      echo "$output" >&2
      exit $status
    fi
  else
    mapping_updated="true"
    echo "$output"
  fi
}

# ── otel-integration mapping ───────────────────────────────────────────
echo "--- otel-integration mapping: $integration_chart_version -> $chart_version ---"
run_add_mapping otel-integration "$integration_chart_version" "$chart_version"

# ── collector mapping ──────────────────────────────────────────────────
echo "--- collector mapping: $chart_version -> $app_version ---"
run_add_mapping collector "$chart_version" "$app_version"

# ── summary ────────────────────────────────────────────────────────────
echo "Fleet Manager working dir: $fleet_manager_dir"
if [ "$mapping_updated" = "true" ]; then
  if git -C "$fleet_manager_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Diff:"
    git -C "$fleet_manager_dir" --no-pager diff || true
  fi
else
  echo "No changes made."
fi

if [ -n "$output_env" ]; then
  cat > "$output_env" <<EOF
FLEET_MANAGER_DIR=$fleet_manager_dir
INTEGRATION_CHART_VERSION=$integration_chart_version
CHART_VERSION=$chart_version
APP_VERSION=$app_version
MAPPING_UPDATED=$mapping_updated
EOF
fi
