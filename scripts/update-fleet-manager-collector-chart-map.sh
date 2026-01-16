#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage: update-fleet-manager-collector-chart-map.sh [options]

Options:
  --chart-file <path>           Path to otel-integration Chart.yaml
  --chart-version <version>     Override chart version (skips reading Chart.yaml)
  --app-version <version>       Override appVersion (skips helm lookup)
  --fleet-manager-dir <path>    Existing Fleet Manager checkout to modify
  --fleet-manager-repo <url>    Fleet Manager git URL (default: https://github.com/coralogix/fleet-manager.git)
  --fleet-manager-branch <name> Fleet Manager branch to clone (default: master)
  --output-env <path>           Write environment key/values to this file
  -h, --help                    Show this help text

This script updates a local Fleet Manager copy by running:
  scripts/add-chart-version-mapping.sh pkg/helm/data/collector_chart_versions_map.json <chart_version> <app_version>

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

if [ -z "$chart_file" ]; then
  chart_file="$repo_root/otel-integration/k8s-helm/Chart.yaml"
fi

if [ -z "$chart_version" ]; then
  chart_version="$("$script_dir/get-otel-collector-chart-version.sh" "$chart_file")"
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

mapping_file="$fleet_manager_dir/pkg/helm/data/collector_chart_versions_map.json"
if [ ! -f "$mapping_file" ]; then
  echo "Mapping file not found: $mapping_file" >&2
  exit 1
fi

mapping_updated="false"
mapping_message=""

set +e
output="$(
  "$fleet_manager_dir/scripts/add-chart-version-mapping.sh" \
    "$mapping_file" \
    "$chart_version" \
    "$app_version" 2>&1
)"
status=$?
set -e

if [ $status -ne 0 ]; then
  if echo "$output" | grep -q "mapping already exists"; then
    mapping_message="$output"
  else
    echo "$output" >&2
    exit $status
  fi
else
  mapping_updated="true"
  mapping_message="$output"
fi

echo "$mapping_message"
if [ "$mapping_updated" = "true" ] && git -C "$fleet_manager_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Diff:"
  git -C "$fleet_manager_dir" --no-pager diff -- "$mapping_file" || true
fi

echo "Fleet Manager working dir: $fleet_manager_dir"
if [ "$mapping_updated" = "true" ]; then
  echo "Updated mapping: $chart_version -> $app_version"
else
  echo "No changes made."
fi

if [ -n "$output_env" ]; then
  cat > "$output_env" <<EOF
FLEET_MANAGER_DIR=$fleet_manager_dir
CHART_VERSION=$chart_version
APP_VERSION=$app_version
MAPPING_UPDATED=$mapping_updated
EOF
fi
