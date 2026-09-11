#!/usr/bin/env bash
#
# bump-autoinstrumentation-images.sh
#
# Aligns otel-integration autoinstrumentation image tags with an OpenTelemetry
# Operator release's versions.txt. Updates values.yaml, Chart.yaml,
# global.version, CHANGELOG.md, and golden distribution headers when tags change.
#
# Options:
#   --operator-tag TAG      Operator git tag (vX.Y.Z). Fetches versions.txt.
#   --versions-file FILE    Local versions.txt (skips the network fetch)
#   --values-file FILE      Override values.yaml path
#   --chart-yaml FILE       Override Chart.yaml path
#   --changelog FILE        Override CHANGELOG.md path
#   --golden-dir DIR        Override golden renders directory
#   --summary-file FILE     Markdown summary output (default: /tmp/autoinstr-bump-summary.md)
#   --github-output FILE    Write GitHub Actions outputs (default: $GITHUB_OUTPUT)
#   --dry-run               Show the delta without writing files
#   --help
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OPERATOR_TAG=""
VERSIONS_FILE=""
VALUES_FILE="$REPO_ROOT/otel-integration/k8s-helm/values.yaml"
CHART_YAML="$REPO_ROOT/otel-integration/k8s-helm/Chart.yaml"
CHANGELOG_FILE="$REPO_ROOT/otel-integration/CHANGELOG.md"
GOLDEN_DIR="$REPO_ROOT/otel-integration/k8s-helm/tests/golden"
SUMMARY_FILE="/tmp/autoinstr-bump-summary.md"
GITHUB_OUTPUT_FILE="${GITHUB_OUTPUT:-}"
DRY_RUN=false

IMAGE_REPO="ghcr.io/open-telemetry/opentelemetry-operator"
OPERATOR_REPO="open-telemetry/opentelemetry-operator"

# values.yaml key -> versions.txt key. nginx shares the apache-httpd image.
PACKAGES=(
  "java:autoinstrumentation-java"
  "python:autoinstrumentation-python"
  "dotnet:autoinstrumentation-dotnet"
  "apacheHttpd:autoinstrumentation-apache-httpd"
)

log_info() { echo "[INFO] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^#//' | sed 's/^ //'
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --operator-tag)
      OPERATOR_TAG="$2"
      shift 2
      ;;
    --versions-file)
      VERSIONS_FILE="$2"
      shift 2
      ;;
    --values-file)
      VALUES_FILE="$2"
      shift 2
      ;;
    --chart-yaml)
      CHART_YAML="$2"
      shift 2
      ;;
    --changelog)
      CHANGELOG_FILE="$2"
      shift 2
      ;;
    --golden-dir)
      GOLDEN_DIR="$2"
      shift 2
      ;;
    --summary-file)
      SUMMARY_FILE="$2"
      shift 2
      ;;
    --github-output)
      GITHUB_OUTPUT_FILE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help | -h)
      usage
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      ;;
    esac
  done
}

normalize_operator_tag() {
  local tag="$1"
  if [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "$tag"
  elif [[ "$tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "v${tag}"
  else
    log_error "Invalid operator tag '$tag' (expected vX.Y.Z)"
    exit 1
  fi
}

fetch_latest_operator_tag() {
  local url="https://api.github.com/repos/${OPERATOR_REPO}/releases/latest"
  local args=(-fsSL)
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json")
  fi
  local tag
  tag=$(curl "${args[@]}" "$url" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
  if [[ -z "$tag" ]]; then
    log_error "Could not resolve the latest ${OPERATOR_REPO} release tag"
    exit 1
  fi
  normalize_operator_tag "$tag"
}

load_versions_file() {
  if [[ -n "$VERSIONS_FILE" ]]; then
    if [[ ! -f "$VERSIONS_FILE" ]]; then
      log_error "versions file not found: $VERSIONS_FILE"
      exit 1
    fi
    return
  fi
  if [[ -z "$OPERATOR_TAG" ]]; then
    OPERATOR_TAG=$(fetch_latest_operator_tag)
  else
    OPERATOR_TAG=$(normalize_operator_tag "$OPERATOR_TAG")
  fi
  VERSIONS_FILE=$(mktemp)
  trap 'rm -f "$VERSIONS_FILE"' EXIT
  local url="https://raw.githubusercontent.com/${OPERATOR_REPO}/${OPERATOR_TAG}/versions.txt"
  log_info "Fetching ${url}"
  curl -fsSL "$url" -o "$VERSIONS_FILE"
}

versions_txt_value() {
  local key="$1"
  local value
  value=$(grep -E "^${key}=" "$VERSIONS_FILE" | tail -1 | cut -d= -f2- | tr -d '[:space:]')
  if [[ -z "$value" ]]; then
    log_error "Missing ${key} in versions.txt"
    exit 1
  fi
  echo "$value"
}

current_image_tag() {
  local pkg="$1"
  local line
  line=$(grep -E "image: ${IMAGE_REPO}/autoinstrumentation-${pkg}:" "$VALUES_FILE" | head -1 || true)
  if [[ -z "$line" ]]; then
    log_error "No ${pkg} autoinstrumentation image in ${VALUES_FILE}"
    exit 1
  fi
  echo "${line##*:}" | tr -d '[:space:]'
}

increment_patch_version() {
  local version="$1"
  local major minor patch
  IFS='.' read -r major minor patch <<<"$version"
  echo "${major}.${minor}.$((patch + 1))"
}

write_output() {
  local key="$1"
  local value="$2"
  if [[ -n "$GITHUB_OUTPUT_FILE" ]]; then
    if [[ "$value" == *$'\n'* ]]; then
      local delim
      delim="EOF_$(printf '%s' "$key" | tr -c 'A-Za-z0-9' '_')"
      {
        echo "${key}<<${delim}"
        printf '%s\n' "$value"
        echo "${delim}"
      } >>"$GITHUB_OUTPUT_FILE"
    else
      echo "${key}=${value}" >>"$GITHUB_OUTPUT_FILE"
    fi
  fi
}

insert_changelog_entry() {
  local new_chart_version="$1"
  local change_line="$2"
  local today
  today=$(date +%Y-%m-%d)
  local entry_file
  entry_file=$(mktemp)

  {
    echo "### v${new_chart_version} / ${today}"
    echo ""
    echo "$change_line"
    echo ""
  } >"$entry_file"

  local first_version_line
  first_version_line=$(grep -Enm1 "^### v?[0-9]" "$CHANGELOG_FILE" | cut -d: -f1)
  if [[ -z "$first_version_line" ]]; then
    cat "$entry_file" >>"$CHANGELOG_FILE"
  else
    local temp_file
    temp_file=$(mktemp)
    head -n $((first_version_line - 1)) "$CHANGELOG_FILE" >"$temp_file"
    cat "$entry_file" >>"$temp_file"
    tail -n +"$first_version_line" "$CHANGELOG_FILE" >>"$temp_file"
    mv "$temp_file" "$CHANGELOG_FILE"
  fi
  rm -f "$entry_file"
}

main() {
  parse_args "$@"

  for required in "$VALUES_FILE" "$CHART_YAML" "$CHANGELOG_FILE"; do
    if [[ ! -f "$required" ]]; then
      log_error "File not found: $required"
      exit 1
    fi
  done

  load_versions_file
  if [[ -z "$OPERATOR_TAG" ]]; then
    OPERATOR_TAG="local"
  fi

  local apache_desired
  apache_desired=$(versions_txt_value "autoinstrumentation-apache-httpd")
  if grep -qE "^autoinstrumentation-nginx=" "$VERSIONS_FILE"; then
    local nginx_desired
    nginx_desired=$(versions_txt_value "autoinstrumentation-nginx")
    if [[ "$nginx_desired" != "$apache_desired" ]]; then
      log_error "Operator nginx ($nginx_desired) and apache-httpd ($apache_desired) tags differ; both pins in values.yaml share one image"
      exit 1
    fi
  fi

  local apache_current nginx_current
  apache_current=$(grep -E "image: ${IMAGE_REPO}/autoinstrumentation-apache-httpd:" "$VALUES_FILE" | head -1 | awk -F: '{print $NF}' | tr -d '[:space:]')
  nginx_current=$(grep -E "image: ${IMAGE_REPO}/autoinstrumentation-apache-httpd:" "$VALUES_FILE" | tail -1 | awk -F: '{print $NF}' | tr -d '[:space:]')
  if [[ -z "$apache_current" || -z "$nginx_current" ]]; then
    log_error "values.yaml must pin both apacheHttpd and nginx to autoinstrumentation-apache-httpd"
    exit 1
  fi
  if [[ "$apache_current" != "$nginx_current" ]]; then
    log_error "apacheHttpd ($apache_current) and nginx ($nginx_current) pins are already out of sync"
    exit 1
  fi

  local changed=false
  local delta_lines=()
  local changelog_bits=()

  local pair key versions_key pkg current desired
  for pair in "${PACKAGES[@]}"; do
    key="${pair%%:*}"
    versions_key="${pair##*:}"
    pkg="${versions_key#autoinstrumentation-}"
    current=$(current_image_tag "$pkg")
    desired=$(versions_txt_value "$versions_key")
    if [[ "$current" == "$desired" ]]; then
      log_info "${key}: ${current} (unchanged)"
      continue
    fi
    changed=true
    log_info "${key}: ${current} -> ${desired}"
    delta_lines+=("${key}: ${current} -> ${desired}")
    changelog_bits+=("${key} \`${current}\` -> \`${desired}\`")
    if [[ "$DRY_RUN" != "true" ]]; then
      sed -i.bak "s|${IMAGE_REPO}/autoinstrumentation-${pkg}:${current}|${IMAGE_REPO}/autoinstrumentation-${pkg}:${desired}|g" "$VALUES_FILE"
      rm -f "${VALUES_FILE}.bak"
    fi
  done

  local current_chart new_chart change_line summary
  current_chart=$(grep -E '^version:' "$CHART_YAML" | awk '{print $2}' | tr -d '"')
  new_chart="$current_chart"
  change_line=""

  if [[ "$changed" == "true" ]]; then
    new_chart=$(increment_patch_version "$current_chart")
    change_line="- [Chore] Bump autoinstrumentation images to match OpenTelemetry Operator ${OPERATOR_TAG} ($(IFS=', '; echo "${changelog_bits[*]}"))."
    if [[ "$DRY_RUN" != "true" ]]; then
      sed -i.bak "s/^version: ${current_chart}$/version: ${new_chart}/" "$CHART_YAML"
      rm -f "${CHART_YAML}.bak"
      sed -i.bak "/^global:/,/^[a-z]/ s/version: \"${current_chart}\"/version: \"${new_chart}\"/" "$VALUES_FILE"
      rm -f "${VALUES_FILE}.bak"
      insert_changelog_entry "$new_chart" "$change_line"
      if [[ -d "$GOLDEN_DIR" ]]; then
        local golden
        while IFS= read -r golden; do
          sed -i.bak "s|helm-otel-integration/${current_chart}|helm-otel-integration/${new_chart}|g" "$golden"
          rm -f "${golden}.bak"
        done < <(find "$GOLDEN_DIR" -type f -name '*.yaml')
      fi
    fi
  fi

  {
    echo "## Autoinstrumentation image bump"
    echo ""
    echo "**Operator:** \`${OPERATOR_TAG}\`"
    echo ""
    if [[ "$changed" == "true" ]]; then
      echo "Chart \`${current_chart}\` -> \`${new_chart}\`"
      echo ""
      for line in "${delta_lines[@]}"; do
        echo "- ${line}"
      done
    else
      echo "Already aligned with Operator \`${OPERATOR_TAG}\`. No PR needed."
    fi
  } >"$SUMMARY_FILE"

  summary=$(cat "$SUMMARY_FILE")
  local delta_joined=""
  if ((${#delta_lines[@]} > 0)); then
    delta_joined=$(IFS=', '; echo "${delta_lines[*]}")
  fi
  write_output "changed" "$changed"
  write_output "operator_tag" "$OPERATOR_TAG"
  write_output "chart_version" "$new_chart"
  write_output "delta" "$delta_joined"
  write_output "summary" "$summary"

  if [[ "$changed" == "true" ]]; then
    log_info "Would bump chart ${current_chart} -> ${new_chart}"
    if [[ "$DRY_RUN" == "true" ]]; then
      log_info "Dry run; no files written"
    fi
  else
    log_info "No image changes"
  fi
}

main "$@"
