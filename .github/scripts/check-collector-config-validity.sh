#!/usr/bin/env bash
set -euo pipefail

# Validates the collector configs embedded in the golden renders against the
# container image the chart actually renders, using `otelcol ... validate`
# (config unmarshal + pipeline construction — no eBPF probes, no cluster).
#
# Golden renders alone cannot catch an upstream config-key removal: the rendered
# YAML stays byte-identical while the binary stops accepting it. That is how
# `tracers: all` shipped in otel-integration 0.0.333 and crash-looped every
# profiler pod with:
#   'config.Config' has invalid keys: tracers
#
# Only configs that wire the `profiling` receiver are checked. The agent and
# cluster-collector configs reference Coralogix-distribution-only components,
# which no published upstream image can resolve.

CHART_DIR="${CHART_DIR:-otel-integration/k8s-helm}"
GOLDEN_DIR="${GOLDEN_DIR:-${CHART_DIR}/tests/golden}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}
require_cmd docker
require_cmd awk

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Splits a golden render into the `relay` config of every collector ConfigMap.
extract_configs() {
  local golden="$1" outdir="$2"
  awk -v outdir="$outdir" '
    /^# Source: /            { source = $3 }
    /^  relay: \|/           { name = source; gsub(/[^A-Za-z0-9]/, "_", name);
                               file = outdir "/" name ".yaml"; capturing = 1; next }
    capturing && /^$/        { print "" > file; next }
    capturing && /^    /     { print substr($0, 5) > file; next }
    capturing                { capturing = 0; close(file) }
  ' "$golden"
}

# Echoes the profiler image the given golden render pins, or nothing.
profiler_image() {
  local golden="$1" images
  images="$(grep -hoE '[^"[:space:]]*opentelemetry-collector-ebpf-profiler:[^"[:space:]]+' "$golden" | sort -u)"
  if [ "$(printf '%s\n' "$images" | grep -c .)" -gt 1 ]; then
    echo "Golden $(basename "$golden") pins more than one profiler image:" >&2
    printf '%s\n' "$images" | sed 's/^/  /' >&2
    return 1
  fi
  printf '%s' "$images"
}

# Runs `validate` inside the pinned image. The config is handed over through an
# environment variable rather than a bind mount so this works the same on CI and
# on a laptop whose Docker VM does not share $TMPDIR.
#
# `validate` builds the pipelines, so components are constructed for real. The
# `eks` resource detector builds a Kubernetes client at construction time, so a
# service-account token has to exist for it — it is never used, no request is
# made. The missing ca.crt only produces a klog warning.
validate_config() {
  local image="$1" binary="$2" config="$3"
  local -a env_args=(
    -e "CX_COLLECTOR_CONFIG"
    -e "KUBERNETES_SERVICE_HOST=127.0.0.1"
    -e "KUBERNETES_SERVICE_PORT=443"
  )

  # `validate` resolves ${env:...} references, so stub every variable the config
  # expects — these are supplied by the DaemonSet at runtime.
  local var
  while read -r var; do
    case "$var" in
      *_IP|*_ADDR) env_args+=(-e "${var}=127.0.0.1") ;;
      *_PORT) env_args+=(-e "${var}=4317") ;;
      *) env_args+=(-e "${var}=placeholder") ;;
    esac
  done < <(grep -oE '\$\{env:[A-Za-z_][A-Za-z0-9_]*\}' "$config" | sed "s/\${env://; s/}//" | sort -u)

  CX_COLLECTOR_CONFIG="$(cat "$config")" docker run --rm --entrypoint sh "${env_args[@]}" "$image" -c '
    mkdir -p /var/run/secrets/kubernetes.io/serviceaccount
    printf stub > /var/run/secrets/kubernetes.io/serviceaccount/token
    exec "$1" validate --config=env:CX_COLLECTOR_CONFIG --feature-gates=+service.profilesSupport
  ' sh "$binary" 2>&1
}

failed=0
found=0
profiler_configs=0

for golden in "${GOLDEN_DIR}"/*.yaml; do
  case_name="$(basename "$golden" .yaml)"
  outdir="${tmpdir}/${case_name}"
  mkdir -p "$outdir"
  extract_configs "$golden" "$outdir"

  image=""
  for config in "$outdir"/*.yaml; do
    [ -e "$config" ] || continue
    found=$((found + 1))
    label="${case_name}/$(basename "$config" .yaml)"

    grep -qE '^  profiling:' "$config" || continue
    profiler_configs=$((profiler_configs + 1))

    if [ -z "$image" ]; then
      image="$(profiler_image "$golden")"
      if [ -z "$image" ]; then
        echo "FAIL  ${label}"
        echo "      config uses the 'profiling' receiver but ${case_name}.yaml pins no profiler image" >&2
        failed=1
        continue
      fi
      echo "Validating against ${image}"
      docker pull -q "$image" >/dev/null
      binary="$(docker image inspect --format '{{index .Config.Entrypoint 0}}' "$image")"
    fi

    if output="$(validate_config "$image" "$binary" "$config")"; then
      echo "OK    ${label}"
    else
      echo "FAIL  ${label}"
      echo "$output" | sed 's/^/      /' | head -20
      failed=1
    fi
  done
done

if [ "$found" -eq 0 ]; then
  echo "No collector configs found under ${GOLDEN_DIR}" >&2
  exit 1
fi

# Guard against silently losing coverage: the golden case that exercises the
# profiling receiver must keep existing.
if [ "$profiler_configs" -eq 0 ]; then
  echo "No config using the 'profiling' receiver found under ${GOLDEN_DIR}" >&2
  exit 1
fi

if [ "$failed" -ne 0 ]; then
  echo "Collector config validation failed." >&2
  exit 1
fi

echo "All validated collector configs are accepted by the pinned image."
