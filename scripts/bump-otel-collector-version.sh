#!/usr/bin/env bash
#
# bump-otel-collector-version.sh
#
# Bumps the opentelemetry-collector chart dependency across all integration charts.
# Updates Chart.yaml, values.yaml, and CHANGELOG.md for each chart.
#
# Options:
#   --version VERSION       New opentelemetry-collector chart version (required)
#   --changelog-file FILE   File containing changelog entries to copy (optional)
#   --source-commit SHA     Source commit SHA for reference (optional)
#   --source-pr NUMBER      Source PR number for reference (optional)
#   --source-repo REPO      Source repository (default: coralogix/opentelemetry-helm-charts)
#   --skip CHART            Chart to skip (can be repeated)
#   --summary-file FILE     Path to write markdown summary (default: /tmp/otel-bump-summary.md)
#   --dry-run               Show what would be done without making changes
#   --help                  Show this help message
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

NEW_VERSION=""
CHANGELOG_FILE=""
SOURCE_COMMIT=""
SOURCE_PR=""
SOURCE_REPO="coralogix/opentelemetry-helm-charts"
DRY_RUN=false
SKIP_CHARTS=""
SUMMARY_FILE="/tmp/otel-bump-summary.md"

ALL_CHARTS="otel-integration otel-linux-standalone otel-macos-standalone otel-windows-standalone"

CHART_STATUS=""
CHART_WARNINGS=""

get_chart_path() {
  case "$1" in
    otel-integration) echo "otel-integration/k8s-helm" ;;
    otel-linux-standalone) echo "otel-linux-standalone" ;;
    otel-macos-standalone) echo "otel-macos-standalone" ;;
    otel-windows-standalone) echo "otel-windows-standalone" ;;
    *) echo "" ;;
  esac
}

get_changelog_path() {
  case "$1" in
    otel-integration) echo "otel-integration/CHANGELOG.md" ;;
    otel-linux-standalone) echo "otel-linux-standalone/CHANGELOG.md" ;;
    otel-macos-standalone) echo "otel-macos-standalone/CHANGELOG.md" ;;
    otel-windows-standalone) echo "otel-windows-standalone/CHANGELOG.md" ;;
    *) echo "" ;;
  esac
}

log_info() { echo "[INFO] $*" >&2; }
log_success() { echo "[SUCCESS] $*" >&2; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

set_chart_status() {
  local chart="$1"
  local status="$2"
  CHART_STATUS="$CHART_STATUS $chart:$status"
}

add_chart_warning() {
  local chart="$1"
  local warning="$2"
  CHART_WARNINGS="$CHART_WARNINGS|$chart:$warning"
}

get_chart_status() {
  local chart="$1"
  echo "$CHART_STATUS" | tr ' ' '\n' | grep "^$chart:" | cut -d: -f2 | tail -1
}

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^#//' | sed 's/^ //'
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --version)
        NEW_VERSION="$2"
        shift 2
        ;;
      --changelog-file)
        CHANGELOG_FILE="$2"
        shift 2
        ;;
      --source-commit)
        SOURCE_COMMIT="$2"
        shift 2
        ;;
      --source-pr)
        SOURCE_PR="$2"
        shift 2
        ;;
      --source-repo)
        SOURCE_REPO="$2"
        shift 2
        ;;
      --skip)
        SKIP_CHARTS="$SKIP_CHARTS $2"
        shift 2
        ;;
      --summary-file)
        SUMMARY_FILE="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --help|-h)
        usage
        ;;
      *)
        log_error "Unknown option: $1"
        exit 1
        ;;
    esac
  done

  if [[ -z "$NEW_VERSION" ]]; then
    log_error "--version is required"
    usage
  fi
}

should_skip() {
  local chart="$1"
  echo "$SKIP_CHARTS" | grep -qw "$chart"
}

increment_patch_version() {
  local version="$1"
  local major minor patch
  IFS='.' read -r major minor patch <<< "$version"
  echo "${major}.${minor}.$((patch + 1))"
}

get_current_chart_version() {
  local chart_yaml="$1"
  yq '.version' "$chart_yaml" | tr -d '"'
}

get_dependency_version() {
  local chart_yaml="$1"
  yq '.dependencies[] | select(.name == "opentelemetry-collector") | .version' "$chart_yaml" | head -1 | tr -d '"'
}

update_chart_yaml() {
  local chart="$1"
  local chart_path
  chart_path=$(get_chart_path "$chart")
  local chart_yaml="$REPO_ROOT/$chart_path/Chart.yaml"
  
  if [[ ! -f "$chart_yaml" ]]; then
    log_error "Chart.yaml not found: $chart_yaml"
    return 1
  fi

  local current_version
  current_version=$(get_current_chart_version "$chart_yaml")
  local new_chart_version
  new_chart_version=$(increment_patch_version "$current_version")
  
  local current_dep_version
  current_dep_version=$(get_dependency_version "$chart_yaml")

  log_info "  Chart version: $current_version -> $new_chart_version"
  log_info "  Dependency version: $current_dep_version -> $NEW_VERSION"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "$new_chart_version"
    return 0
  fi

  yq -i ".version = \"$new_chart_version\"" "$chart_yaml"
  yq -i "(.dependencies[] | select(.name == \"opentelemetry-collector\") | .version) = \"$NEW_VERSION\"" "$chart_yaml"

  echo "$new_chart_version"
}

update_values_yaml() {
  local chart="$1"
  local new_chart_version="$2"
  local chart_path
  chart_path=$(get_chart_path "$chart")
  local values_yaml="$REPO_ROOT/$chart_path/values.yaml"

  if [[ ! -f "$values_yaml" ]]; then
    log_warn "  values.yaml not found: $values_yaml (skipping)"
    return 0
  fi

  local current_global_version
  current_global_version=$(yq '.global.version // ""' "$values_yaml" | tr -d '"')
  
  if [[ -z "$current_global_version" ]]; then
    log_warn "  No global.version in values.yaml (skipping)"
    return 0
  fi

  log_info "  global.version: $current_global_version -> $new_chart_version"

  if [[ "$DRY_RUN" == "true" ]]; then
    return 0
  fi

  yq -i ".global.version = \"$new_chart_version\"" "$values_yaml"
}

update_changelog() {
  local chart="$1"
  local new_chart_version="$2"
  local changelog_path
  changelog_path="$REPO_ROOT/$(get_changelog_path "$chart")"
  local today
  today=$(date +%Y-%m-%d)

  if [[ ! -f "$changelog_path" ]]; then
    log_error "  CHANGELOG.md not found: $changelog_path"
    return 1
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "  Would update CHANGELOG.md"
    return 0
  fi

  # Build changelog entry in a temp file
  local entry_file
  entry_file=$(mktemp)
  
  echo "### v${new_chart_version} / ${today}" > "$entry_file"
  echo "" >> "$entry_file"
  echo "- [Chore] Bump chart dependency to opentelemetry-collector ${NEW_VERSION}" >> "$entry_file"

  if [[ -n "$CHANGELOG_FILE" && -f "$CHANGELOG_FILE" ]]; then
    echo "" >> "$entry_file"
    echo "#### Changes from opentelemetry-collector ${NEW_VERSION}:" >> "$entry_file"
    cat "$CHANGELOG_FILE" >> "$entry_file"
  fi

  echo "" >> "$entry_file"

  # Find first version header line number and insert before it
  local first_version_line
  first_version_line=$(grep -n "^### v[0-9]" "$changelog_path" | head -1 | cut -d: -f1)

  if [[ -n "$first_version_line" ]]; then
    # Insert entry before the first version header
    local temp_file
    temp_file=$(mktemp)
    head -n $((first_version_line - 1)) "$changelog_path" > "$temp_file"
    cat "$entry_file" >> "$temp_file"
    tail -n +$first_version_line "$changelog_path" >> "$temp_file"
    mv "$temp_file" "$changelog_path"
  else
    # No version headers found, append to end
    cat "$entry_file" >> "$changelog_path"
  fi

  rm -f "$entry_file"
  log_info "  Updated CHANGELOG.md"
}

run_post_commands() {
  local chart="$1"
  local chart_path
  chart_path=$(get_chart_path "$chart")
  local full_path="$REPO_ROOT/$chart_path"
  local has_warning=false
  local cmd_output
  local cmd_exit

  if [[ "$DRY_RUN" == "true" ]]; then
    if [[ "$chart" == "otel-integration" ]]; then
      log_info "  Would run: helm dependency update"
    else
      log_info "  Would run: helm dependency update && make otel-config"
    fi
    return 0
  fi

  if [[ "$chart" == "otel-integration" ]]; then
    log_info "  Running helm dependency update..."
    cmd_output=$(cd "$full_path" && helm dependency update 2>&1) && cmd_exit=0 || cmd_exit=$?
    if [[ $cmd_exit -ne 0 ]]; then
      echo "$cmd_output" >&2
      log_error "  Failed: helm dependency update (exit code: $cmd_exit)"
      add_chart_warning "$chart" "helm dependency update failed"
      has_warning=true
    fi
  else
    # Standalone charts: update deps first, then generate config
    log_info "  Running helm dependency update..."
    cmd_output=$(cd "$REPO_ROOT/$chart" && helm dependency update 2>&1) && cmd_exit=0 || cmd_exit=$?
    if [[ $cmd_exit -ne 0 ]]; then
      echo "$cmd_output" >&2
      log_error "  Failed: helm dependency update (exit code: $cmd_exit)"
      add_chart_warning "$chart" "helm dependency update failed"
      has_warning=true
    fi
    
    local makefile="$REPO_ROOT/${chart}/Makefile"
    if [[ -f "$makefile" ]]; then
      log_info "  Running make otel-config..."
      cmd_output=$(cd "$REPO_ROOT/$chart" && make otel-config 2>&1) && cmd_exit=0 || cmd_exit=$?
      # Check for helm errors in output even if exit code is 0
      if [[ $cmd_exit -ne 0 ]] || echo "$cmd_output" | grep -qi "^error:"; then
        echo "$cmd_output" >&2
        log_error "  Failed: make otel-config (exit code: $cmd_exit)"
        add_chart_warning "$chart" "make otel-config failed - check helm template errors"
        has_warning=true
      else
        # Show just the "Wrote" line on success
        echo "$cmd_output" | grep -i "^Wrote" >&2 || true
      fi
    else
      log_warn "  No Makefile found, skipping otel-config generation"
    fi
  fi

  if [[ "$has_warning" == "true" ]]; then
    return 1
  fi
  return 0
}

process_chart() {
  local chart="$1"
  
  log_info "Processing $chart..."

  if should_skip "$chart"; then
    log_warn "  Skipped (via --skip flag)"
    set_chart_status "$chart" "skipped"
    return 0
  fi

  local chart_path
  chart_path=$(get_chart_path "$chart")
  if [[ ! -d "$REPO_ROOT/$chart_path" ]]; then
    log_error "  Chart path not found: $chart_path"
    set_chart_status "$chart" "failed"
    return 1
  fi

  local chart_yaml="$REPO_ROOT/$chart_path/Chart.yaml"
  local current_dep_version
  current_dep_version=$(get_dependency_version "$chart_yaml")
  if [[ "$current_dep_version" == "$NEW_VERSION" ]]; then
    log_warn "  Already at version $NEW_VERSION - skipping"
    set_chart_status "$chart" "skipped"
    return 0
  fi

  local new_chart_version
  new_chart_version=$(update_chart_yaml "$chart")

  if [[ -z "$new_chart_version" ]]; then
    log_error "  Failed to get new chart version"
    set_chart_status "$chart" "failed"
    return 1
  fi

  update_values_yaml "$chart" "$new_chart_version"
  update_changelog "$chart" "$new_chart_version"
  
  if run_post_commands "$chart"; then
    set_chart_status "$chart" "ok"
    log_success "  Completed $chart"
  else
    set_chart_status "$chart" "warning"
    log_warn "  Completed $chart with warnings"
  fi
}

generate_summary() {
  local has_failures=false
  local has_warnings=false
  
  echo "" >&2
  log_info "=========================================="
  log_info "Summary"
  log_info "=========================================="
  echo "" >&2
  echo "New opentelemetry-collector version: $NEW_VERSION" >&2
  echo "" >&2
  echo "Charts:" >&2
  
  for chart in $ALL_CHARTS; do
    local status
    status=$(get_chart_status "$chart")
    case "$status" in
      ok)
        echo "  [OK]      $chart" >&2
        ;;
      skipped)
        echo "  [SKIP]    $chart" >&2
        ;;
      warning)
        echo "  [WARN]    $chart" >&2
        has_warnings=true
        ;;
      failed)
        echo "  [FAILED]  $chart" >&2
        has_failures=true
        ;;
      *)
        echo "  [?]       $chart" >&2
        ;;
    esac
  done
  
  # Show warnings details
  if [[ -n "$CHART_WARNINGS" ]]; then
    echo "" >&2
    echo "Warnings:" >&2
    echo "$CHART_WARNINGS" | tr '|' '\n' | grep -v '^$' | while read -r warning; do
      local wchart wtext
      wchart=$(echo "$warning" | cut -d: -f1)
      wtext=$(echo "$warning" | cut -d: -f2-)
      echo "  - $wchart: $wtext" >&2
    done
  fi
  
  echo "" >&2
  if [[ -n "$SOURCE_COMMIT" ]]; then
    echo "Source commit: $SOURCE_COMMIT" >&2
  fi
  if [[ -n "$SOURCE_PR" ]]; then
    echo "Source PR: #$SOURCE_PR" >&2
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "" >&2
    log_warn "DRY RUN - no changes were made"
  fi
  
  echo "" >&2
  echo "Summary file: $SUMMARY_FILE" >&2
  
  if [[ "$has_failures" == "true" ]]; then
    echo "" >&2
    log_error "Some charts failed to process"
    return 1
  fi
  
  if [[ "$has_warnings" == "true" ]]; then
    echo "" >&2
    log_warn "Some charts completed with warnings - review the output above"
  fi
}

generate_markdown_summary() {
  local has_warnings=false
  local has_failures=false
  
  {
    echo "## OpenTelemetry Collector Bump Summary"
    echo ""
    echo "**Version:** \`$NEW_VERSION\`"
    
    # Source links
    if [[ -n "$SOURCE_COMMIT" || -n "$SOURCE_PR" ]]; then
      echo -n "**Source:** "
      local links=""
      if [[ -n "$SOURCE_COMMIT" ]]; then
        local short_commit="${SOURCE_COMMIT:0:7}"
        links="[${short_commit}](https://github.com/${SOURCE_REPO}/commit/${SOURCE_COMMIT})"
      fi
      if [[ -n "$SOURCE_PR" ]]; then
        if [[ -n "$links" ]]; then
          links="$links | "
        fi
        links="${links}[PR #${SOURCE_PR}](https://github.com/${SOURCE_REPO}/pull/${SOURCE_PR})"
      fi
      echo "$links"
    fi
    
    echo ""
    echo "### Charts"
    echo ""
    echo "| Chart | Status | Notes |"
    echo "|-------|--------|-------|"
    
    for chart in $ALL_CHARTS; do
      local status
      status=$(get_chart_status "$chart")
      local status_icon notes=""
      
      case "$status" in
        ok)
          status_icon="✅ OK"
          ;;
        skipped)
          status_icon="⏭️ Skipped"
          ;;
        warning)
          status_icon="⚠️ Warning"
          has_warnings=true
          # Get warning for this chart
          notes=$(echo "$CHART_WARNINGS" | tr '|' '\n' | grep "^$chart:" | cut -d: -f2- | head -1)
          ;;
        failed)
          status_icon="❌ Failed"
          has_failures=true
          ;;
        *)
          status_icon="❓ Unknown"
          ;;
      esac
      
      echo "| $chart | $status_icon | $notes |"
    done
    
    # Warnings section
    if [[ -n "$CHART_WARNINGS" ]]; then
      echo ""
      echo "### Warnings"
      echo ""
      echo "$CHART_WARNINGS" | tr '|' '\n' | grep -v '^$' | while read -r warning; do
        local wchart wtext
        wchart=$(echo "$warning" | cut -d: -f1)
        wtext=$(echo "$warning" | cut -d: -f2-)
        echo "- **$wchart:** $wtext"
      done
    fi
    
    # Changelog entries if provided
    if [[ -n "$CHANGELOG_FILE" && -f "$CHANGELOG_FILE" ]]; then
      echo ""
      echo "### Changes from opentelemetry-collector $NEW_VERSION"
      echo ""
      cat "$CHANGELOG_FILE"
    fi
    
    # Footer
    echo ""
    echo "---"
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "*🔍 DRY RUN - no changes were made*"
    else
      echo "*Generated by bump-otel-collector-version.sh*"
    fi
    
  } > "$SUMMARY_FILE"
  
  log_info "Markdown summary written to: $SUMMARY_FILE"
}

main() {
  parse_args "$@"

  command -v yq >/dev/null 2>&1 || { log_error "yq is required but not installed"; exit 1; }
  command -v helm >/dev/null 2>&1 || { log_error "helm is required but not installed"; exit 1; }

  log_info "Bumping opentelemetry-collector to version $NEW_VERSION"
  if [[ "$DRY_RUN" == "true" ]]; then
    log_warn "DRY RUN mode enabled"
  fi
  echo "" >&2

  cd "$REPO_ROOT"

  for chart in $ALL_CHARTS; do
    process_chart "$chart" || true
    echo "" >&2
  done

  generate_summary
  generate_markdown_summary
}

main "$@"
