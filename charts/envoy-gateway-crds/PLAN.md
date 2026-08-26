# Envoy Gateway CRDs - Implementation Plan

**Chart:** `envoy-gateway-crds`
**Issue:** [#981](https://github.com/helmforgedev/charts/issues/981)
**Target chart version:** `1.0.0`
**Target maturity:** `stable`
**Complexity:** High

## Executive Summary

Create a separately published, installable Helm chart for the exact CRD set
used by Envoy Gateway v1.9.0. The chart establishes a release boundary before
the Envoy Gateway application chart, provides explicit lifecycle and ownership
contracts, supports provider-managed Gateway API CRDs, and documents a
zero-deletion migration from the current bundled structure.

## Scope

The chart manages the lifecycle contract for:

- 10 Gateway API v1.6.1 Experimental CRDs.
- 8 Envoy Gateway v1.9.0 extension CRDs.
- Gateway API safe-upgrade `ValidatingAdmissionPolicy`.
- Gateway API safe-upgrade `ValidatingAdmissionPolicyBinding`.

It does not install Envoy Gateway, Envoy Proxy, GatewayClass, Gateway, Routes,
or application workloads.

## Priority 1: Standalone CRD Release

### P1-1: Conditional raw CRD bundles

- Create internal `gateway-api-crds` and
  `envoy-gateway-extension-crds` subcharts.
- Keep all CRDs in `crds/` so they stay outside the Helm release Secret.
- Enable each group independently from parent values.
- Preserve exact upstream schemas and record SHA-256 provenance.

### P1-2: Safe-upgrade policy lifecycle

- Render the upstream v1.6.1 CEL policy and binding as templates.
- Add `helm.sh/resource-policy: keep` from the first release.
- Support `managed`, `external`, and `disabled` modes.
- Fail clearly on invalid combinations and ownership conflicts.

### P1-3: Operational documentation

- Document fresh installation, upgrades, rollback boundaries, uninstall,
  external management, compatibility, and emergency recovery.
- Provide exact Helm, Helmfile-style, and server-side apply sequences.

### P1 validation gate

1. Install the chart into a disposable Kubernetes 1.33 cluster.
2. Wait for all 18 CRDs to become Established.
3. Verify the release Secret remains below 1 MiB.
4. Install the application chart with `crds.enabled=false`.
5. Run first-install helm-diff 3.15.11 without disabling validation.
6. Exercise a functional Envoy Gateway HTTP route.
7. Uninstall the CRD release and prove CRDs, custom resources, policy, and
   binding are preserved.

## Priority 2: Bridge Release And Migration

Implemented in an independent `envoy-gateway` branch based on `main`:

- Keep the local dependency temporarily.
- Add `resource-policy: keep` to existing policy resources.
- Add external-CRD presence and compatibility validation.
- Correct Kubernetes compatibility for Envoy Gateway v1.9.
- Deprecate same-release CRD installation.
- Document the ordered migration from chart 1.10.1.

The standalone chart and bridge release must be published separately. The
repository publication workflow sorts changed chart names alphabetically and
would otherwise publish the application before the new CRD chart.

## Priority 3: Final Removal

After a documented migration window:

- Change the application default to external CRDs in a major release.
- Remove the local `crds` subchart and deprecated values.
- Retain compatibility preflight and standalone/external documentation.

This phase is intentionally not part of the initial release.

## Planned Chart Structure

```text
charts/envoy-gateway-crds/
|-- Chart.yaml
|-- values.yaml
|-- values.schema.json
|-- README.md
|-- DESIGN.md
|-- RESEARCH.md
|-- PLAN.md
|-- .helmignore
|-- charts/
|   |-- gateway-api-crds/
|   |   |-- Chart.yaml
|   |   `-- crds/
|   `-- envoy-gateway-extension-crds/
|       |-- Chart.yaml
|       `-- crds/
|-- templates/
|   |-- _helpers.tpl
|   |-- validate.yaml
|   |-- safe-upgrade-policy.yaml
|   `-- NOTES.txt
|-- ci/
|-- docs/
|-- examples/
`-- tests/
```

## Validation Strategy

### Static gates

- Helm dependency resolution and strict lint.
- Default and every `ci/*.yaml` render.
- Unit tests for bundle selection, management modes, keep annotations, and
  validation errors.
- Kubeconform over `helm template --include-crds`.
- Artifact Hub lint and HelmForge standards checks.
- Deterministic count and source digest checks for all 18 CRDs.

### Behavioral gates

- Fresh full install.
- Envoy-only install with provider-managed Gateway API.
- Missing and partial bundle failures.
- Exact version and channel mismatch failures.
- Same-version SSA update preserving UIDs.
- Migration from the published Envoy Gateway 1.10.1 chart.
- Policy ownership transfer.
- TCPRoute and UDPRoute storage-version checks.
- Application rollback inside the supported matrix.
- CRD chart rollback proving schemas are not downgraded.
- Uninstall proving cluster-scoped resources and custom resources remain.

### Tool matrix

- Helm 3.21.x.
- Repository-pinned Helm 4.x.
- helm-diff 3.15.11.
- Kubernetes 1.33 and 1.36 disposable k3d clusters.

The final mandatory chart gates are:

```shell
make validate-chart CHART=envoy-gateway-crds
make validate-chart CHART=envoy-gateway
```

## Documentation Plan

Chart and site documentation will cover:

1. Release separation rationale.
2. Compatibility matrix.
3. Fresh installation.
4. Helmfile-style ordering.
5. Provider-managed Gateway API.
6. Bundle annotations and provenance.
7. Server-side apply upgrade flow.
8. Policy management modes.
9. Migration from application chart 1.10.1.
10. Ownership adoption.
11. UID and custom-resource preservation checks.
12. Rollback boundaries.
13. Uninstall behavior.
14. Troubleshooting.
15. Emergency recovery.

## Acceptance Criteria

- First application diff succeeds without `--disable-validation` after release
  A is installed.
- All 18 CRDs are Established and have the expected versions and annotations.
- The standalone release Secret remains below the Kubernetes size limit.
- Existing installations migrate without deleting or replacing CRDs, custom
  resources, policy, or binding.
- Unsupported, partial, newer unknown, or channel-mismatched bundles fail
  before application resources are submitted.
- Fresh, upgrade, rollback, external-management, and uninstall scenarios have
  deterministic automated coverage.
- Both charts and the site pass every required HelmForge gate.
