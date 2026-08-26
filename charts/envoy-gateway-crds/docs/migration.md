# Migration From Envoy Gateway Application Chart 1.10.1

This is the self-contained migration procedure from application chart 1.10.1
to 2.0.0. It preserves CRD, custom-resource, policy, and binding UIDs while
moving lifecycle ownership to `envoy-gateway-crds` 1.0.0.

## Why A Bridge Release Is Required

Envoy Gateway chart 1.10.1 owns the safe-upgrade policy and binding as normal
Helm templates. The CRDs themselves are not Helm-owned because they are under
`crds/`.

Disabling the old dependency before the current release revision contains
`helm.sh/resource-policy: keep` can cause Helm to delete the policy resources.
The bridge release records that protection before ownership moves.

## Preflight Inventory

Record the application release, CRD UIDs, custom-resource UIDs, counts, bundle
annotations, and policy ownership before making changes. Store the output with
the change record.

At minimum, capture:

```shell
export NAMESPACE=envoy-gateway
export APP_RELEASE=envoy-gateway
export CRD_RELEASE=envoy-gateway-crds
export BRIDGE_VERSION=2.0.0
export CRD_CHART_VERSION=1.0.0

helm status envoy-gateway --namespace envoy-gateway
kubectl get crd -o json > crds-before.json
kubectl get gatewayclasses,gateways,httproutes -A -o json > gateway-api-before.json
kubectl get envoyproxies,securitypolicies,backendtrafficpolicies -A -o json > envoy-api-before.json
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding \
  safe-upgrades.gateway.networking.k8s.io -o yaml > policy-before.yaml
```

## Migration Procedure

### 1. Install the application bridge

Keep the bundled dependency enabled so application chart 2.0.0 records the
keep policy in both the live resources and the Helm release revision:

```shell
helm upgrade "$APP_RELEASE" \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway \
  --version "$BRIDGE_VERSION" \
  --namespace "$NAMESPACE" \
  --reuse-values \
  --set crds.enabled=true \
  --wait \
  --timeout 10m

for kind in validatingadmissionpolicy validatingadmissionpolicybinding; do
  kubectl get "$kind" safe-upgrades.gateway.networking.k8s.io \
    -o jsonpath='{.metadata.annotations.helm\.sh/resource-policy}{"\n"}'
done
```

Both checks must print `keep`. Stop if either does not.

### 2. Apply the locked CRD bundle

Render the standalone bundle without competing for policy ownership, perform a
server-side dry-run, then apply it with the dedicated field manager:

```shell
helm template "$CRD_RELEASE" \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version "$CRD_CHART_VERSION" \
  --include-crds \
  --set safeUpgradePolicy.management=disabled \
  > envoy-gateway-crds.yaml

kubectl apply --server-side --dry-run=server \
  --field-manager=helmforge-envoy-gateway-crds \
  -f envoy-gateway-crds.yaml
kubectl apply --server-side \
  --field-manager=helmforge-envoy-gateway-crds \
  -f envoy-gateway-crds.yaml
kubectl wait --for=condition=Established --timeout=120s \
  -f envoy-gateway-crds.yaml
```

Do not add `--force-conflicts` without auditing `metadata.managedFields` and
confirming every conflict belongs to the known v1.9.0/v1.6.1 bundle.

### 3. Create the standalone release

The CRDs now exist and were updated server-side. Record the release without
asking Helm to create them again and without adopting the policy yet:

```shell
helm upgrade --install "$CRD_RELEASE" \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version "$CRD_CHART_VERSION" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --skip-crds \
  --set safeUpgradePolicy.management=disabled
```

### 4. Disable the old dependency

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

Confirm the application release no longer contains the policy while both live
objects remain present:

```shell
if helm get manifest "$APP_RELEASE" --namespace "$NAMESPACE" |
  grep -q 'safe-upgrades.gateway.networking.k8s.io'; then
  echo "application release still contains the policy" >&2
  exit 1
fi
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding \
  safe-upgrades.gateway.networking.k8s.io
```

### 5. Transfer policy ownership

Compare the live specifications with the standalone render before adoption:

```shell
helm template "$CRD_RELEASE" \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version "$CRD_CHART_VERSION" \
  --namespace "$NAMESPACE" \
  --skip-crds \
  --set safeUpgradePolicy.management=managed \
  > policy-standalone.yaml

helm upgrade "$CRD_RELEASE" \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version "$CRD_CHART_VERSION" \
  --namespace "$NAMESPACE" \
  --skip-crds \
  --take-ownership \
  --set safeUpgradePolicy.management=managed
```

`--take-ownership` requires Helm 3.17 or later. Older clients must use the
audited metadata fallback below.

### 6. Verify preservation

Capture the same objects and stable name/UID inventories after migration, then
compare them with the preflight files. Every UID and resource count must be
unchanged. Also verify discovery, bundle metadata, controller availability, and
existing Gateway traffic before closing the change.

## Ownership Adoption

Helm 3.17 and later supports `--take-ownership`. Use it only after the
application release has disabled the old dependency and the specifications have
been compared:

```shell
helm upgrade envoy-gateway-crds \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --namespace envoy-gateway \
  --skip-crds \
  --take-ownership \
  --set safeUpgradePolicy.management=managed
```

For older Helm clients, patch exactly these ownership fields on both objects
after the same audit:

- `app.kubernetes.io/managed-by=Helm`
- `meta.helm.sh/release-name=envoy-gateway-crds`
- `meta.helm.sh/release-namespace=envoy-gateway`

Do not edit Helm release Secrets and do not use a hook to transfer ownership.

## Verification

The migration passes only when:

- All 18 CRD UIDs are unchanged.
- All custom-resource UIDs and counts are unchanged.
- Gateway API annotations remain v1.6.1 and Experimental.
- Envoy CRD annotations identify v1.9.0.
- The policy and binding are owned only by the standalone release.
- Envoy Gateway is Available and reconciles existing resources.
- Existing Gateway traffic remains successful.

## Recovery

If any UID changes or a custom resource disappears, stop immediately. Do not
continue with adoption or application upgrade. Preserve diagnostics and restore
forward from the captured manifests; do not downgrade CRD schemas.

After adoption, do not roll the application back to a revision from before the
bridge. Such a revision attempts to add the policy and binding back to the old
release. Deploy the required compatible controller chart with
`crds.enabled=false` instead.
