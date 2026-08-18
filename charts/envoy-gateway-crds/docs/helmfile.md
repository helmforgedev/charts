# Helmfile And GitOps Ordering

## Two-Phase Bootstrap

No single client-side diff can validate custom resources against APIs that do
not exist yet. Bootstrap is intentionally two-phase:

1. Apply the CRD release.
2. Wait for discovery.
3. Diff and apply the application release.

A Helmfile `needs` relationship documents the dependency but does not make a
single global first diff capable of discovering APIs that have not been
applied.

## Conceptual Helmfile Configuration

```yaml
releases:
  - name: envoy-gateway-crds
    namespace: envoy-gateway
    chart: oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds
    version: CRD_CHART_VERSION

  - name: envoy-gateway
    namespace: envoy-gateway
    chart: oci://ghcr.io/helmforgedev/helm/envoy-gateway
    version: APP_CHART_VERSION
    needs:
      - envoy-gateway/envoy-gateway-crds
    values:
      - crds:
          enabled: false
```

Run the CRD selector first during initial bootstrap. Subsequent application
diffs can use normal validation.

## Upgrade Ordering

For upgrades, apply CRD schemas server-side before syncing the CRD release and
the application release. Treat CRDs as a forward-only infrastructure layer.
