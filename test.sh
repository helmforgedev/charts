#!/usr/bin/env bash

set -u

SCRIPT_NAME="$(basename "$0")"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHARTS_DIR="$ROOT_DIR/charts"

TOTAL_CHECKS=0
FAILED_CHECKS=0

KUBECTL_CONTEXT_OK=0
LINT_OK=1
UNITTEST_OK=1
CI_TEMPLATE_OK=1

HAS_UNITTEST_PLUGIN=0

usage() {
  cat <<'EOF'
HelmForge charts validation helper.

Usage:
  ./test.sh <chart-name>
  ./test.sh --all
  ./test.sh --help

Examples:
  ./test.sh mosquitto
  ./test.sh --all

What it checks per chart:
  1) helm dependency build
  2) helm lint --strict
  3) helm template (default values)
  4) helm template for every charts/<chart>/ci/*.yaml file
  5) helm unittest (requires helm-unittest plugin)

It also prints the current kubectl context and a PR checklist snippet at the end.
EOF
}

info() {
  echo "[INFO] $*"
}

ok() {
  echo "[PASS] $*"
}

warn() {
  echo "[WARN] $*"
}

fail() {
  echo "[FAIL] $*"
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Required command not found: $cmd"
    exit 1
  fi
}

run_check() {
  local label="$1"
  shift

  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  if "$@"; then
    ok "$label"
    return 0
  fi

  FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fail "$label"
  return 1
}

run_quiet() {
  "$@" >/dev/null 2>&1
}

chart_exists() {
  local chart="$1"
  [[ -f "$CHARTS_DIR/$chart/Chart.yaml" ]]
}

discover_all_charts() {
  local dir
  for dir in "$CHARTS_DIR"/*; do
    [[ -d "$dir" ]] || continue
    [[ -f "$dir/Chart.yaml" ]] || continue
    basename "$dir"
  done
}

run_ci_templates() {
  local chart="$1"
  local chart_path="$CHARTS_DIR/$chart"
  local ci_file
  local ci_found=0

  shopt -s nullglob
  for ci_file in "$chart_path"/ci/*.yaml; do
    ci_found=1
    if ! helm template test-release "$chart_path" -f "$ci_file" >/dev/null; then
      return 1
    fi
  done
  shopt -u nullglob

  if [[ "$ci_found" -eq 0 ]]; then
    warn "No ci/*.yaml files found for '$chart' (skipping scenario rendering)"
  fi

  return 0
}

validate_chart() {
  local chart="$1"
  local chart_path="$CHARTS_DIR/$chart"

  echo
  info "Validating chart: $chart"

  run_check "[$chart] helm dependency build" run_quiet helm dependency build "$chart_path"

  if ! run_check "[$chart] helm lint --strict" run_quiet helm lint "$chart_path" --strict; then
    LINT_OK=0
  fi

  run_check "[$chart] helm template (default values)" run_quiet helm template test-release "$chart_path"

  if ! run_check "[$chart] helm template for ci/*.yaml scenarios" run_ci_templates "$chart"; then
    CI_TEMPLATE_OK=0
  fi

  if [[ "$HAS_UNITTEST_PLUGIN" -eq 1 ]]; then
    if ! run_check "[$chart] helm unittest" run_quiet helm unittest "$chart_path"; then
      UNITTEST_OK=0
    fi
  else
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    UNITTEST_OK=0
    fail "[$chart] helm unittest (helm-unittest plugin not installed)"
  fi
}

print_checklist_snippet() {
  local lint_box="[x]"
  local unittest_box="[x]"
  local ci_box="[x]"
  local context_box="[x]"

  [[ "$LINT_OK" -eq 1 ]] || lint_box="[ ]"
  [[ "$UNITTEST_OK" -eq 1 ]] || unittest_box="[ ]"
  [[ "$CI_TEMPLATE_OK" -eq 1 ]] || ci_box="[ ]"
  [[ "$KUBECTL_CONTEXT_OK" -eq 1 ]] || context_box="[ ]"

  echo
  echo "PR checklist snippet:"
  echo "- $context_box I confirmed \`kubectl config current-context\` before local installs/upgrades/uninstalls"
  echo "- $lint_box \`helm lint charts/<chart-name> --strict\` passed"
  echo "- $unittest_box \`helm unittest charts/<chart-name>\` passed"
  echo "- $ci_box All relevant \`ci/*.yaml\` scenarios rendered successfully"
  echo "- [ ] I validated this change on a local \`k3d\` cluster when required"
  echo "- [ ] I validated the default install"
  echo "- [ ] I validated at least one main non-default scenario for this change"
}

main() {
  local -a charts_to_check=()
  case "${1:-}" in
    "")
      usage
      exit 0
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --all)
      if [[ "$#" -ne 1 ]]; then
        fail "Use only --all, without extra arguments."
        usage
        exit 1
      fi
      mapfile -t charts_to_check < <(discover_all_charts)
      if [[ "${#charts_to_check[@]}" -eq 0 ]]; then
        fail "No charts found under '$CHARTS_DIR'."
        exit 1
      fi
      ;;
    *)
      if [[ "$#" -ne 1 ]]; then
        fail "Expected exactly one chart name, or --all."
        usage
        exit 1
      fi

      if ! chart_exists "$1"; then
        fail "Chart '$1' not found in '$CHARTS_DIR'."
        exit 1
      fi
      charts_to_check=("$1")
      ;;
  esac

  require_command helm
  require_command kubectl

  local context
  context="$(kubectl config current-context 2>/dev/null || true)"
  if [[ -n "$context" ]]; then
    KUBECTL_CONTEXT_OK=1
    info "kubectl context: $context"
  else
    warn "Could not read kubectl context"
  fi

  if helm plugin list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -qx "unittest"; then
    HAS_UNITTEST_PLUGIN=1
  else
    warn "helm-unittest plugin is missing. Install with:"
    warn "  helm plugin install https://github.com/helm-unittest/helm-unittest --verify=false"
  fi

  info "Charts selected: ${charts_to_check[*]}"

  local chart
  for chart in "${charts_to_check[@]}"; do
    validate_chart "$chart"
  done

  echo
  echo "Summary: $((TOTAL_CHECKS - FAILED_CHECKS))/$TOTAL_CHECKS checks passed."
  print_checklist_snippet

  if [[ "$FAILED_CHECKS" -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
