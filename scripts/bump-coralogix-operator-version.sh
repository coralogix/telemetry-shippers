#!/usr/bin/env bash
#
# bump-coralogix-operator-version.sh
#
# Bumps the coralogix-operator subchart dependency of otel-integration.
# Updates Chart.yaml (dependency + patch-bumped chart version), values.yaml
# (global.version), CHANGELOG.md, and regenerates the Helm golden renders.
# Does nothing when the pinned version is already at or above the target.
#
# Options:
#   --version VERSION       New coralogix-operator chart version (required)
#   --release-url URL       Release notes URL for the CHANGELOG entry
#                           (default: the coralogix-operator GitHub release for VERSION)
#   --repo-root DIR         Repository root to edit (default: this script's repo)
#   --skip-golden           Do not regenerate the Helm golden renders
#   --summary-file FILE     Path to write markdown summary (default: /tmp/coralogix-operator-bump-summary.md)
#   --help                  Show this help message
#
# When GITHUB_OUTPUT is set, writes changed, previous_version and chart_version.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DEPENDENCY_NAME="coralogix-operator"
NEW_VERSION=""
RELEASE_URL=""
SKIP_GOLDEN=false
SUMMARY_FILE="/tmp/coralogix-operator-bump-summary.md"

log_info() { echo "[INFO] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^#//' | sed 's/^ //'
  exit 0
}

set_output() {
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "$1=$2" >>"$GITHUB_OUTPUT"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    --version)
      NEW_VERSION="$2"
      shift 2
      ;;
    --release-url)
      RELEASE_URL="$2"
      shift 2
      ;;
    --repo-root)
      REPO_ROOT="$(cd "$2" && pwd)"
      shift 2
      ;;
    --skip-golden)
      SKIP_GOLDEN=true
      shift
      ;;
    --summary-file)
      SUMMARY_FILE="$2"
      shift 2
      ;;
    --help | -h)
      usage
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
    esac
  done

  if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "--version must be a semver like 1.2.3 (got '$NEW_VERSION')"
    exit 1
  fi
  if [[ -z "$RELEASE_URL" ]]; then
    RELEASE_URL="https://github.com/coralogix/coralogix-operator/releases/tag/v${NEW_VERSION}"
  fi
}

increment_patch_version() {
  local major minor patch
  IFS='.' read -r major minor patch <<<"$1"
  echo "${major}.${minor}.$((patch + 1))"
}

# Succeeds when $1 >= $2 (semver-aware).
version_gte() {
  [[ "$(printf '%s\n' "$1" "$2" | sort -V | tail -1)" == "$1" ]]
}

main() {
  parse_args "$@"

  local chart_dir="$REPO_ROOT/otel-integration/k8s-helm"
  local chart_yaml="$chart_dir/Chart.yaml"
  local values_yaml="$chart_dir/values.yaml"
  local changelog="$REPO_ROOT/otel-integration/CHANGELOG.md"

  local current_dep_version
  current_dep_version=$(yq ".dependencies[] | select(.name == \"$DEPENDENCY_NAME\") | .version" "$chart_yaml" | head -1 | tr -d '"')
  if [[ -z "$current_dep_version" ]]; then
    log_error "No $DEPENDENCY_NAME dependency in $chart_yaml"
    exit 1
  fi
  set_output previous_version "$current_dep_version"

  if version_gte "$current_dep_version" "$NEW_VERSION"; then
    log_info "$DEPENDENCY_NAME is already at $current_dep_version (>= $NEW_VERSION) - nothing to do"
    set_output changed false
    exit 0
  fi

  local current_chart_version new_chart_version current_global_version
  current_chart_version=$(yq '.version' "$chart_yaml" | tr -d '"')
  new_chart_version=$(increment_patch_version "$current_chart_version")
  current_global_version=$(yq '.global.version' "$values_yaml" | tr -d '"')

  log_info "$DEPENDENCY_NAME: $current_dep_version -> $NEW_VERSION"
  log_info "otel-integration chart: $current_chart_version -> $new_chart_version"

  yq -i ".version = \"$new_chart_version\"" "$chart_yaml"
  yq -i "(.dependencies[] | select(.name == \"$DEPENDENCY_NAME\") | .version) = \"$NEW_VERSION\"" "$chart_yaml"

  # Update only version within global: block (sed address range), keeping the
  # comments and formatting of values.yaml intact.
  sed -i.bak '/^global:/,/^[a-z]/ s/version: "'"$current_global_version"'"/version: "'"$new_chart_version"'"/' "$values_yaml" && rm -f "${values_yaml}.bak"
  if [[ "$(yq '.global.version' "$values_yaml")" != "$new_chart_version" ]]; then
    log_error "Failed to set global.version in $values_yaml"
    exit 1
  fi

  # Insert the entry before the first version header of the changelog.
  local entry_file temp_file first_version_line
  entry_file=$(mktemp)
  temp_file=$(mktemp)
  {
    echo "### v${new_chart_version} / $(date +%Y-%m-%d)"
    echo ""
    echo "- [Chore] Bump the ${DEPENDENCY_NAME} subchart from ${current_dep_version} to ${NEW_VERSION} ([release notes](${RELEASE_URL}))."
    echo ""
  } >"$entry_file"
  first_version_line=$(grep -En "^### v?[0-9]" "$changelog" | head -1 | cut -d: -f1)
  if [[ -z "$first_version_line" ]]; then
    log_error "No version header found in $changelog"
    exit 1
  fi
  head -n $((first_version_line - 1)) "$changelog" >"$temp_file"
  cat "$entry_file" >>"$temp_file"
  tail -n +"$first_version_line" "$changelog" >>"$temp_file"
  mv "$temp_file" "$changelog"
  rm -f "$entry_file"

  if [[ "$SKIP_GOLDEN" != "true" ]]; then
    # The chart version is rendered into the golden files (distribution
    # headers and config checksums), so they must follow every bump.
    log_info "Regenerating Helm golden renders..."
    (cd "$REPO_ROOT" && .github/scripts/check-helm-golden-renders.sh --update)
  fi

  cat >"$SUMMARY_FILE" <<EOF
Bumps the \`${DEPENDENCY_NAME}\` subchart of \`otel-integration\` from \`${current_dep_version}\` to \`${NEW_VERSION}\` ([release notes](${RELEASE_URL})).

- \`otel-integration/k8s-helm/Chart.yaml\`: dependency \`${current_dep_version}\` -> \`${NEW_VERSION}\`, chart version \`${current_chart_version}\` -> \`${new_chart_version}\`
- \`otel-integration/k8s-helm/values.yaml\`: \`global.version\` -> \`${new_chart_version}\`
- \`otel-integration/CHANGELOG.md\`: \`v${new_chart_version}\` entry
EOF
  if [[ "$SKIP_GOLDEN" != "true" ]]; then
    echo "- \`otel-integration/k8s-helm/tests/golden\`: regenerated for the new chart version" >>"$SUMMARY_FILE"
  fi

  set_output changed true
  set_output chart_version "$new_chart_version"
  log_info "Done"
}

main "$@"
