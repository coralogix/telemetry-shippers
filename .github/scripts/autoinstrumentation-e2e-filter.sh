#!/usr/bin/env bash
#
# Decides whether the autoinstrumentation webhook E2E should run, and which
# language subtests to include.
#
# Outputs (stdout and optional --github-output):
#   run=true|false
#   go_run=<go test -run regexp>
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALUES_FILE="otel-integration/k8s-helm/values.yaml"
ALL_LANGS=(java python dotnet apache nginx)

BASE_SHA=""
HEAD_SHA=""
GITHUB_OUTPUT_FILE=""
FORCE_ALL=false

HARNESS_PATHS=(
  "otel-integration/k8s-helm/e2e-test/instrumentation_webhook_test.go"
  "otel-integration/k8s-helm/e2e-test/testdata/values-e2e-instrumentation-webhook.yaml"
  "otel-integration/k8s-helm/e2e-test/testdata/nginx-e2e.conf"
  "otel-integration/k8s-helm/e2e-test/run-all.sh"
  ".github/scripts/autoinstrumentation-e2e-filter.sh"
  ".github/workflows/otel-integration-e2e-test.yml"
)

usage() {
  cat <<'EOF'
Usage: autoinstrumentation-e2e-filter.sh [--base SHA] [--head SHA] [--all] [--repo DIR] [--github-output FILE]
EOF
  exit 1
}

write_output() {
  local key="$1"
  local value="$2"
  echo "${key}=${value}"
  if [[ -n "$GITHUB_OUTPUT_FILE" ]]; then
    echo "${key}=${value}" >>"$GITHUB_OUTPUT_FILE"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --base)
    BASE_SHA="$2"
    shift 2
    ;;
  --head)
    HEAD_SHA="$2"
    shift 2
    ;;
  --github-output)
    GITHUB_OUTPUT_FILE="$2"
    shift 2
    ;;
  --repo)
    REPO_ROOT="$2"
    shift 2
    ;;
  --all)
    FORCE_ALL=true
    shift
    ;;
  -h|--help)
    usage
    ;;
  *)
    echo "Unknown option: $1" >&2
    usage
    ;;
  esac
done

emit_all() {
  write_output "run" "true"
  write_output "go_run" "^TestE2E_InstrumentationWebhookNoCRDs$"
}

if [[ "$FORCE_ALL" == "true" ]]; then
  emit_all
  exit 0
fi

if [[ -z "$BASE_SHA" || -z "$HEAD_SHA" ]]; then
  echo "Either --all or both --base and --head are required" >&2
  exit 1
fi

cd "$REPO_ROOT"

changed_files=$(git diff --name-only "${BASE_SHA}...${HEAD_SHA}")
harness_changed=false
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  for harness in "${HARNESS_PATHS[@]}"; do
    if [[ "$path" == "$harness" ]]; then
      harness_changed=true
      break
    fi
  done
done <<<"$changed_files"

if [[ "$harness_changed" == "true" ]]; then
  emit_all
  exit 0
fi

# The operator Helm chart supplies the webhook manager this E2E exercises.
operator_chart_version() {
  local sha="$1"
  git show "${sha}:otel-integration/k8s-helm/Chart.yaml" 2>/dev/null | awk '
    /name: opentelemetry-operator/ {hit=1}
    hit && /version:/ {
      gsub(/"/, "", $2)
      print $2
      exit
    }
  '
}

if [[ "$(operator_chart_version "$BASE_SHA")" != "$(operator_chart_version "$HEAD_SHA")" ]]; then
  emit_all
  exit 0
fi

# Shared webhook settings (exporter, env, sampler, feature flags) are not
# language pins. If that subtree changed besides image tags, run every language.
autoinstr_config_without_images() {
  local sha="$1"
  git show "${sha}:${VALUES_FILE}" 2>/dev/null | awk '
    /^opentelemetry-autoinstrumentation:/ {p=1}
    p && /^[^[:space:]#]/ && !/^opentelemetry-autoinstrumentation:/ {exit}
    p && /autoinstrumentation-(java|python|dotnet|apache-httpd):/ {next}
    p {print}
  '
}

if [[ "$(autoinstr_config_without_images "$BASE_SHA")" != "$(autoinstr_config_without_images "$HEAD_SHA")" ]]; then
  emit_all
  exit 0
fi

values_diff=$(git diff -U0 "${BASE_SHA}...${HEAD_SHA}" -- "$VALUES_FILE" || true)
langs=()
add_lang() {
  local lang="$1"
  local existing
  for existing in "${langs[@]+"${langs[@]}"}"; do
    if [[ "$existing" == "$lang" ]]; then
      return
    fi
  done
  langs+=("$lang")
}

while IFS= read -r line; do
  [[ "$line" =~ ^[+-][^+-] ]] || continue
  if [[ "$line" == *autoinstrumentation-java:* ]]; then
    add_lang java
  elif [[ "$line" == *autoinstrumentation-python:* ]]; then
    add_lang python
  elif [[ "$line" == *autoinstrumentation-dotnet:* ]]; then
    add_lang dotnet
  elif [[ "$line" == *autoinstrumentation-apache-httpd:* ]]; then
    add_lang apache
    add_lang nginx
  fi
done <<<"$values_diff"

if [[ ${#langs[@]} -eq 0 ]]; then
  write_output "run" "false"
  write_output "go_run" ""
  exit 0
fi

# Preserve ALL_LANGS order.
ordered=()
for lang in "${ALL_LANGS[@]}"; do
  for got in "${langs[@]}"; do
    if [[ "$got" == "$lang" ]]; then
      ordered+=("$lang")
    fi
  done
done

if [[ ${#ordered[@]} -eq ${#ALL_LANGS[@]} ]]; then
  emit_all
  exit 0
fi

joined=$(IFS='|'; echo "${ordered[*]}")
write_output "run" "true"
write_output "go_run" "^TestE2E_InstrumentationWebhookNoCRDs$/(${joined})$"
