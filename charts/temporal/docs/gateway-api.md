# Gateway API for Temporal

## Why Two Route Types

Temporal exposes two different application protocols:

- The Web UI is HTTP and belongs behind HTTPRoute.
- The SDK frontend is gRPC over HTTP/2 and belongs behind GRPCRoute.

Classic Ingress does not model gRPC directly. Controllers commonly require
private annotations to switch backend protocol. The chart instead creates
portable Gateway API resources and marks the frontend Service port with
`appProtocol: kubernetes.io/h2c`.

## Ownership Boundary

The chart creates routes, not Gateways. Platform owners control listeners,
certificates, addresses, policies, and cross-namespace permissions. Every route
must provide `parentRefs`; a missing reference fails rendering.

HTTPRoute default backends always use the chart Web UI Service on port 8080.
GRPCRoute default backends always use the chart frontend Service on port 7233.
Internal roles and operational ports have no public route template.

## Listener Example

The referenced Gateway can expose distinct hosts or listeners for HTTP and
gRPC. The chart example assumes `https` and `temporal-grpc` section names. The
Gateway itself remains a platform resource and is intentionally omitted.

After installation:

```bash
kubectl -n temporal get httproute,grpcroute
kubectl -n temporal describe httproute temporal-temporal-ui
kubectl -n temporal describe grpcroute temporal-temporal-frontend
```

Require `Accepted=True` and `ResolvedRefs=True`. Then test the Web UI through
HTTPS and use a real Temporal SDK or CLI against the gRPC hostname.

## Rules and Custom Backends

Routes accept Gateway API `rules`, including matches and filters. When a rule
omits `backendRefs`, the chart inserts the product-safe default. Setting
`omitDefaultBackend: true` permits a filter-only rule. Explicit backendRefs are
an advanced escape hatch and transfer backend correctness to the operator.

## TLS Boundaries

The default backend is h2c: TLS terminates at the Gateway and the controller
opens cleartext HTTP/2 to the frontend Service. Protect that leg with cluster
network controls.

Backend TLS requires a compatible BackendTLSPolicy, CA reference, and hostname.
These resources differ across controller conformance levels and can be supplied
through `extraManifests` after consulting controller documentation.

GRPCRoute termination authenticates the Gateway to Temporal, not the individual
SDK certificate. If the deployment requires end-to-end mTLS identity, use a
TLSRoute passthrough design managed outside the chart. That mode cannot use
GRPCRoute's L7 method and header matching.

## Controller Compatibility

Confirm that the selected controller supports v1 GRPCRoute, h2c backends, the
desired filters, cross-namespace references, and backend TLS policies. Gateway
API resource acceptance is controller status, not proof of application-level
gRPC behavior, so always run a Temporal CLI or SDK request through the listener.

## Troubleshooting

If a route is not accepted, inspect parent listener protocol and hostname
compatibility. If references are unresolved, check Service name, namespace,
port, and ReferenceGrant. If the controller returns HTTP 502 or resets streams,
verify h2c support and Service appProtocol. If the UI works but SDKs fail, debug
the GRPCRoute and listener independently from the HTTPRoute.
