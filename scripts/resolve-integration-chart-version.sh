#!/usr/bin/env bash
#
# Resolves the otel-integration chart version from a given Chart.yaml.
#
# Reads the top-level `version` field and prints it. Exits with an error if the
# value is missing or empty.
#
# Usage:
#   resolve-integration-chart-version.sh <path-to-Chart.yaml>
#
set -euo pipefail

if [ $# -ne 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $(basename "$0") <path-to-Chart.yaml>" >&2
  exit 1
fi

chart_file="$1"

if ! command -v yq >/dev/null 2>&1; then
  echo "yq is required." >&2
  exit 1
fi

integration_chart_version="$(yq -r '.version' "$chart_file")"
if [ "$integration_chart_version" = "null" ] || [ -z "$integration_chart_version" ]; then
  echo "No top-level chart version found in $chart_file" >&2
  exit 1
fi

printf '%s\n' "$integration_chart_version"
