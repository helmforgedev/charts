<!-- SPDX-License-Identifier: Apache-2.0 -->
# Envoy Gateway — Chart Design

## Scope

Design notes for the HelmForge `envoy-gateway` chart. It deploys the **Envoy
Gateway** control plane (operator) that implements the Kubernetes Gateway API and
provisions Envoy proxies for ingress/egress traffic.

## Architecture

- **controller Deployment** — the Envoy Gateway operator (`envoyproxy/gateway`).
  It watches Gateway API resources and the `gateway.envoyproxy.io` policy CRDs and
  reconciles managed Envoy proxy fleets.
- **certgen Job** (pre-install hook) — generates the TLS certs the controller and
  webhook use, before the controller starts.
- **GatewayClass** + an **EnvoyProxy** custom resource — the EnvoyProxy CR
  (`proxy.*`) tells the operator how to provision proxy pods (replicas, resources,
  service type). The proxy pods themselves are managed by the operator, not by
  this chart.
- Optional **Gateway**, example **HTTPRoute** and a demo backend (`gateway.create`,
  `gatewayAPI.examples.enabled`) for a working dev profile.
- Advanced policies (ClientTrafficPolicy, BackendTrafficPolicy, SecurityPolicy,
  rate-limit) are templated when enabled.

## Design Choices

### CRDs

The chart deploys an `EnvoyProxy` CR and other `gateway.envoyproxy.io` resources,
so all required APIs must be discoverable before application rendering. New
installations use the separate `envoy-gateway-crds` release, which contains the
8 Envoy Gateway v1.9.0 CRDs, 10 Gateway API v1.6.1 Experimental CRDs, and the
safe-upgrade admission policy. Kubernetes support follows the upstream Envoy
Gateway v1.9 matrix: versions 1.33 through 1.36.

The local CRD subchart remains temporarily enabled by default as a bridge for
chart 1.10.1 users. Its policy and binding carry
`helm.sh/resource-policy: keep`, allowing the dependency to be disabled before
those resources are adopted by the standalone release. With
`crds.enabled=false`, the application validates all 18 GVKs and, when connected
to a cluster, the exact bundle metadata. See the README and migration guide.

### Optional rate limiting

`redis.enabled` provisions a Redis used by the global rate-limit service when
rate-limit policies are enabled. The chart resolves the subchart client Service
and auth Secret with the subchart fullname logic, so release names that contain
`redis` keep working.

### Fixed controller ports

The controller listens on fixed upstream ports (8080 http, 8081 metrics, 18000
xDS, 18001 rate limit, 18002 Wasm). The EnvoyGateway API does not make them
configurable, so the chart keeps them as constants, marks them with the
`helmforge: fixed-protocol-port` exception, and the controller Service targets
them by name. The optional demo backend (`gatewayAPI.examples`) uses the
go-httpbin default listener on 8080 under the same exception.

## Production Boundary

The controller runs `controller.replicaCount` (default 1) with an optional PDB.
Data-plane scaling is configured on the EnvoyProxy CR (`proxy.replicaCount`), and
the operator provisions/sizes the Envoy fleet accordingly.

- Install the `envoy-gateway-crds` release before the application chart and
  follow the upstream Kubernetes compatibility matrix (1.33 through 1.36).
- Size proxy resources and autoscaling for the expected traffic; profiles
  override the defaults.

## Security Boundary

- The controller runs non-root with a read-only root filesystem, no privilege
  escalation, every capability dropped, and `RuntimeDefault` seccomp. It keeps
  its ServiceAccount token because it is a Kubernetes operator.
- The controller needs cluster-wide RBAC to watch Gateway API resources and to
  provision proxies; restrict who can create Gateways and policies.
- `securityPolicy.cors.allowOrigins` defaults to `*` when CORS is enabled;
  set explicit origins in production. OIDC client secrets and API keys come
  from existing Secrets or ExternalSecret resources.

## Observability Boundary

- Controller probes use `/healthz` and `/readyz` on the metrics port; they do
  not verify that provisioned proxies are healthy.
- `monitoring.*` exposes controller metrics for Prometheus. Proxy metrics and
  access logs follow the EnvoyProxy configuration managed by the operator.

## Current Gaps and Improvement Candidates

- The local CRD subchart remains as a bridge for 1.10.1 users and must be
  removed in a later major release.
- Proxy pods are configured only through the subset of EnvoyProxy fields the
  chart models.

## Explicit Non-Goals

- It does not bundle unrelated Gateway API `gateway.networking.x-k8s.io`
  experimental CRDs.
- It does not manage the Envoy data-plane pods directly (the operator does).

## References

- Envoy Gateway: <https://gateway.envoyproxy.io>
- Gateway API: <https://gateway-api.sigs.k8s.io>
- See [`docs/`](docs/) and [`examples/`](examples/).
