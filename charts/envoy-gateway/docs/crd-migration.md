# CRD Migration From Chart 1.10.1 to 2.0.0

This procedure moves the Envoy Gateway v1.9.0 and Gateway API v1.6.1
Experimental CRD lifecycle out of the application release without deleting or
recreating cluster APIs or stored custom resources.

## User Impact

Chart 1.10.1 allowed Kubernetes 1.26 and installed 18 CRDs through a local
subchart. The CRDs were under Helm's special `crds/` directory, so Helm created
missing objects but never tracked, upgraded, rolled back, or deleted them. The
same subchart rendered a safe-upgrade `ValidatingAdmissionPolicy` and binding as
normal Helm resources owned by the application release.

Chart 2.0.0 is intentionally a major release. The bridge changes three
contracts:

- Kubernetes support is corrected to the upstream Envoy Gateway v1.9 matrix:
  1.33 through 1.36.
- New installations place CRDs and the safe-upgrade policy in the standalone
  `envoy-gateway-crds` release.
- `crds.enabled=false` now fails before application rendering when the complete
  compatible CRD bundle is not discoverable.

Clusters older than Kubernetes 1.33 must be upgraded before this chart. Users
already on 1.10.1 must not disable `crds.enabled` until the bridge step below is
complete.

## Requirements

- Kubernetes 1.33 through 1.36.
- Cluster-admin access for CRDs and admission policies.
- Helm 3.17 or later for `--take-ownership`, or the audited metadata fallback.
- `kubectl` and `jq` for the inventory checks.
- Published bridge and standalone chart versions selected from the same Envoy
  Gateway v1.9.0 compatibility line.

Set the placeholders used below:

```shell
export NAMESPACE=envoy-gateway
export APP_RELEASE=envoy-gateway
export CRD_RELEASE=envoy-gateway-crds
export BRIDGE_VERSION=2.0.0
export CRD_CHART_VERSION=1.0.0

REQUIRED_CRDS='backendtlspolicies.gateway.networking.k8s.io
gatewayclasses.gateway.networking.k8s.io
gateways.gateway.networking.k8s.io
grpcroutes.gateway.networking.k8s.io
httproutes.gateway.networking.k8s.io
listenersets.gateway.networking.k8s.io
referencegrants.gateway.networking.k8s.io
tcproutes.gateway.networking.k8s.io
tlsroutes.gateway.networking.k8s.io
udproutes.gateway.networking.k8s.io
backends.gateway.envoyproxy.io
backendtrafficpolicies.gateway.envoyproxy.io
clienttrafficpolicies.gateway.envoyproxy.io
envoyextensionpolicies.gateway.envoyproxy.io
envoypatchpolicies.gateway.envoyproxy.io
envoyproxies.gateway.envoyproxy.io
httproutefilters.gateway.envoyproxy.io
securitypolicies.gateway.envoyproxy.io'
```

## 1. Capture The Current State

Confirm the current application release and Kubernetes version:

```shell
helm status "$APP_RELEASE" --namespace "$NAMESPACE"
kubectl version
```

Create a change-record directory and capture cluster-scoped objects:

```shell
set -euo pipefail

mkdir -p envoy-gateway-crd-migration
for crd in $REQUIRED_CRDS; do
  kubectl get crd "$crd" -o json
done | jq -s '{apiVersion: "v1", kind: "List", items: .}' \
  > envoy-gateway-crd-migration/crds-before.json
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding \
  safe-upgrades.gateway.networking.k8s.io \
  -o json > envoy-gateway-crd-migration/policy-before.json
```

Capture every stored Gateway API and Envoy Gateway custom resource. A missing
resource type should stop the preflight instead of being silently ignored:

```shell
set -euo pipefail

for resource in $(kubectl api-resources \
  --api-group=gateway.networking.k8s.io \
  --verbs=list \
  -o name); do
  kubectl get "$resource" -A -o json
done > envoy-gateway-crd-migration/gateway-api-before.json

for resource in $(kubectl api-resources \
  --api-group=gateway.envoyproxy.io \
  --verbs=list \
  -o name); do
  kubectl get "$resource" -A -o json
done > envoy-gateway-crd-migration/envoy-api-before.json
```

Create stable name/UID inventories for later comparison:

```shell
set -euo pipefail

jq -r '.items[] | [.metadata.name, .metadata.uid] | @tsv' \
  envoy-gateway-crd-migration/crds-before.json \
  | sort > envoy-gateway-crd-migration/crd-uids-before.tsv

jq -rs '[.[].items[]] | .[] |
  [.apiVersion, .kind, (.metadata.namespace // ""), .metadata.name, .metadata.uid] |
  @tsv' envoy-gateway-crd-migration/gateway-api-before.json \
  envoy-gateway-crd-migration/envoy-api-before.json \
  | sort > envoy-gateway-crd-migration/resource-uids-before.tsv

jq -r '.items[] | [.kind, .metadata.name, .metadata.uid] | @tsv' \
  envoy-gateway-crd-migration/policy-before.json \
  | sort > envoy-gateway-crd-migration/policy-uids-before.tsv
```

## 2. Upgrade To The Bridge With Bundled CRDs Enabled

The bridge must become the current application revision before ownership is
moved. It records `helm.sh/resource-policy: keep` in both the live resources and
the Helm release manifest used by the next upgrade.

```shell
helm upgrade "$APP_RELEASE" \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway \
  --version "$BRIDGE_VERSION" \
  --namespace "$NAMESPACE" \
  --reuse-values \
  --set crds.enabled=true \
  --wait \
  --timeout 10m
```

Verify the protection on both objects:

```shell
kubectl get validatingadmissionpolicy \
  safe-upgrades.gateway.networking.k8s.io \
  -o jsonpath='{.metadata.annotations.helm\.sh/resource-policy}{"\n"}'
kubectl get validatingadmissionpolicybinding \
  safe-upgrades.gateway.networking.k8s.io \
  -o jsonpath='{.metadata.annotations.helm\.sh/resource-policy}{"\n"}'
```

Both commands must print `keep`. Stop if either value is absent.

## 3. Apply The Matching CRD Bundle Server-Side

Render only the selected CRDs. Disabling policy management prevents the
standalone release from competing for policy ownership during this phase:

```shell
helm template "$CRD_RELEASE" \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version "$CRD_CHART_VERSION" \
  --include-crds \
  --set safeUpgradePolicy.management=disabled \
  > envoy-gateway-crd-migration/envoy-gateway-crds.yaml
```

Run a server-side dry-run, inspect conflicts, then apply:

```shell
kubectl apply \
  --server-side \
  --dry-run=server \
  --field-manager=helmforge-envoy-gateway-crds \
  -f envoy-gateway-crd-migration/envoy-gateway-crds.yaml

kubectl apply \
  --server-side \
  --field-manager=helmforge-envoy-gateway-crds \
  -f envoy-gateway-crd-migration/envoy-gateway-crds.yaml

for crd in $REQUIRED_CRDS; do
  kubectl wait --for=condition=Established --timeout=120s "crd/$crd"
done
```

Do not add `--force-conflicts` by default. If the dry-run reports conflicts,
inspect `metadata.managedFields` and confirm that each conflicting field is part
of the known v1.9.0/v1.6.1 bundle before making an explicit ownership decision.

## 4. Create The Standalone Release Without Policy Ownership

The CRDs already exist and were updated server-side. Record the standalone Helm
release without asking Helm to create them again:

```shell
helm upgrade --install "$CRD_RELEASE" \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version "$CRD_CHART_VERSION" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --skip-crds \
  --set safeUpgradePolicy.management=disabled
```

## 5. Disable The Old Dependency

Now upgrade the same bridge application release with the bundled dependency
disabled:

```shell
helm upgrade "$APP_RELEASE" \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway \
  --version "$BRIDGE_VERSION" \
  --namespace "$NAMESPACE" \
  --reuse-values \
  --set crds.enabled=false \
  --wait \
  --timeout 10m
```

This operation performs discovery checks for all 18 required GVKs. When the
Helm operation is server-connected it also checks the v1.6.1 Experimental and
v1.9.0 bundle annotations. Do not use `--disable-validation` to bypass a failure.

Verify that the application manifest no longer contains the policy while the
live policy remains present:

```shell
if helm get manifest "$APP_RELEASE" --namespace "$NAMESPACE" \
  | grep -q 'safe-upgrades.gateway.networking.k8s.io'; then
  echo "application release still contains the safe-upgrade policy" >&2
  exit 1
fi

kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding \
  safe-upgrades.gateway.networking.k8s.io
```

## 6. Transfer Policy Ownership

First render the standalone policy and compare its `spec` with the live policy.
Do not adopt an unexpected policy:

```shell
helm template "$CRD_RELEASE" \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version "$CRD_CHART_VERSION" \
  --namespace "$NAMESPACE" \
  --skip-crds \
  --set safeUpgradePolicy.management=managed \
  > envoy-gateway-crd-migration/policy-standalone.yaml
```

With Helm 3.17 or later, adopt both existing objects and enable managed mode:

```shell
helm upgrade "$CRD_RELEASE" \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version "$CRD_CHART_VERSION" \
  --namespace "$NAMESPACE" \
  --skip-crds \
  --take-ownership \
  --set safeUpgradePolicy.management=managed
```

For older Helm clients, patch only the standard Helm ownership metadata after
the same specification audit, then run the command without `--take-ownership`:

```shell
for kind in validatingadmissionpolicy validatingadmissionpolicybinding; do
  kubectl label "$kind" safe-upgrades.gateway.networking.k8s.io \
    app.kubernetes.io/managed-by=Helm --overwrite
  kubectl annotate "$kind" safe-upgrades.gateway.networking.k8s.io \
    meta.helm.sh/release-name="$CRD_RELEASE" \
    meta.helm.sh/release-namespace="$NAMESPACE" \
    --overwrite
done
```

Never edit Helm release Secrets and never use a hook to transfer ownership.

## 7. Prove That No Object Was Recreated

Capture the post-migration state and compare it to the preflight inventory:

```shell
set -euo pipefail

for crd in $REQUIRED_CRDS; do
  kubectl get crd "$crd" -o json
done | jq -s '{apiVersion: "v1", kind: "List", items: .}' \
  > envoy-gateway-crd-migration/crds-after.json
jq -r '.items[] | [.metadata.name, .metadata.uid] | @tsv' \
  envoy-gateway-crd-migration/crds-after.json \
  | sort > envoy-gateway-crd-migration/crd-uids-after.tsv
diff -u envoy-gateway-crd-migration/crd-uids-before.tsv \
  envoy-gateway-crd-migration/crd-uids-after.tsv

kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding \
  safe-upgrades.gateway.networking.k8s.io \
  -o json > envoy-gateway-crd-migration/policy-after.json
jq -r '.items[] | [.kind, .metadata.name, .metadata.uid] | @tsv' \
  envoy-gateway-crd-migration/policy-after.json \
  | sort > envoy-gateway-crd-migration/policy-uids-after.tsv
diff -u envoy-gateway-crd-migration/policy-uids-before.tsv \
  envoy-gateway-crd-migration/policy-uids-after.tsv
```

Repeat the custom-resource inventory from step 1 into
`resource-uids-after.tsv`, then compare it with `resource-uids-before.tsv`.
The CRD, custom-resource, and policy-resource UID diffs must all be empty. Also
verify:

```shell
kubectl get crd gateways.gateway.networking.k8s.io \
  -o jsonpath='{.metadata.annotations.gateway\.networking\.k8s\.io/bundle-version}{" "}{.metadata.annotations.gateway\.networking\.k8s\.io/channel}{"\n"}'
kubectl get crd envoyproxies.gateway.envoyproxy.io \
  -o jsonpath='{.metadata.annotations.helmforge\.dev/bundle-version}{"\n"}'
kubectl rollout status deployment --namespace "$NAMESPACE" --timeout=5m
kubectl get gatewayclass,gateway,httproute -A
```

Expected bundle output is `v1.6.1 experimental` and `v1.9.0`.

## Helm Diff And GitOps

Bootstrap remains two-phase because a client-side diff cannot discover APIs
that have not been applied. Apply and wait for the CRD release first. Then the
application diff can retain Kubernetes validation:

```shell
helm diff upgrade "$APP_RELEASE" \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway \
  --version "$BRIDGE_VERSION" \
  --namespace "$NAMESPACE" \
  --allow-unreleased \
  --set crds.enabled=false
```

Do not add `--disable-validation`. Use `--dry-run=server` when exact lookup-based
metadata checks are required during diff.

## Rollback And Recovery

CRD schemas are forward-only. `helm rollback envoy-gateway-crds` does not
downgrade objects from `crds/`, and no supported procedure applies older CRD
schemas over stored resources. Roll back the application only to a controller
version compatible with the live bundle.

After policy ownership has moved, do not run `helm rollback` to an application
revision from before the bridge. That revision contains the old CRD dependency
and attempts to add the policy and binding back to the application release.
Use `helm diff rollback` to detect this unsafe plan. Recover by upgrading the
desired compatible application chart with `crds.enabled=false`, not by restoring
the pre-bridge release manifest.

If an inventory comparison changes a UID or loses a custom resource, stop
before policy adoption or further controller changes. Preserve diagnostics and
recover forward from the captured manifests and application backups.

Uninstalling the application release after migration does not touch CRDs or the
policy. Uninstalling the standalone release also retains CRDs, custom resources,
policy, and binding by design. Manual CRD deletion is outside this lifecycle
because Kubernetes deletes all custom resources stored under a deleted CRD.
