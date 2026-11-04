#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: update-fleet-manager-collector-releases_test.sh <helm-data-dir> <collector-version>" >&2
  echo "Smoke test against live GitHub assets, Helm charts, and the Helm data catalog." >&2
  echo "Requires gh, jq, xxd, helm, yq, and GITHUB_TOKEN." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helm_data_dir="$(cd "$1" && pwd)"
version="${2#v}"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

# Remove only the target release, so the script must fetch real assets.
cp -R "$helm_data_dir/collector_releases" "$work_dir/collector_releases"
rm "$work_dir/collector_releases/$version.json"
bash "$script_dir/update-fleet-manager-collector-releases.sh" \
  "$version" "$work_dir/collector_releases"
diff -ru "$helm_data_dir/collector_releases" "$work_dir/collector_releases"
echo "PASS: fetched release matches Helm data byte for byte; other releases are unchanged."

# An invalid token proves that a repeat fetch does not make GitHub requests.
GITHUB_TOKEN=invalid bash "$script_dir/update-fleet-manager-collector-releases.sh" \
  "$version" "$work_dir/collector_releases"
diff -ru "$helm_data_dir/collector_releases" "$work_dir/collector_releases"
echo "PASS: repeat fetch keeps the catalog unchanged without network access."

# Exercise the actual workflow step against published charts. Both 0.142.1 and
# 0.142.2 use Collector 0.164.0; 0.141.0 uses Collector 0.163.2.
yq -r '.jobs.detect.steps[] | select(.id == "collector_release") | .run' \
  "$script_dir/../.github/workflows/sync-fleet-manager-collector-releases.yml" > "$work_dir/detect-version.sh"
touch "$work_dir/unchanged.out"
OLD_COLLECTOR_CHART_VERSION=0.142.1 COLLECTOR_CHART_VERSION=0.142.2 \
  GITHUB_OUTPUT="$work_dir/unchanged.out" bash "$work_dir/detect-version.sh"
test ! -s "$work_dir/unchanged.out"
echo "PASS: a chart update with the same Collector version does not request a fetch."

OLD_COLLECTOR_CHART_VERSION=0.141.0 COLLECTOR_CHART_VERSION=0.142.2 \
  GITHUB_OUTPUT="$work_dir/changed.out" bash "$work_dir/detect-version.sh"
test "$(cat "$work_dir/changed.out")" = "version=0.164.0"
echo "PASS: a chart update with a new Collector version requests a fetch."
