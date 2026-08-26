# Envoy Gateway CRDs - Research Findings

**Issue:** [#981](https://github.com/helmforgedev/charts/issues/981)
**Upstream:** <https://github.com/envoyproxy/gateway>
**Research date:** 2026-08-18

## Recommendation

Publish `envoy-gateway-crds` as an independent cluster-scoped chart before the
Envoy Gateway application chart. Keep CRDs in Helm's special `crds/`
directories, use conditional internal subcharts to select Gateway API and Envoy
Gateway bundles independently, and keep the Gateway API safe-upgrade policy in
normal templates.

The application chart must not depend on this chart. Separate Helm releases are
the mechanism that lets Kubernetes discovery observe the CRDs before
`helm-diff` validates custom resources from the application release.

## Supported Compatibility Set

| Component | Supported version |
| --- | --- |
| Envoy Gateway | v1.9.0 |
| Gateway API | v1.6.1 |
| Gateway API channel | Experimental |
| Kubernetes | 1.33 through 1.36 |
| Envoy Proxy | distroless-v1.39.0 |

This is the exact upstream Envoy Gateway v1.9 compatibility matrix. Gateway API
v1.5.1 belongs to Envoy Gateway v1.8 and must not be used for this release.

## Current HelmForge State

The existing `envoy-gateway` 1.10.1 chart contains one local `crds` dependency.
That dependency installs:

- 10 Gateway API v1.6.1 Experimental CRDs.
- 8 Envoy Gateway v1.9.0 extension CRDs.
- One `ValidatingAdmissionPolicy` and its binding.

The 18 CRDs occupy approximately 3.87 MB before compression. Because they are
stored under `crds/`, Helm creates them before templates but does not add them to
the release manifest, upgrade them, or delete them. The policy and binding are
ordinary templates and are owned by the Envoy Gateway application release.

`crds.enabled=false` removes the local dependency but the application chart
still renders `EnvoyProxy`, `GatewayClass`, `Gateway`, and `HTTPRoute`. A first
`helm diff upgrade --allow-unreleased` therefore fails when the cluster has not
registered those APIs yet.

## Existing Upstream CRD Chart

Envoy Gateway publishes `gateway-crds-helm`, but it places CRDs in `templates/`
to allow values-based selection. Upstream documents `helm template | kubectl
apply --server-side` instead of `helm install` because storing the rendered CRDs
in the Helm release Secret can exceed the Kubernetes 1 MiB object limit.

Copying that design would not meet issue #981's requirement for a real release
A. HelmForge instead uses conditional internal subcharts whose CRDs remain in
special `crds/` directories. Disabled dependencies are removed before Helm
collects CRD objects, so selection remains possible without templating the
CRDs.

## Ownership Model

Literal Helm ownership of CRDs is intentionally not claimed. Helm does not
track objects installed from `crds/`, even if ownership annotations are added.
Adding Helm ownership metadata would therefore be misleading.

The supported ownership model is:

- Helm owns the standalone release record, safe-upgrade policy, and binding.
- Server-side apply manages CRD fields with field manager
  `helmforge-envoy-gateway-crds`.
- Static bundle annotations identify the source version and digest.
- CRD lifecycle is forward-only and cluster-admin controlled.

## Safe-Upgrade Policy

The Gateway API v1.6.1 policy remains in `templates/` because it is not a CRD.
The standalone chart exposes an explicit management mode:

- `managed`: render the policy and binding and let Helm enforce ownership.
- `external`: another release or platform owns them; render nothing.
- `disabled`: intentionally omit them for bootstrap and migration operations.

Both managed resources use `helm.sh/resource-policy: keep`. The chart must not
silently stop rendering when it detects a different owner; Helm's ownership
error is the correct fail-fast behavior.

## Upgrade Model

Helm never upgrades objects from `crds/`. Upgrades therefore use this order:

1. Inspect installed bundle versions, channels, UIDs, and stored versions.
2. Render only the selected CRDs with `helm template --include-crds` and the
   safe-upgrade policy disabled.
3. Execute a server-side dry-run.
4. Apply with field manager `helmforge-envoy-gateway-crds`.
5. Wait for every selected CRD to become `Established=True`.
6. Upgrade the standalone Helm release with `--skip-crds`.
7. Upgrade the Envoy Gateway application release.

`--force-conflicts` is never a default. It may be used only after an operator
audits the conflicting fields and confirms that the installed bundle is known
and compatible. CRD downgrade is unsupported.

## Migration From Envoy Gateway 1.10.1

The current application release owns the safe-upgrade policy and binding. A
bridge release is mandatory before disabling or removing the local CRD
dependency:

1. Upgrade the application to a bridge version that still renders the policy
   but adds `helm.sh/resource-policy: keep`.
2. Record CRD and custom-resource UIDs and counts.
3. Apply the standalone chart's identical CRD bundle server-side.
4. Install the standalone release with the policy disabled and `--skip-crds`.
5. Upgrade the application bridge release with `crds.enabled=false`.
6. Verify that Helm preserved the policy and binding.
7. Compare resource specifications before adoption.
8. Adopt the policy and binding into the standalone release with Helm
   `--take-ownership` or audited metadata patches.
9. Enable the policy in the standalone release.
10. Confirm all original UIDs, counts, and custom-resource content remain.

Adding `keep` only to the live object is insufficient. The annotation must be
present in the application release revision before the dependency is disabled.

## Application Preflight

When the application uses external CRDs, it must fail before Kubernetes emits a
generic resource mapping error. Presence checks use
`.Capabilities.APIVersions.Has` for the complete required GVK set. Exact bundle
version, channel, and CRD metadata checks use `lookup` only when cluster access
is available.

Normal `helm-diff` validation can prove discovery presence. Exact annotations
are additionally verified by a real install/upgrade or `helm diff
--dry-run=server`.

## Validation Constraints Discovered

- The current HelmForge k3d server is Kubernetes 1.31.5, outside the supported
  v1.9 matrix.
- The prepare flow does not pin a K3s version.
- `helm-diff` 3.15.11 is not installed by the current prepare flow.
- Generic k3d validation passes vacuously for a chart with no workloads and
  does not prove CRD lifecycle behavior.
- Generic kubeconform validation omits CRDs because it does not use
  `--include-crds`.
- Kubescape reports no scannable resources for a CRD-only chart. The correct
  result is documented `N/A`, not a fabricated workload.

These gates must be made deterministic before the chart can be considered
release-ready.

## Primary Sources

- <https://github.com/envoyproxy/gateway/blob/v1.9.0/site/content/en/news/releases/matrix.md>
- <https://gateway.envoyproxy.io/v1.9/install/install-helm/>
- <https://github.com/envoyproxy/gateway/tree/v1.9.0/charts/gateway-helm/charts/crds>
- <https://github.com/envoyproxy/gateway/tree/v1.9.0/charts/gateway-crds-helm>
- <https://github.com/kubernetes-sigs/gateway-api/releases/tag/v1.6.1>
- <https://github.com/kubernetes-sigs/gateway-api/blob/v1.6.1/site/content/en/guides/crd-management/_index.md>
- <https://helm.sh/docs/chart_best_practices/custom_resource_definitions/>
- <https://github.com/databus23/helm-diff/tree/v3.15.11>
