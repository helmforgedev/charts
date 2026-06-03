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
so the **operator CRDs** ship in the chart's `crds/` and Helm installs them when
absent. The upstream **Gateway API** CRDs (`gateway.networking.k8s.io`, including
`ListenerSet` from the experimental channel that EG v1.8 watches) are a shared,
cluster-scoped prerequisite — installed once per cluster, not bundled (they are
large and are typically platform-managed, e.g. via Argo CD). See the README.

## Optional rate limiting

`redis.enabled` provisions a Redis used by the global rate-limit service when
rate-limit policies are enabled.

## Scaling

The controller runs `controller.replicaCount` (default 1) with an optional PDB.
Data-plane scaling is configured on the EnvoyProxy CR (`proxy.replicaCount`), and
the operator provisions/sizes the Envoy fleet accordingly.

## What this chart deliberately does NOT do

- It does not bundle the shared Gateway API CRDs (cluster prerequisite).
- It does not manage the Envoy data-plane pods directly (the operator does).

## References

- Envoy Gateway: <https://gateway.envoyproxy.io>
- Gateway API: <https://gateway-api.sigs.k8s.io>
- See [`docs/`](docs/) and [`examples/`](examples/).
