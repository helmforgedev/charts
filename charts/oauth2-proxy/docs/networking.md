# OAuth2 Proxy Networking

## Ingress

Use `ingress.ingressClassName` for the target Ingress controller. Configure TLS at the ingress edge and keep `config.cookie.secure=true` for HTTPS deployments.

## Gateway API

Gateway API is configured with the `gateway` block. Set `gateway.parentRefs` to the Gateway that terminates traffic and `gateway.hostnames` to the public auth hostname.

## Dual Stack

The Service exposes `service.ipFamilyPolicy` and `service.ipFamilies` so IPv4, IPv6, and dual-stack clusters can be configured without template overrides.
