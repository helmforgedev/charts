<!-- SPDX-License-Identifier: Apache-2.0 -->
# Envoy Gateway — Chart Design

Design notes for the HelmForge `envoy-gateway` chart. It deploys the **Envoy
Gateway** control plane (operator) that implements the Kubernetes Gateway API and
provisions Envoy proxies for ingress/egress traffic.

## Application shape

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

## CRDs

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

## Optional rate limiting

`redis.enabled` provisions a Redis used by the global rate-limit service when
rate-limit policies are enabled.

## Scaling

The controller runs `controller.replicaCount` (default 1) with an optional PDB.
Data-plane scaling is configured on the EnvoyProxy CR (`proxy.replicaCount`), and
the operator provisions/sizes the Envoy fleet accordingly.

## What this chart deliberately does NOT do

- It does not bundle unrelated Gateway API `gateway.networking.x-k8s.io`
  experimental CRDs.
- It does not manage the Envoy data-plane pods directly (the operator does).

## References

- Envoy Gateway: <https://gateway.envoyproxy.io>
- Gateway API: <https://gateway-api.sigs.k8s.io>
- See [`docs/`](docs/) and [`examples/`](examples/).
