#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Run default + every CI scenario with chart-owned fixtures on an explicit local lab.
set -euo pipefail
context="${1:?Usage: validate-runtime.sh k3d-helmforge-<lab> [evidence-directory]}"
[[ "$context" == k3d-helmforge-* ]] || { echo 'A local k3d-helmforge-* context is required' >&2; exit 1; }
chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
evidence="${2:-$(mktemp -d /tmp/rustfs-ci-evidence.XXXXXX)}"
mkdir -p "$evidence"
evidence="$(cd "$evidence" && pwd)"
[[ "$(kubectl --context "$context" config current-context)" == "$context" ]] || exit 1
namespace=""
cleanup() {
  if [[ -n "$namespace" ]]; then kubectl --context "$context" delete namespace "$namespace" --wait=true --timeout=180s > /dev/null; fi
}
on_exit() {
  status=$?
  if [[ "$status" -ne 0 && -n "$namespace" ]]; then
    kubectl --context "$context" -n "$namespace" get pods,pvc,jobs -o wide > "$evidence/failure-resources.log" 2>&1 || true
    kubectl --context "$context" -n "$namespace" get events --sort-by=.lastTimestamp > "$evidence/failure-events.log" 2>&1 || true
    kubectl --context "$context" -n "$namespace" logs -l app.kubernetes.io/instance=smoke --all-containers --prefix > "$evidence/failure-logs.log" 2>&1 || true
  fi
  cleanup
  exit "$status"
}
trap on_exit EXIT
run_id="$(date +%s)-$$"
scenarios=(default "$chart_dir"/ci/*-values.yaml)
for values in "${scenarios[@]}"; do
  scenario="$(basename "$values" .yaml)"
  namespace="hf-rustfs-${run_id}-${scenario%-values}"
  # Register namespace ownership only after creation succeeds.
  owned_namespace="$namespace"; namespace=""
  kubectl --context "$context" create namespace "$owned_namespace" > /dev/null
  namespace="$owned_namespace"
  args=()
  if [[ "$values" != default ]]; then args=(-f "$values"); fi
  fixture="$chart_dir/ci/fixtures/$scenario.yaml"
  if [[ -f "$fixture" ]]; then
    kubectl --context "$context" -n "$namespace" apply -f "$fixture" > "$evidence/$scenario-fixtures.log"
    while IFS= read -r deployment; do
      [[ -n "$deployment" ]] || continue
      kubectl --context "$context" -n "$namespace" rollout status "$deployment" --timeout=240s >> "$evidence/$scenario-fixtures.log"
    done < <(kubectl --context "$context" -n "$namespace" get deployments -l helmforge.dev/runtime-fixture=true -o name)
  fi
  # Helm waits for post-install hooks even without --wait-for-jobs.
  helm install smoke "$chart_dir" --kube-context "$context" -n "$namespace" "${args[@]}" --wait --timeout 600s > "$evidence/$scenario-install.log" 2>&1
  helm test smoke --kube-context "$context" -n "$namespace" --logs --timeout 120s > "$evidence/$scenario-test.log" 2>&1
  node "$chart_dir/scripts/runtime-smoke.mjs" "$context" "$namespace" smoke > "$evidence/$scenario-smoke.log" 2>&1
  if [[ "$scenario" == replication-* ]]; then
    helm upgrade smoke "$chart_dir" --kube-context "$context" -n "$namespace" "${args[@]}" --wait --timeout 600s > "$evidence/$scenario-upgrade.log" 2>&1
    node "$chart_dir/scripts/runtime-smoke.mjs" "$context" "$namespace" smoke >> "$evidence/$scenario-smoke.log" 2>&1
  fi
  kubectl --context "$context" -n "$namespace" get pods,pvc,jobs -o wide > "$evidence/$scenario-resources.log"
  helm get hooks smoke --kube-context "$context" -n "$namespace" > "$evidence/$scenario-hooks.yaml"
  echo "PASS $scenario"
  cleanup; namespace=""
done
echo "PASS all ${#scenarios[@]} runtime scenarios; evidence: $evidence"
