# CRD Lifecycle

## Fresh Installation

Install this release before the Envoy Gateway application release:

```shell
helm upgrade --install envoy-gateway-crds \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version VERSION \
  --namespace envoy-gateway \
  --create-namespace

helm show crds oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version VERSION > envoy-gateway-crds-installed.yaml

kubectl wait --for=condition=Established \
  --timeout=120s \
  -f envoy-gateway-crds-installed.yaml
```

The wait checks all 18 CRDs in the packaged default bundle. Refresh discovery
before diffing the application chart.

`helm show crds` does not evaluate subchart conditions, so that file-based wait
is only valid for the default full bundle. For a partial bundle, wait for the
enabled API group instead. For example, provider-managed Gateway API mode
installs only the Envoy Gateway extension group:

```shell
kubectl get crd -o name | grep '\.gateway\.envoyproxy\.io$' |
  xargs kubectl wait --for=condition=Established --timeout=120s
```

## Upgrades

Helm does not upgrade objects from `crds/`. Render the selected CRDs with the
policy disabled so the output contains CRDs only:

```shell
helm template envoy-gateway-crds \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version VERSION \
  --include-crds \
  --set safeUpgradePolicy.management=disabled > envoy-gateway-crds.yaml
```

Inspect the installed bundle and execute server-side dry-run:

```shell
kubectl apply \
  --server-side \
  --dry-run=server \
  --field-manager=helmforge-envoy-gateway-crds \
  -f envoy-gateway-crds.yaml
```

If the dry-run is clean, apply and wait for `Established=True`. Then update the
release record without asking Helm to create CRDs again:

```shell
kubectl apply \
  --server-side \
  --field-manager=helmforge-envoy-gateway-crds \
  -f envoy-gateway-crds.yaml

helm upgrade envoy-gateway-crds \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version VERSION \
  --namespace envoy-gateway \
  --skip-crds
```

Do not use `--force-conflicts` as a routine flag. A conflict identifies another
field manager and requires an ownership audit.

Before publishing or applying a changed bundle, compare the vendored sources
with `BUNDLE.lock.yaml`. The lock records the pre-overlay bytes copied from the
existing v1.9.0 application bundle. Envoy Gateway CRDs add only the documented
HelmForge version/source annotations; their schema content remains unchanged.

## Rollback

`helm rollback envoy-gateway-crds` does not roll CRDs backwards. This is the
safe behavior. Never restore an older schema over stored custom resources.

Rollback the application only to a controller version compatible with the live
CRD bundle.

## Uninstall

`helm uninstall envoy-gateway-crds` preserves the CRDs, custom resources,
policy, and binding. Deletion is an explicit manual cluster administration
operation outside the chart lifecycle.

Before manual CRD deletion, inventory every custom resource and all controllers
that use Gateway API. Deleting a CRD deletes every custom resource of that kind.
