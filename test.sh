#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHARTS_DIR="$ROOT_DIR/charts"

TOTAL_CHECKS=0
FAILED_CHECKS=0

RUN_ALL=0
RUN_KUBECONFORM=1
RUN_ARTIFACTHUB=1
RUN_KUBESCAPE=1
RUN_UNITTEST=1
RUN_RUNTIME=0
KEEP_NAMESPACE=0
AUTO_INSTALL_TOOLS=1

RELEASE_NAME="hf-test"
NAMESPACE=""
EXPECTED_CONTEXT_PREFIX="k3d-"
RUNTIME_TIMEOUT="120s"
KUBESCAPE_MIN_SCORE=50
TOOL_BIN_DIR="${HELMFORGE_TOOLS_DIR:-$HOME/.local/bin}"
HELM_VERSION="${HELM_VERSION:-v4.1.4}"
KUBECONFORM_VERSION="${KUBECONFORM_VERSION:-v0.7.0}"
AH_VERSION="${AH_VERSION:-1.22.0}"
KUBESCAPE_VERSION="${KUBESCAPE_VERSION:-4.0.9}"
KUBECTL_VERSION="${KUBECTL_VERSION:-stable}"
VALUES_FILES=()
CHARTS_TO_CHECK=()

LINT_OK=1
TEMPLATE_OK=1
UNITTEST_OK=1
KUBECONFORM_OK=1
ARTIFACTHUB_OK=1
KUBESCAPE_OK=1
RUNTIME_OK=1
CONTEXT_OK=0
UNITTEST_RAN=0

usage() {
  cat <<'EOF'
HelmForge charts validation helper.

Usage:
  ./test.sh <chart-name> [options]
  ./test.sh --all [options]
  ./test.sh --help

Common examples:
  ./test.sh redis
  ./test.sh uptime-kuma --values charts/uptime-kuma/ci/mysql-values.yaml --runtime
  ./test.sh generic --skip-kubescape
  ./test.sh --all --skip-runtime

What it checks by default:
  1) helm dependency build
  2) helm lint --strict
  3) helm template with default values
  4) helm template for every charts/<chart>/ci/*.yaml file
  5) kubeconform for default values and every ci/*.yaml file
  6) helm unittest --with-subchart=false when tests/ exists
  7) Artifact Hub lint
  8) Kubescape MITRE, NSA, and SOC2 scan with a minimum score gate

Runtime validation:
  --runtime installs the chart into the current k3d context with helm --wait --timeout 120s,
  checks workloads, events, and pod logs, then removes the namespace unless --keep-namespace is set.

Options:
  --all                       Validate all charts under charts/
  --values <file>             Extra values file for runtime install. Can be repeated.
  --release <name>            Runtime Helm release name. Default: hf-test
  --namespace <name>          Runtime namespace. Default: hf-test-<chart>
  --kube-context <prefix>     Required context prefix for runtime checks. Default: k3d-
  --runtime                   Run local k3d install validation
  --skip-runtime              Do not run runtime validation (default)
  --skip-kubeconform          Skip kubeconform validation
  --skip-artifacthub          Skip Artifact Hub lint
  --skip-kubescape            Skip Kubescape scan
  --skip-unittest             Skip helm-unittest
  --keep-namespace            Keep runtime namespace after validation
  --no-install                Fail when a required tool is missing instead of installing it

Tool bootstrap:
  Missing helm, kubectl, kubeconform, ah, kubescape, and helm-unittest are installed
  before validation when the selected gates need them. CLI tools are installed into
  ${HELMFORGE_TOOLS_DIR:-$HOME/.local/bin} by default. Override versions with
  HELM_VERSION, KUBECTL_VERSION, KUBECONFORM_VERSION, AH_VERSION, and KUBESCAPE_VERSION.
EOF
}

info() { echo "[INFO] $*"; }
ok() { echo "[PASS] $*"; }
warn() { echo "[WARN] $*"; }
fail() { echo "[FAIL] $*"; }

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Required command not found: $cmd"
    exit 1
  fi
}

ensure_tool_path() {
  mkdir -p "$TOOL_BIN_DIR"
  case ":$PATH:" in
    *":$TOOL_BIN_DIR:"*) ;;
    *) export PATH="$TOOL_BIN_DIR:$PATH" ;;
  esac
}

require_bootstrap_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Cannot install missing tools because '$cmd' is not available"
    exit 1
  fi
}

platform_os() {
  local os
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  case "$os" in
    linux|darwin) printf '%s\n' "$os" ;;
    msys*|mingw*|cygwin*) printf 'windows\n' ;;
    *) fail "Unsupported OS for tool bootstrap: $os"; exit 1 ;;
  esac
}

platform_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) printf 'amd64\n' ;;
    aarch64|arm64) printf 'arm64\n' ;;
    *) fail "Unsupported architecture for tool bootstrap: $arch"; exit 1 ;;
  esac
}

download_file() {
  local url="$1"
  local output="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$output"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$url" -O "$output"
  else
    fail "Cannot download tools because neither curl nor wget is available"
    exit 1
  fi
}

install_binary_from_archive() {
  local url="$1"
  local binary_name="$2"
  local archive
  local extract_dir
  archive="$(mktemp)"
  extract_dir="$(mktemp -d)"

  require_bootstrap_command tar
  info "Downloading $binary_name from $url"
  download_file "$url" "$archive"
  tar -xzf "$archive" -C "$extract_dir"

  local found
  found="$(find "$extract_dir" -type f -name "$binary_name" -o -name "$binary_name.exe" | head -1)"
  if [[ -z "$found" ]]; then
    rm -rf "$archive" "$extract_dir"
    fail "Could not find $binary_name in downloaded archive"
    exit 1
  fi

  cp "$found" "$TOOL_BIN_DIR/$binary_name"
  chmod +x "$TOOL_BIN_DIR/$binary_name"
  rm -rf "$archive" "$extract_dir"
}

install_kubectl() {
  local os
  local arch
  local version
  os="$(platform_os)"
  arch="$(platform_arch)"
  version="$KUBECTL_VERSION"

  if [[ "$version" == "stable" ]]; then
    local version_file
    version_file="$(mktemp)"
    download_file "https://dl.k8s.io/release/stable.txt" "$version_file"
    version="$(tr -d '\r\n' < "$version_file")"
    rm -f "$version_file"
  fi

  local suffix=""
  [[ "$os" == "windows" ]] && suffix=".exe"
  info "Downloading kubectl $version"
  download_file "https://dl.k8s.io/release/$version/bin/$os/$arch/kubectl$suffix" "$TOOL_BIN_DIR/kubectl"
  chmod +x "$TOOL_BIN_DIR/kubectl"
}

install_tool() {
  local cmd="$1"
  local os
  local arch
  os="$(platform_os)"
  arch="$(platform_arch)"

  ensure_tool_path
  case "$cmd" in
    helm)
      install_binary_from_archive "https://get.helm.sh/helm-${HELM_VERSION}-${os}-${arch}.tar.gz" helm
      ;;
    kubectl)
      install_kubectl
      ;;
    kubeconform)
      install_binary_from_archive "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-${os}-${arch}.tar.gz" kubeconform
      ;;
    ah)
      local ah_os="$os"
      [[ "$ah_os" == "darwin" ]] && ah_os="macos"
      install_binary_from_archive "https://github.com/artifacthub/hub/releases/download/v${AH_VERSION}/ah_${AH_VERSION}_${ah_os}_${arch}.tar.gz" ah
      ;;
    kubescape)
      install_binary_from_archive "https://github.com/kubescape/kubescape/releases/download/v${KUBESCAPE_VERSION}/kubescape_${KUBESCAPE_VERSION}_${os}_${arch}.tar.gz" kubescape
      ;;
    *)
      fail "No bootstrap recipe is defined for: $cmd"
      exit 1
      ;;
  esac
}

ensure_command() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$AUTO_INSTALL_TOOLS" -eq 0 ]]; then
    fail "Required command not found: $cmd"
    exit 1
  fi

  warn "Required command not found: $cmd; installing into $TOOL_BIN_DIR"
  install_tool "$cmd"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Installed $cmd, but it is still not available in PATH"
    exit 1
  fi
}

selected_charts_have_tests() {
  local chart
  for chart in "${CHARTS_TO_CHECK[@]}"; do
    if [[ -d "$CHARTS_DIR/$chart/tests" ]]; then
      return 0
    fi
  done
  return 1
}

ensure_helm_unittest() {
  if helm plugin list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -qx "unittest"; then
    return 0
  fi

  if [[ "$AUTO_INSTALL_TOOLS" -eq 0 ]]; then
    fail "helm-unittest plugin is missing. Install with: helm plugin install https://github.com/helm-unittest/helm-unittest"
    exit 1
  fi

  info "Installing helm-unittest plugin"
  helm plugin install https://github.com/helm-unittest/helm-unittest --verify=false
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

helm_dependency_build() {
  local chart_path="$1"
  helm dependency build "$chart_path"
}

template_default() {
  local chart_path="$1"
  helm template test-release "$chart_path"
}

template_ci_values() {
  local chart="$1"
  local chart_path="$CHARTS_DIR/$chart"
  local ci_file
  local ci_found=0

  shopt -s nullglob
  for ci_file in "$chart_path"/ci/*.yaml; do
    ci_found=1
    info "Rendering $chart with $ci_file"
    helm template test-release "$chart_path" -f "$ci_file" >/dev/null || return 1
  done
  shopt -u nullglob

  if [[ "$ci_found" -eq 0 ]]; then
    warn "No ci/*.yaml files found for '$chart' (skipping scenario rendering)"
  fi

  return 0
}

kubeconform_render() {
  kubeconform -strict -summary \
    -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
    -exit-on-error
}

kubeconform_default() {
  local chart_path="$1"
  helm template test-release "$chart_path" | kubeconform_render
}

kubeconform_ci_values() {
  local chart="$1"
  local chart_path="$CHARTS_DIR/$chart"
  local ci_file
  local ci_found=0

  shopt -s nullglob
  for ci_file in "$chart_path"/ci/*.yaml; do
    ci_found=1
    info "Kubeconform validating $chart with $ci_file"
    helm template test-release "$chart_path" -f "$ci_file" | kubeconform_render || return 1
  done
  shopt -u nullglob

  if [[ "$ci_found" -eq 0 ]]; then
    warn "No ci/*.yaml files found for '$chart' (skipping scenario kubeconform)"
  fi

  return 0
}

helm_unittest() {
  local chart_path="$1"
  helm unittest --with-subchart=false "$chart_path"
}

artifacthub_lint() {
  local chart="$1"
  (cd "$ROOT_DIR" && ah lint -p "charts/$chart")
}

kubescape_scan() {
  local chart="$1"
  local report
  report="$(mktemp)"

  (cd "$ROOT_DIR" && kubescape scan framework "MITRE,NSA,SOC2" "charts/$chart") 2>&1 | tee "$report"

  local score
  local score_int
  score="$(grep -E 'Overall compliance-score|Resource Summary' "$report" | grep -Eo '[0-9]+([.][0-9]+)?%' | tail -1 | tr -d '%' || true)"
  score="${score:-0}"
  score_int="$(printf '%s\n' "$score" | awk '{print int($1)}')"
  rm -f "$report"

  info "Kubescape score for $chart: $score%"
  [[ "$score_int" -ge "$KUBESCAPE_MIN_SCORE" ]]
}

runtime_namespace_for_chart() {
  local chart="$1"
  if [[ -n "$NAMESPACE" ]]; then
    printf '%s\n' "$NAMESPACE"
  else
    printf 'hf-test-%s\n' "$chart"
  fi
}

cleanup_runtime_namespace() {
  local ns="$1"

  if [[ "$KEEP_NAMESPACE" -eq 0 ]]; then
    helm uninstall "$RELEASE_NAME" --namespace "$ns" >/dev/null 2>&1 || true
    kubectl delete namespace "$ns" --wait=false >/dev/null 2>&1 || true
  else
    warn "Keeping namespace '$ns' because --keep-namespace was set"
  fi
}

current_context() {
  kubectl config current-context 2>/dev/null || true
}

require_runtime_context() {
  local context
  context="$(current_context)"
  if [[ -z "$context" ]]; then
    fail "Cannot read kubectl context"
    return 1
  fi

  info "kubectl context: $context"
  if [[ "$context" != "$EXPECTED_CONTEXT_PREFIX"* ]]; then
    fail "Runtime validation requires a local context matching '$EXPECTED_CONTEXT_PREFIX*'"
    return 1
  fi

  CONTEXT_OK=1
}

runtime_install() {
  local chart="$1"
  local chart_path="$CHARTS_DIR/$chart"
  local ns
  ns="$(runtime_namespace_for_chart "$chart")"
  local -a value_args=()
  local value_file

  for value_file in "${VALUES_FILES[@]}"; do
    value_args+=(--values "$value_file")
  done

  kubectl create namespace "$ns" >/dev/null 2>&1 || true
  info "Installing $chart as release '$RELEASE_NAME' in namespace '$ns'"

  if ! helm upgrade --install "$RELEASE_NAME" "$chart_path" \
    --namespace "$ns" \
    "${value_args[@]}" \
    --wait \
    --timeout "$RUNTIME_TIMEOUT"; then
    collect_runtime_evidence "$ns"
    cleanup_runtime_namespace "$ns"
    return 1
  fi

  collect_runtime_evidence "$ns"
  if ! validate_runtime_events "$ns"; then
    cleanup_runtime_namespace "$ns"
    return 1
  fi

  if ! validate_runtime_logs "$ns"; then
    cleanup_runtime_namespace "$ns"
    return 1
  fi

  cleanup_runtime_namespace "$ns"
}

collect_runtime_evidence() {
  local ns="$1"
  echo
  info "Runtime resources in namespace $ns"
  kubectl get all,pvc,ingress,httproute,externalsecret -n "$ns" 2>/dev/null || kubectl get all,pvc,ingress -n "$ns" 2>/dev/null || true
  echo
  info "Recent namespace events"
  kubectl get events -n "$ns" --sort-by=.lastTimestamp 2>/dev/null | tail -40 || true
}

validate_runtime_events() {
  local ns="$1"
  local events
  events="$(kubectl get events -n "$ns" --sort-by=.lastTimestamp 2>/dev/null || true)"
  if printf '%s\n' "$events" | grep -Eiq 'Warning|Failed|BackOff|Unhealthy|FailedMount|FailedScheduling|ImagePullBackOff|ErrImagePull|CrashLoopBackOff'; then
    fail "Runtime events contain warnings or failures"
    return 1
  fi

  return 0
}

validate_runtime_logs() {
  local ns="$1"
  local pods
  pods="$(kubectl get pods -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)"
  local pod
  local bad=0

  while IFS= read -r pod; do
    [[ -n "$pod" ]] || continue
    info "Checking logs for pod $pod"
    local logs
    logs="$(kubectl logs -n "$ns" "$pod" --all-containers --tail=120 2>&1 || true)"
    if printf '%s\n' "$logs" | grep -Eiq 'panic|fatal|traceback|permission denied|CrashLoopBackOff|Error:|ERROR'; then
      printf '%s\n' "$logs" | tail -80
      bad=1
    fi
  done <<< "$pods"

  [[ "$bad" -eq 0 ]]
}

validate_chart() {
  local chart="$1"
  local chart_path="$CHARTS_DIR/$chart"

  echo
  info "Validating chart: $chart"

  run_check "[$chart] helm dependency build" run_quiet helm_dependency_build "$chart_path"

  if ! run_check "[$chart] helm lint --strict" run_quiet helm lint "$chart_path" --strict; then
    LINT_OK=0
  fi

  if ! run_check "[$chart] helm template (default values)" run_quiet template_default "$chart_path"; then
    TEMPLATE_OK=0
  fi

  if ! run_check "[$chart] helm template for ci/*.yaml scenarios" template_ci_values "$chart"; then
    TEMPLATE_OK=0
  fi

  if [[ "$RUN_KUBECONFORM" -eq 1 ]]; then
    if ! run_check "[$chart] kubeconform (default values)" run_quiet kubeconform_default "$chart_path"; then
      KUBECONFORM_OK=0
    fi
    if ! run_check "[$chart] kubeconform for ci/*.yaml scenarios" kubeconform_ci_values "$chart"; then
      KUBECONFORM_OK=0
    fi
  fi

  if [[ "$RUN_UNITTEST" -eq 1 ]]; then
    if [[ -d "$chart_path/tests" ]]; then
      UNITTEST_RAN=1
      if ! run_check "[$chart] helm unittest --with-subchart=false" run_quiet helm_unittest "$chart_path"; then
        UNITTEST_OK=0
      fi
    else
      warn "[$chart] no tests/ directory found (helm unittest skipped)"
    fi
  fi

  if [[ "$RUN_ARTIFACTHUB" -eq 1 ]]; then
    if ! run_check "[$chart] Artifact Hub lint" artifacthub_lint "$chart"; then
      ARTIFACTHUB_OK=0
    fi
  fi

  if [[ "$RUN_KUBESCAPE" -eq 1 ]]; then
    if ! run_check "[$chart] Kubescape MITRE,NSA,SOC2" kubescape_scan "$chart"; then
      KUBESCAPE_OK=0
    fi
  fi

  if [[ "$RUN_RUNTIME" -eq 1 ]]; then
    if ! run_check "[$chart] k3d runtime install and log/event validation" runtime_install "$chart"; then
      RUNTIME_OK=0
    fi
  fi
}

print_checklist_snippet() {
  local lint_box="[x]"
  local template_box="[x]"
  local unittest_box="[x]"
  local kubeconform_box="[x]"
  local artifacthub_box="[x]"
  local kubescape_box="[x]"
  local runtime_box="[x]"
  local context_box="[x]"
  local context_note=""
  local unittest_note=""
  local kubeconform_note=""
  local artifacthub_note=""
  local kubescape_note=""
  local runtime_note=""

  [[ "$LINT_OK" -eq 1 ]] || lint_box="[ ]"
  [[ "$TEMPLATE_OK" -eq 1 ]] || template_box="[ ]"
  [[ "$UNITTEST_OK" -eq 1 ]] || unittest_box="[ ]"
  [[ "$KUBECONFORM_OK" -eq 1 ]] || kubeconform_box="[ ]"
  [[ "$ARTIFACTHUB_OK" -eq 1 ]] || artifacthub_box="[ ]"
  [[ "$KUBESCAPE_OK" -eq 1 ]] || kubescape_box="[ ]"
  [[ "$RUNTIME_OK" -eq 1 ]] || runtime_box="[ ]"
  [[ "$CONTEXT_OK" -eq 1 || "$RUN_RUNTIME" -eq 0 ]] || context_box="[ ]"

  if [[ "$RUN_RUNTIME" -eq 0 ]]; then
    runtime_box="[ ]"
    runtime_note=" (not run; add --runtime when runtime validation is required)"
  fi

  if [[ "$RUN_UNITTEST" -eq 0 ]]; then
    unittest_box="[ ]"
    unittest_note=" (skipped by --skip-unittest)"
  elif [[ "$UNITTEST_RAN" -eq 0 ]]; then
    unittest_box="[ ]"
    unittest_note=" (not applicable: no tests/ directory)"
  fi

  if [[ "$RUN_KUBECONFORM" -eq 0 ]]; then
    kubeconform_box="[ ]"
    kubeconform_note=" (skipped by --skip-kubeconform)"
  fi

  if [[ "$RUN_ARTIFACTHUB" -eq 0 ]]; then
    artifacthub_box="[ ]"
    artifacthub_note=" (skipped by --skip-artifacthub)"
  fi

  if [[ "$RUN_KUBESCAPE" -eq 0 ]]; then
    kubescape_box="[ ]"
    kubescape_note=" (skipped by --skip-kubescape)"
  fi

  if [[ "$RUN_RUNTIME" -eq 0 ]]; then
    context_box="[ ]"
    context_note=" (not required without --runtime)"
  fi

  echo
  echo "PR checklist snippet:"
  echo "- $context_box I confirmed \`kubectl config current-context\` before local installs/upgrades/uninstalls$context_note"
  echo "- $lint_box \`helm lint charts/<chart-name> --strict\` passed"
  echo "- $template_box \`helm template\` passed for default values and relevant \`ci/*.yaml\` scenarios"
  echo "- $unittest_box \`helm unittest --with-subchart=false charts/<chart-name>\` passed when tests exist$unittest_note"
  echo "- $kubeconform_box \`kubeconform -strict\` passed without \`--ignore-missing-schema\`$kubeconform_note"
  echo "- $artifacthub_box \`ah lint -p charts/<chart-name>\` passed$artifacthub_note"
  echo "- $kubescape_box \`kubescape scan framework \"MITRE,NSA,SOC2\"\` passed the minimum score gate$kubescape_note"
  echo "- $runtime_box local k3d runtime validation passed when required, including pod status, events, and logs$runtime_note"
  echo "- [ ] I updated chart docs and the site repo when public behavior changed"
  echo "- [ ] I linked or created the required GitHub issue for this PR"
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage
        exit 0
        ;;
      --all)
        RUN_ALL=1
        ;;
      --runtime)
        RUN_RUNTIME=1
        ;;
      --skip-runtime)
        RUN_RUNTIME=0
        ;;
      --skip-kubeconform)
        RUN_KUBECONFORM=0
        ;;
      --skip-artifacthub)
        RUN_ARTIFACTHUB=0
        ;;
      --skip-kubescape)
        RUN_KUBESCAPE=0
        ;;
      --skip-unittest)
        RUN_UNITTEST=0
        ;;
      --keep-namespace)
        KEEP_NAMESPACE=1
        ;;
      --no-install)
        AUTO_INSTALL_TOOLS=0
        ;;
      --values|-f)
        shift
        [[ "${1:-}" ]] || { fail "--values requires a file path"; exit 1; }
        VALUES_FILES+=("$1")
        ;;
      --release)
        shift
        [[ "${1:-}" ]] || { fail "--release requires a name"; exit 1; }
        RELEASE_NAME="$1"
        ;;
      --namespace|-n)
        shift
        [[ "${1:-}" ]] || { fail "--namespace requires a name"; exit 1; }
        NAMESPACE="$1"
        ;;
      --kube-context)
        shift
        [[ "${1:-}" ]] || { fail "--kube-context requires a context prefix"; exit 1; }
        EXPECTED_CONTEXT_PREFIX="$1"
        ;;
      --*)
        fail "Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        CHARTS_TO_CHECK+=("$1")
        ;;
    esac
    shift
  done
}

validate_args() {
  if [[ "$RUN_ALL" -eq 1 && "${#CHARTS_TO_CHECK[@]}" -gt 0 ]]; then
    fail "Use either --all or explicit chart names, not both."
    exit 1
  fi

  if [[ "$RUN_ALL" -eq 1 ]]; then
    mapfile -t CHARTS_TO_CHECK < <(discover_all_charts)
  fi

  if [[ "${#CHARTS_TO_CHECK[@]}" -eq 0 ]]; then
    usage
    exit 0
  fi

  local chart
  for chart in "${CHARTS_TO_CHECK[@]}"; do
    if ! chart_exists "$chart"; then
      fail "Chart '$chart' not found in '$CHARTS_DIR'."
      exit 1
    fi
  done

  local value_file
  for value_file in "${VALUES_FILES[@]}"; do
    if [[ ! -f "$value_file" ]]; then
      fail "Values file not found: $value_file"
      exit 1
    fi
  done

  if [[ "$RUN_RUNTIME" -eq 1 && "$RUN_ALL" -eq 1 ]]; then
    warn "--runtime with --all can be slow and destructive. Use explicit chart names for runtime validation when possible."
  fi
}

main() {
  parse_args "$@"
  validate_args

  ensure_tool_path
  ensure_command helm
  ensure_command kubectl
  [[ "$RUN_KUBECONFORM" -eq 0 ]] || ensure_command kubeconform
  [[ "$RUN_ARTIFACTHUB" -eq 0 ]] || ensure_command ah
  [[ "$RUN_KUBESCAPE" -eq 0 ]] || ensure_command kubescape

  if [[ "$RUN_UNITTEST" -eq 1 ]] && selected_charts_have_tests; then
    ensure_helm_unittest
  fi

  if [[ "$RUN_RUNTIME" -eq 1 ]]; then
    require_runtime_context || exit 1
  else
    local context
    context="$(current_context)"
    if [[ -n "$context" ]]; then
      info "kubectl context: $context"
    else
      warn "Could not read kubectl context"
    fi
  fi

  info "Charts selected: ${CHARTS_TO_CHECK[*]}"

  local chart
  for chart in "${CHARTS_TO_CHECK[@]}"; do
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
