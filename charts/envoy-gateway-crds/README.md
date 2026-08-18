# Envoy Gateway CRDs

Standalone lifecycle chart for the Envoy Gateway v1.9.0 extension CRDs,
Gateway API v1.6.1 Experimental CRDs, and Gateway API safe-upgrade policy.

This chart is installed before the HelmForge Envoy Gateway application chart.
The separate release lets Kubernetes discovery register every custom API before
`helm-diff` validates the application resources.

## Compatibility

| Component | Version |
| --- | --- |
| Envoy Gateway CRDs | v1.9.0 |
| Gateway API CRDs | v1.6.1 |
| Gateway API channel | Experimental |
| Kubernetes | 1.33-1.36 |
| Matching application | Envoy Gateway v1.9 bridge release |

See [the complete compatibility contract](docs/compatibility.md) before using a
provider-managed Gateway API bundle.

## Why A Separate Chart

Helm can create CRDs before normal templates during a real install, but a dry
run cannot change API discovery. The application chart renders `EnvoyProxy`,
`GatewayClass`, `Gateway`, and `HTTPRoute`; a first `helm diff` therefore fails
when those APIs do not already exist.

This chart creates a real release boundary:

1. Install the CRD release.
2. Wait for all selected CRDs to become Established.
3. Run the application diff with normal validation.
4. Install the application with bundled CRDs disabled.

The chart does not become a dependency of the application chart because a
dependency would put both layers back in the same Helm operation.

## Installation

### OCI

```shell
helm upgrade --install envoy-gateway-crds \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version VERSION \
  --namespace envoy-gateway \
  --create-namespace
```

### HTTPS repository

```shell
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm upgrade --install envoy-gateway-crds helmforge/envoy-gateway-crds \
  --version VERSION \
  --namespace envoy-gateway \
  --create-namespace
```

### Wait for discovery

```shell
helm show crds oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version VERSION > envoy-gateway-crds-installed.yaml

kubectl wait --for=condition=Established \
  --timeout=120s \
  -f envoy-gateway-crds-installed.yaml

kubectl api-resources --api-group=gateway.networking.k8s.io
kubectl api-resources --api-group=gateway.envoyproxy.io
```

`helm show crds` returns all 18 CRDs from the default packaged bundle, so the
wait is exhaustive rather than a two-object spot check. Use the exact installed
chart version.

### Diff and install Envoy Gateway

```shell
helm diff upgrade envoy-gateway \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway \
  --namespace envoy-gateway \
  --allow-unreleased \
  --set crds.enabled=false

helm upgrade --install envoy-gateway \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway \
  --namespace envoy-gateway \
  --create-namespace \
  --set crds.enabled=false
```

The first diff does not require `--disable-validation` after discovery contains
the selected APIs.

## Installed Resources

The default installation creates:

- 10 Gateway API v1.6.1 Experimental CRDs.
- 8 Envoy Gateway v1.9.0 extension CRDs.
- `ValidatingAdmissionPolicy/safe-upgrades.gateway.networking.k8s.io`.
- `ValidatingAdmissionPolicyBinding/safe-upgrades.gateway.networking.k8s.io`.

The chart creates no pods, containers, Services, credentials, or network
listeners.

## CRD Ownership

Objects under `crds/` are intentionally outside the Helm release manifest.
Helm installs missing CRDs, skips existing CRDs, and does not upgrade or delete
them. The chart therefore does not add misleading Helm ownership annotations to
CRDs.

Lifecycle ownership is represented by:

- The standalone release and compatibility contract.
- Static bundle annotations and the checked-in [source digest lock](BUNDLE.lock.yaml).
- Server-side apply field manager `helmforge-envoy-gateway-crds`.
- Helm ownership of the policy and binding.

See [CRD lifecycle](docs/lifecycle.md) for the supported upgrade and uninstall
behavior.

## Configuration

### CRD bundles

| Parameter | Description | Default |
| --- | --- | --- |
| `crds.gatewayAPI.enabled` | Install Gateway API v1.6.1 Experimental CRDs | `true` |
| `crds.envoyGateway.enabled` | Install Envoy Gateway v1.9.0 extension CRDs | `true` |

At least one bundle must remain enabled.

### Safe-upgrade policy

| Parameter | Description | Default |
| --- | --- | --- |
| `safeUpgradePolicy.management` | `managed`, `external`, or `disabled` | `managed` |
| `commonLabels` | Additional policy and binding labels | `{}` |

`managed` requires the Gateway API bundle to be enabled. Use `external` when a
provider or platform release owns the policy. Use `disabled` only for CRD-only
rendering, bootstrap, or the documented migration procedure.

## Provider-Managed Gateway API

Verify the provider bundle before disabling the HelmForge Gateway API group:

```shell
kubectl get crd gateways.gateway.networking.k8s.io \
  -o go-template='version={{ index .metadata.annotations "gateway.networking.k8s.io/bundle-version" }} channel={{ index .metadata.annotations "gateway.networking.k8s.io/channel" }}{{ "\n" }}'
```

Then install only the Envoy Gateway extension CRDs:

```shell
helm upgrade --install envoy-gateway-crds \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version VERSION \
  --namespace envoy-gateway \
  --create-namespace \
  --set crds.gatewayAPI.enabled=false \
  --set crds.envoyGateway.enabled=true \
  --set safeUpgradePolicy.management=external
```

Do not overwrite provider CRDs with an unknown/newer bundle or a different
channel.

## Upgrading

`helm upgrade` alone does not update CRDs. Render the selected bundle, execute a
server-side dry-run, apply it, wait for Established, then upgrade the release
with `--skip-crds`.

The complete commands and conflict policy are documented in
[CRD lifecycle](docs/lifecycle.md).

Never add `--force-conflicts` by default. Never downgrade CRD schemas.

## Migration From Envoy Gateway 1.10.1

Existing releases must not install the standalone policy immediately because
the application release currently owns the same policy and binding.

The mandatory sequence is:

1. Upgrade the application to the bridge release, still using
   `crds.enabled=true`.
2. Verify `helm.sh/resource-policy: keep` on the policy and binding.
3. Capture CRD and custom-resource UIDs and counts.
4. Apply the identical standalone bundle server-side.
5. Install this release with policy disabled and `--skip-crds`.
6. Upgrade the application bridge release with `crds.enabled=false`.
7. Verify that every UID and custom resource remains.
8. Adopt the policy and binding into this release.
9. Enable managed policy mode and revalidate traffic.

Do not skip the bridge release. Do not patch only the live policy before
disabling the old dependency. Helm needs `keep` in the prior application
release revision.

See [the complete migration procedure](docs/migration.md), including inventory,
ownership adoption, verification, and recovery.

## Helmfile And GitOps

Initial bootstrap is a two-phase operation. A `needs` relationship documents
ordering but cannot make a global client-side diff discover APIs that have not
been applied.

See [Helmfile and GitOps ordering](docs/helmfile.md).

## Rollback

A Helm rollback of this release does not downgrade CRDs. That is intentional.
Application rollback is supported only when the target Envoy Gateway version is
compatible with the live CRD bundle.

If an application rollback would require an older CRD schema, stop and recover
forward instead.

## Uninstall

Uninstalling the release preserves:

- All CRDs.
- All custom resources.
- The managed safe-upgrade policy.
- The managed policy binding.

Manual CRD deletion is intentionally not part of this chart. Kubernetes deletes
all custom resources of a kind when its CRD is deleted.

## Troubleshooting

### Application diff still reports unknown kinds

Confirm every required CRD is Established and refresh the client discovery
cache. Do not disable validation as the permanent solution.

### Helm reports policy ownership conflict

An existing application or platform release owns the policy. Existing
HelmForge users must complete the bridge migration. Provider-managed users must
select `safeUpgradePolicy.management=external`.

### CRDs did not change after helm upgrade

This is expected for `crds/`. Follow the server-side apply upgrade procedure.

### Server-side apply reports conflicts

Inspect `managedFields`, installed bundle annotations, and the conflicting
paths. Do not add `--force-conflicts` until the existing owner and schema are
understood.

### Gateway API channel differs

Do not mix Standard and Experimental CRDs. Choose one compatible cluster-level
owner and reconcile the channel before installing Envoy Gateway.

### A rollback did not restore old schemas

CRDs are forward-only. Helm rollback changes tracked resources but does not
modify objects installed from `crds/`.

### Uninstall left cluster-scoped resources

This is the documented safety contract. CRDs, custom resources, policy, and
binding are retained to prevent data loss.

### Kubernetes version is rejected

Envoy Gateway v1.9 supports Kubernetes 1.33 through 1.36. Upgrade Kubernetes or
select an Envoy Gateway release compatible with the cluster.

### Provider-managed Gateway API lacks an Experimental kind

The provider bundle is not equivalent to the supported full bundle. Either
avoid the feature under an explicitly supported external contract or install a
single compatible Experimental bundle through the cluster owner.

### Stored versions include v1alpha2

Gateway API v1.6 moves TCPRoute and UDPRoute storage to v1. Re-save existing
objects as documented upstream before v1alpha2 is eventually removed.

## Examples

- [Full bundle](examples/full.yaml)
- [Provider-managed Gateway API](examples/provider-managed-gateway-api.yaml)
- [GitOps CRD upgrade render](examples/gitops-upgrade.yaml)

## Security Scan

### Security Scan: `envoy-gateway-crds`

| Framework | Result |
| --- | --- |
| MITRE + NSA + SOC2 | **N/A** |

No Kubescape-scannable workload is rendered. The inventory contains only
`CustomResourceDefinition`, `ValidatingAdmissionPolicy`, and
`ValidatingAdmissionPolicyBinding`. This exception is determined from
`helm template --include-crds`; the chart does not self-exempt by annotation.

## Documentation

- [Compatibility](docs/compatibility.md)
- [CRD lifecycle](docs/lifecycle.md)
- [Migration from 1.10.1](docs/migration.md)
- [Helmfile and GitOps](docs/helmfile.md)
- [Vendored bundle digests](BUNDLE.lock.yaml)
- [Envoy Gateway installation](https://gateway.envoyproxy.io/v1.9/install/install-helm/)
- [Gateway API CRD management](https://gateway-api.sigs.k8s.io/guides/crd-management/)

## Non-Goals

This chart intentionally does not:

- Install Envoy Gateway or Envoy Proxy.
- Create user-facing Gateway API resources.
- Delete CRDs or custom resources.
- Perform automatic CRD downgrade.
- Force server-side apply conflicts.
- Claim Helm ownership of untracked CRDs.

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) and report lifecycle issues through
the [HelmForge charts issue tracker](https://github.com/helmforgedev/charts/issues).

<!-- @AI-METADATA
type: chart-readme
title: Envoy Gateway CRDs Chart
description: Standalone Envoy Gateway and Gateway API CRD lifecycle chart
keywords: envoy-gateway, gateway-api, crds, helm-diff, kubernetes
purpose: Install and operate the CRDs required by Envoy Gateway before the application release
scope: Chart
relations:
  - charts/envoy-gateway-crds/Chart.yaml
  - charts/envoy-gateway-crds/values.yaml
  - charts/envoy-gateway/README.md
path: charts/envoy-gateway-crds/README.md
version: 1.0
date: 2026-08-18
-->
