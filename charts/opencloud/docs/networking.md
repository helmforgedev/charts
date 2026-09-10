# OpenCloud networking and TLS

## Native HTTPS

The application listener uses HTTPS on 9200 by default. Probes use loopback debug HTTP; readiness additionally checks
NATS. An HTTP 200 or ready Pod alone is insufficient evidence for identity and file operations.

Ingress controllers need an HTTPS backend and certificate verification, including a DNS identity matching the server
certificate. The NGINX example configures backend-protocol, proxy-ssl-verify, proxy-ssl-name, server-name and a Secret
containing ca.crt. Configure upload size/timeouts for your expected file sizes; avoid disabling backend verification.

## Gateway API

Use gatewayAPI.enabled and gatewayAPI.httpRoutes[]. Each route supports parentRefs, hostnames, labels, annotations
and rules with matches, filters and optional backendRefs. An omitted backend targets the application Service.
Distinct unnamed routes receive unique suffixes. Duplicate explicit names are rejected.

Native HTTPS automatically renders a v1 BackendTLSPolicy targeting the application Service port. The Gateway
controller must support this resource. For the generated evaluation certificate, the chart creates a public CA
ConfigMap from the same certificate material. With an existing TLS Secret, configure server.backendTLS.caCertificateRefs
or useSystemCAs. References identify ConfigMaps in the application namespace; a Secret is not a supported CA reference.
The default validation hostname comes from server.publicUrl. Custom route backends require their own TLS policies.

A shared Gateway must allow routes from this namespace. Verify HTTPRoute Accepted/ResolvedRefs and BackendTLSPolicy
Accepted/ResolvedRefs using your actual controller, then test the public hostname. The local chart matrix validates
resource schemas and the native HTTPS backend; it does not claim validation of every Gateway/Ingress implementation.

## Edge termination

To terminate TLS exclusively at the edge, set server.tls.enabled=false and keep server.publicUrl on HTTPS. The Pod
must reach the trusted HTTPS edge for its own OIDC discovery and token validation. Allow DNS and that exact edge
through NetworkPolicy. A public URL resolving to a loopback HTTP listener is not a valid replacement.

## Isolation

Application ingress defaults to same-namespace Pods. Configure networkPolicy.ingressFrom for your controller.
Metrics have separate peers under metrics.ingressFrom and never appear on the application Service or routes.
Egress permits DNS and the native self-service path; external integrations require explicit extraEgress/webEgress.
NetworkPolicy requires an enforcing CNI and does not constrain trusted node or control-plane access.
