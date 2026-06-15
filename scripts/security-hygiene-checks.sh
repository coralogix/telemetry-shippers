#!/usr/bin/env bash
set -euo pipefail

HADOLINT_VERSION="${HADOLINT_VERSION:-2.12.0}"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

usage() {
  cat <<'EOF'
Usage: scripts/security-hygiene-checks.sh [check]

Runs the security and hygiene checks locally. Defaults to "all".

Checks:
  all                 Run every available check. This is the default.
  gitleaks            Scan the current tree for secrets.
  shellcheck          Lint checked-in shell scripts.
  hadolint            Lint checked-in Dockerfiles.
  helm-golden         Check Helm golden renders, if the repo script exists.
  helm-golden-update  Regenerate Helm golden renders, if the repo script exists.

macOS setup:
  brew install helm gitleaks shellcheck

Hadolint runs through Docker by default on macOS to match CI's pinned version:
  HADOLINT_VERSION=2.12.0
EOF
}

missing_commands=()
missing_brew_packages=()

record_missing_cmd() {
  local cmd="$1"
  local brew_package="$2"

  if command -v "$cmd" >/dev/null 2>&1; then
    return
  fi

  missing_commands+=("$cmd")
  missing_brew_packages+=("$brew_package")
}

check_missing_commands() {
  if [ "${#missing_commands[@]}" -eq 0 ]; then
    return
  fi

  echo "Missing required command(s): ${missing_commands[*]}" >&2
  echo "" >&2
  echo "Install on macOS with:" >&2
  echo "  brew install ${missing_brew_packages[*]}" >&2
  echo "" >&2
  echo "Then rerun this script." >&2
  exit 1
}

require_cmd() {
  local cmd="$1"
  local install_hint="${2:-}"

  if command -v "$cmd" >/dev/null 2>&1; then
    return
  fi

  echo "Missing required command: $cmd" >&2
  if [ -n "$install_hint" ]; then
    echo "Install with: $install_hint" >&2
  fi
  exit 1
}

has_helm_golden_script() {
  [ -f ".github/scripts/check-helm-golden-renders.sh" ]
}

preflight() {
  local check="$1"

  case "$check" in
    all)
      record_missing_cmd gitleaks gitleaks
      record_missing_cmd shellcheck shellcheck
      if has_helm_golden_script; then
        record_missing_cmd helm helm
      fi
      ;;
    gitleaks)
      record_missing_cmd gitleaks gitleaks
      ;;
    shellcheck)
      record_missing_cmd shellcheck shellcheck
      ;;
    helm-golden|helm-golden-update)
      record_missing_cmd helm helm
      ;;
  esac

  check_missing_commands
}

docker_cmd() {
  if [ -n "${DOCKER:-}" ]; then
    echo "$DOCKER"
    return
  fi

  if command -v docker >/dev/null 2>&1; then
    command -v docker
    return
  fi

  if [ -x /Applications/Docker.app/Contents/Resources/bin/docker ]; then
    echo "/Applications/Docker.app/Contents/Resources/bin/docker"
    return
  fi

  echo "Missing required command: docker" >&2
  echo "Install and start Docker Desktop, or set DOCKER=/path/to/docker." >&2
  exit 1
}

collect_shell_scripts() {
  local file

  shell_scripts=()
  while IFS= read -r -d '' file; do
    shell_scripts+=("$file")
  done < <(find . -type f -name '*.sh' -not -path './tmp/*' -print0)
}

collect_dockerfiles() {
  local file

  dockerfiles=()
  while IFS= read -r -d '' file; do
    dockerfiles+=("$file")
  done < <(find . -type f \( -name 'Dockerfile' -o -name 'Dockerfile.*' \) -print0)
}

run_gitleaks() {
  require_cmd gitleaks "brew install gitleaks"
  gitleaks detect --no-git --source . --redact --verbose
}

run_shellcheck() {
  require_cmd shellcheck "brew install shellcheck"
  collect_shell_scripts

  if [ "${#shell_scripts[@]}" -eq 0 ]; then
    echo "No shell scripts found."
    return
  fi

  shellcheck "${shell_scripts[@]}"
}

run_hadolint() {
  local docker

  collect_dockerfiles
  if [ "${#dockerfiles[@]}" -eq 0 ]; then
    echo "No Dockerfiles found."
    return
  fi

  docker="$(docker_cmd)"
  "$docker" run --rm \
    -v "$repo_root:/repo" \
    -w /repo \
    "hadolint/hadolint:v${HADOLINT_VERSION}" \
    hadolint "${dockerfiles[@]}"
}

helm_golden_script() {
  if has_helm_golden_script; then
    echo ".github/scripts/check-helm-golden-renders.sh"
    return
  fi

  return 1
}

run_helm_script() {
  local script="$1"
  shift

  if [ -x "$script" ]; then
    "$script" "$@"
  else
    bash "$script" "$@"
  fi
}

run_helm_golden() {
  local script

  if ! script="$(helm_golden_script)"; then
    echo "Skipping Helm golden renders: .github/scripts/check-helm-golden-renders.sh is not present on this branch."
    return
  fi

  require_cmd helm "brew install helm"
  run_helm_script "$script"
}

run_helm_golden_update() {
  local script

  require_cmd helm "brew install helm"

  if ! script="$(helm_golden_script)"; then
    echo "Missing Helm golden render script: .github/scripts/check-helm-golden-renders.sh" >&2
    exit 1
  fi

  run_helm_script "$script" --update
}

print_check_header() {
  local name="$1"

  echo ""
  echo "================================================================"
  echo "Running: $name"
  echo "================================================================"
}

run_all() {
  local failed=0
  local failed_checks=()

  print_check_header "gitleaks"
  if ! run_gitleaks; then
    failed=1
    failed_checks+=("gitleaks")
  fi

  print_check_header "shellcheck"
  if ! run_shellcheck; then
    failed=1
    failed_checks+=("shellcheck")
  fi

  print_check_header "hadolint"
  if ! run_hadolint; then
    failed=1
    failed_checks+=("hadolint")
  fi

  print_check_header "helm-golden"
  if ! run_helm_golden; then
    failed=1
    failed_checks+=("helm-golden")
  fi

  if [ "$failed" -ne 0 ]; then
    echo "" >&2
    echo "Failed check(s): ${failed_checks[*]}" >&2
    return 1
  fi

  echo ""
  echo "All security hygiene checks passed."
}

check="${1:-all}"

case "$check" in
  all)
    preflight "$check"
    run_all
    ;;
  gitleaks)
    preflight "$check"
    run_gitleaks
    ;;
  shellcheck)
    preflight "$check"
    run_shellcheck
    ;;
  hadolint)
    run_hadolint
    ;;
  helm-golden)
    preflight "$check"
    run_helm_golden
    ;;
  helm-golden-update)
    preflight "$check"
    run_helm_golden_update
    ;;
  -h|--help)
    usage
    ;;
  *)
    echo "Unknown check: $check" >&2
    usage >&2
    exit 1
    ;;
esac
