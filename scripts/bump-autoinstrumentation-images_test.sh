#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUMP="$SCRIPT_DIR/bump-autoinstrumentation-images.sh"
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

assert_file_contains() {
  local name="$1" file="$2" needle="$3"
  if ! grep -qF "$needle" "$file"; then
    echo "FAIL ${name}: ${file} missing '${needle}'" >&2
    FAILS=$((FAILS + 1))
  else
    echo "ok ${name}"
  fi
}

make_fixture() {
  local dir="$1"
  mkdir -p "$dir/golden"
  cat >"$dir/values.yaml" <<'EOF'
global:
  version: "0.0.10"

opentelemetry-autoinstrumentation:
  manager:
    config:
      instrumentations:
        spec:
          java:
            image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:2.28.1
          python:
            image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:0.63b1
          dotnet:
            image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-dotnet:1.15.0
          apacheHttpd:
            image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-apache-httpd:1.0.4
          nginx:
            image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-apache-httpd:1.0.4
EOF
  cat >"$dir/Chart.yaml" <<'EOF'
apiVersion: v2
name: otel-integration
version: 0.0.10
EOF
  cat >"$dir/CHANGELOG.md" <<'EOF'
# Changelog

## OpenTelemetry-Integration

### v0.0.10 / 2026-01-01

- [Chore] previous
EOF
  echo "            X-Coralogix-Distribution: helm-otel-integration/0.0.10" >"$dir/golden/windows.yaml"

  cat >"$dir/versions-newer.txt" <<'EOF'
autoinstrumentation-java=2.30.0
autoinstrumentation-python=0.64b0
autoinstrumentation-dotnet=1.16.0
autoinstrumentation-apache-httpd=1.0.4
autoinstrumentation-nginx=1.0.4
EOF
  cp "$dir/versions-newer.txt" "$dir/versions-same.txt"
  cat >"$dir/versions-same.txt" <<'EOF'
autoinstrumentation-java=2.28.1
autoinstrumentation-python=0.63b1
autoinstrumentation-dotnet=1.15.0
autoinstrumentation-apache-httpd=1.0.4
autoinstrumentation-nginx=1.0.4
EOF
}

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

# Catch-up from lagged pins. A long changelog must not SIGPIPE under pipefail.
make_fixture "$workdir/lag"
{
  echo ""
  for i in $(seq 1 400); do
    printf '### v0.0.%s / 2020-01-01\n\n- [Chore] filler\n\n' "$i"
  done
} >>"$workdir/lag/CHANGELOG.md"
out="$workdir/lag.out"
"$BUMP" \
  --versions-file "$workdir/lag/versions-newer.txt" \
  --operator-tag v0.158.0 \
  --values-file "$workdir/lag/values.yaml" \
  --chart-yaml "$workdir/lag/Chart.yaml" \
  --changelog "$workdir/lag/CHANGELOG.md" \
  --golden-dir "$workdir/lag/golden" \
  --github-output "$out" \
  --summary-file "$workdir/lag/summary.md"

assert_eq "lag.changed" "$(grep '^changed=' "$out" | cut -d= -f2)" "true"
assert_eq "lag.chart" "$(grep '^version:' "$workdir/lag/Chart.yaml" | awk '{print $2}')" "0.0.11"
assert_file_contains "lag.java" "$workdir/lag/values.yaml" "autoinstrumentation-java:2.30.0"
assert_file_contains "lag.python" "$workdir/lag/values.yaml" "autoinstrumentation-python:0.64b0"
assert_file_contains "lag.dotnet" "$workdir/lag/values.yaml" "autoinstrumentation-dotnet:1.16.0"
assert_file_contains "lag.apache" "$workdir/lag/values.yaml" "autoinstrumentation-apache-httpd:1.0.4"
apache_count=$(grep -c "autoinstrumentation-apache-httpd:1.0.4" "$workdir/lag/values.yaml")
assert_eq "lag.apache_and_nginx" "$apache_count" "2"
assert_file_contains "lag.global" "$workdir/lag/values.yaml" 'version: "0.0.11"'
assert_file_contains "lag.changelog" "$workdir/lag/CHANGELOG.md" "OpenTelemetry Operator v0.158.0"
assert_file_contains "lag.golden" "$workdir/lag/golden/windows.yaml" "helm-otel-integration/0.0.11"

# No-op when already aligned.
make_fixture "$workdir/same"
out="$workdir/same.out"
"$BUMP" \
  --versions-file "$workdir/same/versions-same.txt" \
  --operator-tag v0.154.0 \
  --values-file "$workdir/same/values.yaml" \
  --chart-yaml "$workdir/same/Chart.yaml" \
  --changelog "$workdir/same/CHANGELOG.md" \
  --golden-dir "$workdir/same/golden" \
  --github-output "$out" \
  --summary-file "$workdir/same/summary.md"

assert_eq "same.changed" "$(grep '^changed=' "$out" | cut -d= -f2)" "false"
assert_eq "same.chart" "$(grep '^version:' "$workdir/same/Chart.yaml" | awk '{print $2}')" "0.0.10"
assert_file_contains "same.java_kept" "$workdir/same/values.yaml" "autoinstrumentation-java:2.28.1"
if grep -q "v0.0.11" "$workdir/same/CHANGELOG.md"; then
  echo "FAIL same.changelog: unexpected new entry" >&2
  FAILS=$((FAILS + 1))
else
  echo "ok same.changelog"
fi

# Dry-run does not write.
make_fixture "$workdir/dry"
"$BUMP" --dry-run \
  --versions-file "$workdir/dry/versions-newer.txt" \
  --operator-tag v0.158.0 \
  --values-file "$workdir/dry/values.yaml" \
  --chart-yaml "$workdir/dry/Chart.yaml" \
  --changelog "$workdir/dry/CHANGELOG.md" \
  --golden-dir "$workdir/dry/golden" \
  --github-output "$workdir/dry.out" \
  --summary-file "$workdir/dry/summary.md" >/dev/null
assert_file_contains "dry.java_kept" "$workdir/dry/values.yaml" "autoinstrumentation-java:2.28.1"
assert_eq "dry.chart_kept" "$(grep '^version:' "$workdir/dry/Chart.yaml" | awk '{print $2}')" "0.0.10"

if [[ "$FAILS" -ne 0 ]]; then
  echo "${FAILS} assertion(s) failed" >&2
  exit 1
fi
echo "All bump-autoinstrumentation-images tests passed"
