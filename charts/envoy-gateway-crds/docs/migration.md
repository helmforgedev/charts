# Migration From Envoy Gateway 1.10.1

Use the command-by-command procedure in the
[Envoy Gateway chart documentation](https://helmforge.dev/docs/charts/envoy-gateway#crd-migration-from-chart-1101).
The summary below defines the invariants that the migration must preserve.

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
helm status envoy-gateway --namespace envoy-gateway
kubectl get crd -o json > crds-before.json
kubectl get gatewayclasses,gateways,httproutes -A -o json > gateway-api-before.json
kubectl get envoyproxies,securitypolicies,backendtrafficpolicies -A -o json > envoy-api-before.json
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding \
  safe-upgrades.gateway.networking.k8s.io -o yaml > policy-before.yaml
```

## Migration Procedure

1. Upgrade Envoy Gateway to the published bridge release with
   `crds.enabled=true`.
2. Verify the policy and binding now contain `helm.sh/resource-policy: keep`.
3. Render the standalone CRDs with policy management disabled.
4. Run server-side dry-run, then apply using field manager
   `helmforge-envoy-gateway-crds`.
5. Wait for all 18 CRDs to become Established.
6. Install `envoy-gateway-crds` with `--skip-crds` and policy disabled.
7. Upgrade the application bridge release with `crds.enabled=false`.
8. Verify the policy and binding still exist and no UID changed.
9. Compare the live policy specifications with the standalone template.
10. Adopt the two policy resources with Helm `--take-ownership`, or use the
    audited metadata fallback documented below.
11. Enable policy management in the standalone release.
12. Re-run the complete UID, count, discovery, controller, and traffic checks.

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
