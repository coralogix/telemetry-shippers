#!/usr/bin/env bash
set -euo pipefail

FILTER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.github/scripts/autoinstrumentation-e2e-filter.sh"
FAILS=0

assert_eq() {
  local name="$1" got="$2" want="$3"
  if [[ "$got" != "$want" ]]; then
    echo "FAIL ${name}: got '${got}' want '${want}'" >&2
    FAILS=$((FAILS + 1))
  else
    echo "ok ${name}"
  fi
}

git_commit() {
  git -c user.email=test@example.com -c user.name=test add -A
  git -c user.email=test@example.com -c user.name=test commit -m "$1" >/dev/null
}

init_repo() {
  local dir="$1"
  mkdir -p "$dir/otel-integration/k8s-helm/e2e-test/testdata" \
    "$dir/.github/scripts" \
    "$dir/.github/workflows"
  cat >"$dir/otel-integration/k8s-helm/values.yaml" <<'EOF'
opentelemetry-autoinstrumentation:
  manager:
    config:
      instrumentations:
        spec:
          java:
            image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:2.30.0
          python:
            image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:0.64b0
          dotnet:
            image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-dotnet:1.16.0
          apacheHttpd:
            image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-apache-httpd:1.0.4
          nginx:
            image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-apache-httpd:1.0.4
EOF
  echo "readme" >"$dir/otel-integration/k8s-helm/README.md"
  echo "test" >"$dir/otel-integration/k8s-helm/e2e-test/instrumentation_webhook_test.go"
  echo "values" >"$dir/otel-integration/k8s-helm/e2e-test/testdata/values-e2e-instrumentation-webhook.yaml"
  echo "nginx" >"$dir/otel-integration/k8s-helm/e2e-test/testdata/nginx-e2e.conf"
  echo "run" >"$dir/otel-integration/k8s-helm/e2e-test/run-all.sh"
  echo "filter" >"$dir/.github/scripts/autoinstrumentation-e2e-filter.sh"
  echo "wf" >"$dir/.github/workflows/otel-integration-e2e-test.yml"
  cat >"$dir/otel-integration/k8s-helm/Chart.yaml" <<'EOF'
dependencies:
  - name: opentelemetry-collector
    alias: opentelemetry-agent
    version: "0.138.1"
  - name: opentelemetry-operator
    alias: opentelemetry-autoinstrumentation
    version: "0.122.0"
EOF
  git -C "$dir" init -q
  git -C "$dir" checkout -q -b master
  (
    cd "$dir"
    git_commit "base"
  )
}

run_filter() {
  local repo="$1"
  local base="$2"
  local head="$3"
  bash "$FILTER" --repo "$repo" --base "$base" --head "$head"
}

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

# --all always runs every language.
out=$(bash "$FILTER" --all)
assert_eq "all.run" "$(echo "$out" | awk -F= '/^run=/{print $2}')" "true"
assert_eq "all.go_run" "$(echo "$out" | awk -F= '/^go_run=/{print $2}')" "^TestE2E_InstrumentationWebhookNoCRDs$"

# Collector-only / values change that is not an image pin.
init_repo "$workdir/noop"
base=$(git -C "$workdir/noop" rev-parse HEAD)
echo "global:" >>"$workdir/noop/otel-integration/k8s-helm/values.yaml"
echo "  clusterName: x" >>"$workdir/noop/otel-integration/k8s-helm/values.yaml"
(
  cd "$workdir/noop"
  git_commit "values unrelated"
)
head=$(git -C "$workdir/noop" rev-parse HEAD)
out=$(run_filter "$workdir/noop" "$base" "$head")
assert_eq "noop.run" "$(echo "$out" | awk -F= '/^run=/{print $2}')" "false"

# Java pin only.
init_repo "$workdir/java"
base=$(git -C "$workdir/java" rev-parse HEAD)
sed -i.bak 's/autoinstrumentation-java:2.30.0/autoinstrumentation-java:2.31.1/' \
  "$workdir/java/otel-integration/k8s-helm/values.yaml"
rm -f "$workdir/java/otel-integration/k8s-helm/values.yaml.bak"
(
  cd "$workdir/java"
  git_commit "java bump"
)
head=$(git -C "$workdir/java" rev-parse HEAD)
out=$(run_filter "$workdir/java" "$base" "$head")
assert_eq "java.run" "$(echo "$out" | awk -F= '/^run=/{print $2}')" "true"
assert_eq "java.go_run" "$(echo "$out" | awk -F= '/^go_run=/{print $2}')" \
  "^TestE2E_InstrumentationWebhookNoCRDs$/(java)$"

# Apache pin runs apache and nginx.
init_repo "$workdir/apache"
base=$(git -C "$workdir/apache" rev-parse HEAD)
sed -i.bak 's/autoinstrumentation-apache-httpd:1.0.4/autoinstrumentation-apache-httpd:1.0.5/' \
  "$workdir/apache/otel-integration/k8s-helm/values.yaml"
rm -f "$workdir/apache/otel-integration/k8s-helm/values.yaml.bak"
(
  cd "$workdir/apache"
  git_commit "apache bump"
)
head=$(git -C "$workdir/apache" rev-parse HEAD)
out=$(run_filter "$workdir/apache" "$base" "$head")
assert_eq "apache.run" "$(echo "$out" | awk -F= '/^run=/{print $2}')" "true"
assert_eq "apache.go_run" "$(echo "$out" | awk -F= '/^go_run=/{print $2}')" \
  "^TestE2E_InstrumentationWebhookNoCRDs$/(apache|nginx)$"

# Harness change runs all languages even without pin diffs.
init_repo "$workdir/harness"
base=$(git -C "$workdir/harness" rev-parse HEAD)
echo "// change" >>"$workdir/harness/otel-integration/k8s-helm/e2e-test/instrumentation_webhook_test.go"
(
  cd "$workdir/harness"
  git_commit "harness"
)
head=$(git -C "$workdir/harness" rev-parse HEAD)
out=$(run_filter "$workdir/harness" "$base" "$head")
assert_eq "harness.run" "$(echo "$out" | awk -F= '/^run=/{print $2}')" "true"
assert_eq "harness.go_run" "$(echo "$out" | awk -F= '/^go_run=/{print $2}')" \
  "^TestE2E_InstrumentationWebhookNoCRDs$"

# Shared webhook config (not an image pin) runs every language.
init_repo "$workdir/exporter"
base=$(git -C "$workdir/exporter" rev-parse HEAD)
cat >>"$workdir/exporter/otel-integration/k8s-helm/values.yaml" <<'EOF'
          exporter:
            endpoint: http://$(OTEL_NODE_IP):4317
EOF
(
  cd "$workdir/exporter"
  git_commit "exporter"
)
head=$(git -C "$workdir/exporter" rev-parse HEAD)
out=$(run_filter "$workdir/exporter" "$base" "$head")
assert_eq "exporter.run" "$(echo "$out" | awk -F= '/^run=/{print $2}')" "true"
assert_eq "exporter.go_run" "$(echo "$out" | awk -F= '/^go_run=/{print $2}')" \
  "^TestE2E_InstrumentationWebhookNoCRDs$"

# Operator Helm chart version change runs every language.
init_repo "$workdir/operator"
base=$(git -C "$workdir/operator" rev-parse HEAD)
sed -i.bak 's/version: "0.122.0"/version: "0.123.0"/' \
  "$workdir/operator/otel-integration/k8s-helm/Chart.yaml"
rm -f "$workdir/operator/otel-integration/k8s-helm/Chart.yaml.bak"
(
  cd "$workdir/operator"
  git_commit "operator chart"
)
head=$(git -C "$workdir/operator" rev-parse HEAD)
out=$(run_filter "$workdir/operator" "$base" "$head")
assert_eq "operator.run" "$(echo "$out" | awk -F= '/^run=/{print $2}')" "true"
assert_eq "operator.go_run" "$(echo "$out" | awk -F= '/^go_run=/{print $2}')" \
  "^TestE2E_InstrumentationWebhookNoCRDs$"

# Collector subchart bump does not run the webhook E2E.
init_repo "$workdir/collector"
base=$(git -C "$workdir/collector" rev-parse HEAD)
sed -i.bak 's/version: "0.138.1"/version: "0.138.2"/' \
  "$workdir/collector/otel-integration/k8s-helm/Chart.yaml"
rm -f "$workdir/collector/otel-integration/k8s-helm/Chart.yaml.bak"
(
  cd "$workdir/collector"
  git_commit "collector chart"
)
head=$(git -C "$workdir/collector" rev-parse HEAD)
out=$(run_filter "$workdir/collector" "$base" "$head")
assert_eq "collector.run" "$(echo "$out" | awk -F= '/^run=/{print $2}')" "false"

# README-only does not run.
init_repo "$workdir/readme"
base=$(git -C "$workdir/readme" rev-parse HEAD)
echo "docs" >>"$workdir/readme/otel-integration/k8s-helm/README.md"
(
  cd "$workdir/readme"
  git_commit "readme"
)
head=$(git -C "$workdir/readme" rev-parse HEAD)
out=$(run_filter "$workdir/readme" "$base" "$head")
assert_eq "readme.run" "$(echo "$out" | awk -F= '/^run=/{print $2}')" "false"

if [[ "$FAILS" -ne 0 ]]; then
  echo "${FAILS} assertion(s) failed" >&2
  exit 1
fi
echo "All autoinstrumentation-e2e-filter tests passed"
