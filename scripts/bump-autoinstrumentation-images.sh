#!/usr/bin/env bash
#
# bump-autoinstrumentation-images.sh
#
# Follows published OpenTelemetry Operator Helm charts and aligns image tags
# with the chart appVersion's versions.txt. Updates the operator dependency,
# values.yaml, chart/global versions, changelog, and golden distribution headers.
# The workflow then regenerates complete golden renders, including checksums.
#
# Options:
#   --operator-chart-version VERSION  Published chart version (default: latest stable)
#   --operator-tag TAG      Expected operator tag; must match the selected chart
#   --versions-file FILE    Local versions.txt (skips chart lookup and network fetch)
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
OPERATOR_CHART_VERSION=""
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
    --operator-chart-version)
      OPERATOR_CHART_VERSION="$2"
      shift 2
      ;;
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

resolve_operator_chart() {
  local args=()
  if [[ -n "$OPERATOR_CHART_VERSION" ]]; then
    args+=(--version "$OPERATOR_CHART_VERSION")
  fi
  local metadata chart_tag
  metadata=$(helm show chart opentelemetry-operator \
    --repo https://open-telemetry.github.io/opentelemetry-helm-charts "${args[@]}")
  OPERATOR_CHART_VERSION=$(printf '%s\n' "$metadata" | awk '/^version:/ {gsub(/["\047]/, "", $2); print $2}')
  chart_tag=$(printf '%s\n' "$metadata" | awk '/^appVersion:/ {gsub(/["\047]/, "", $2); print $2}')
  chart_tag=$(normalize_operator_tag "$chart_tag")
  if [[ ! "$OPERATOR_CHART_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid operator chart version '$OPERATOR_CHART_VERSION'"
    exit 1
  fi
  if [[ -n "$OPERATOR_TAG" && "$(normalize_operator_tag "$OPERATOR_TAG")" != "$chart_tag" ]]; then
    log_error "Operator tag $OPERATOR_TAG does not match chart $OPERATOR_CHART_VERSION ($chart_tag)"
    exit 1
  fi
  OPERATOR_TAG="$chart_tag"
  log_info "Operator chart ${OPERATOR_CHART_VERSION} uses ${OPERATOR_TAG}"
}

load_versions_file() {
  if [[ -n "$VERSIONS_FILE" ]]; then
    if [[ ! -f "$VERSIONS_FILE" ]]; then
      log_error "versions file not found: $VERSIONS_FILE"
      exit 1
    fi
    return
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
  if [[ -n "$OPERATOR_CHART_VERSION" && ! "$OPERATOR_CHART_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid operator chart version '$OPERATOR_CHART_VERSION'"
    exit 1
  fi

  for required in "$VALUES_FILE" "$CHART_YAML" "$CHANGELOG_FILE"; do
    if [[ ! -f "$required" ]]; then
      log_error "File not found: $required"
      exit 1
    fi
  done

  if [[ -z "$VERSIONS_FILE" ]]; then
    resolve_operator_chart
  fi
  if [[ -n "$OPERATOR_CHART_VERSION" ]]; then
    local current_operator_chart
    current_operator_chart=$(awk '
      /^  - name:/ {operator = ($3 == "opentelemetry-operator")}
      operator && /^    version:/ {gsub(/["\047]/, "", $2); print $2}
    ' "$CHART_YAML")
    if [[ ! "$current_operator_chart" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      log_error "Missing or invalid opentelemetry-operator dependency in $CHART_YAML"
      exit 1
    fi
    # A chart release is the only trigger; image drift alone must not open a PR.
    if [[ "$current_operator_chart" == "$OPERATOR_CHART_VERSION" ]]; then
      local unchanged_summary
      unchanged_summary="Operator Helm chart ${OPERATOR_CHART_VERSION} is unchanged. Skipping instrumentation image checks; no PR needed."
      printf '%s\n' "$unchanged_summary" >"$SUMMARY_FILE"
      write_output "changed" "false"
      write_output "operator_tag" "$OPERATOR_TAG"
      write_output "operator_chart_version" "$OPERATOR_CHART_VERSION"
      write_output "chart_version" "$(awk '/^version:/ {gsub(/"/, "", $2); print $2}' "$CHART_YAML")"
      write_output "delta" ""
      write_output "summary" "$unchanged_summary"
      log_info "$unchanged_summary"
      return
    fi
  fi

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

  if [[ -n "$OPERATOR_CHART_VERSION" ]]; then
    if [[ "$current_operator_chart" != "$OPERATOR_CHART_VERSION" ]]; then
      changed=true
      delta_lines+=("operator chart: ${current_operator_chart} -> ${OPERATOR_CHART_VERSION}")
      changelog_bits+=("operator chart \`${current_operator_chart}\` -> \`${OPERATOR_CHART_VERSION}\`")
      if [[ "$DRY_RUN" != "true" ]]; then
        sed -i.bak "/^  - name: opentelemetry-operator$/,/^  - name:/ s/^    version:.*/    version: \"${OPERATOR_CHART_VERSION}\"/" "$CHART_YAML"
        rm -f "${CHART_YAML}.bak"
      fi
    fi
  fi

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
    change_line="- [Chore] Bump operator chart and autoinstrumentation images to match OpenTelemetry Operator ${OPERATOR_TAG} ($(IFS=', '; echo "${changelog_bits[*]}"))."
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
    echo "## Operator chart and autoinstrumentation bump"
    echo ""
    echo "**Operator:** \`${OPERATOR_TAG}\`"
    if [[ -n "$OPERATOR_CHART_VERSION" ]]; then
      echo "**Operator Helm chart:** \`${OPERATOR_CHART_VERSION}\`"
    fi
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
  write_output "operator_chart_version" "$OPERATOR_CHART_VERSION"
  write_output "chart_version" "$new_chart"
  write_output "delta" "$delta_joined"
  write_output "summary" "$summary"

  if [[ "$changed" == "true" ]]; then
    log_info "Would bump chart ${current_chart} -> ${new_chart}"
    if [[ "$DRY_RUN" == "true" ]]; then
      log_info "Dry run; no files written"
    fi
  else
    log_info "No operator chart or image changes"
  fi
}

main "$@"
