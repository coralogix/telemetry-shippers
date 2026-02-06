#!/usr/bin/env bash
#
# Resolves the opentelemetry-collector chart version from a given Chart.yaml.
#
# Reads the dependencies list, finds the entry named "opentelemetry-collector",
# and prints its version.  Exits with an error if no version is found or if
# there are multiple distinct versions.
#
# Usage:
#   resolve-collector-chart-version.sh <path-to-Chart.yaml>
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

versions="$(
  yq -r '.dependencies[]? | select(.name == "opentelemetry-collector") | .version' "$chart_file" \
    | sed -e '/^null$/d' -e '/^$/d' \
    | sort -u
)"

if [ -z "$versions" ]; then
  echo "No opentelemetry-collector dependency versions found in $chart_file" >&2
  exit 1
fi

count="$(printf '%s\n' "$versions" | wc -l | tr -d '[:space:]')"
if [ "$count" -ne 1 ]; then
  echo "Expected exactly one opentelemetry-collector dependency version in $chart_file, found $count: $versions" >&2
  exit 1
fi

printf '%s\n' "$versions"
