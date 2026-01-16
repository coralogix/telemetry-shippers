#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$repo_root" ]; then
  repo_root="$(cd "$script_dir/.." && pwd)"
fi

default_chart_file="$repo_root/otel-integration/k8s-helm/Chart.yaml"
chart_file="${1:-$default_chart_file}"

if [ ! -f "$chart_file" ]; then
  echo "Chart file not found: $chart_file" >&2
  exit 1
fi

versions="$(
  awk '
    BEGIN { in_dep = 0 }
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ {
      name = $0
      sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/, "", name)
      sub(/[[:space:]]*#.*/, "", name)
      gsub(/["'"'"']/, "", name)
      in_dep = (name == "opentelemetry-collector") ? 1 : 0
      next
    }
    /^[[:space:]]*-[[:space:]]*name:/ {
      in_dep = 0
    }
    in_dep && /^[[:space:]]*version:[[:space:]]*/ {
      version = $0
      sub(/^[[:space:]]*version:[[:space:]]*/, "", version)
      sub(/[[:space:]]*#.*/, "", version)
      gsub(/["'"'"']/, "", version)
      if (length(version) > 0) {
        print version
      }
      in_dep = 0
    }
  ' "$chart_file" | sort -u
)"

if [ -z "$versions" ]; then
  echo "No opentelemetry-collector dependencies found in $chart_file" >&2
  exit 1
fi

mapfile -t version_list <<< "$versions"
if [ "${#version_list[@]}" -gt 1 ]; then
  echo "Multiple opentelemetry-collector versions found in $chart_file: ${version_list[*]}" >&2
  exit 1
fi

echo "${version_list[0]}"
