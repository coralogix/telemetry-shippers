#!/usr/bin/env bash
set -euo pipefail

CHART_DIR="${CHART_DIR:-otel-integration/k8s-helm}"
GOLDEN_DIR="${GOLDEN_DIR:-${CHART_DIR}/tests/golden}"
RELEASE_NAME="${HELM_GOLDEN_RELEASE_NAME:-render-check}"
DOMAIN="${HELM_GOLDEN_DOMAIN:-eu2.coralogix.com}"
CLUSTER_NAME="${HELM_GOLDEN_CLUSTER_NAME:-golden-render}"
UPDATE_GOLDEN=false

cases=(
  "tail-sampling:tail-sampling-values.yaml"
  "windows:values-windows.yaml"
  "eks-fargate:values-eks-fargate.yaml"
  "ebpf-profiler:values-ebpf-profiler.yaml"
)

usage() {
  cat <<'EOF'
Usage: .github/scripts/check-helm-golden-renders.sh [--update]

Renders high-risk otel-integration Helm presets and compares them with the
checked-in golden files.

  --update   Regenerate the checked-in golden files instead of diffing them.
EOF
}

while (($#)); do
  case "$1" in
    --update)
      UPDATE_GOLDEN=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

render_case() {
  local name="$1"
  local values_file="$2"
  local output_file="$3"

  helm template "$RELEASE_NAME" "$CHART_DIR" \
    -f "${CHART_DIR}/values.yaml" \
    -f "${CHART_DIR}/${values_file}" \
    --set-string "global.domain=${DOMAIN}" \
    --set-string "global.clusterName=${CLUSTER_NAME}" |
    sed -e 's/[[:blank:]]*$//' \
    | awk '
        /^$/ { blanks++; next }
        /^---$/ { blanks = 0; print; next }
        {
          while (blanks > 0) {
            print "";
            blanks--;
          }
          print;
        }
        END {
          while (blanks > 0) {
            print "";
            blanks--;
          }
        }
      ' \
    > "$output_file"
}

require_cmd helm
require_cmd diff
require_cmd sed
require_cmd awk

helm repo add --force-update open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null
helm repo add --force-update coralogix-charts-virtual https://cgx.jfrog.io/artifactory/coralogix-charts-virtual >/dev/null
helm repo add --force-update coralogix-charts https://cgx.jfrog.io/artifactory/coralogix-charts >/dev/null
helm repo update >/dev/null
helm dependency build "$CHART_DIR"

if [ "$UPDATE_GOLDEN" = true ]; then
  mkdir -p "$GOLDEN_DIR"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

failed=0
for case in "${cases[@]}"; do
  name="${case%%:*}"
  values_file="${case#*:}"
  actual="${tmpdir}/${name}.yaml"
  expected="${GOLDEN_DIR}/${name}.yaml"

  if [ "$UPDATE_GOLDEN" = true ]; then
    render_case "$name" "$values_file" "$expected"
    echo "Rendered ${expected}"
    continue
  fi

  if [ ! -f "$expected" ]; then
    echo "Missing golden render: $expected" >&2
    failed=1
    continue
  fi

  render_case "$name" "$values_file" "$actual"

  if ! diff -u "$expected" "$actual"; then
    echo "Golden render mismatch for ${name}. Re-render with .github/scripts/check-helm-golden-renders.sh --update after reviewing the manifest change." >&2
    failed=1
  fi
done

exit "$failed"
