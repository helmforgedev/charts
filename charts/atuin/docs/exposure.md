# Exposure

Atuin clients use HTTP APIs on port 8888. Enable either `ingress` or `gatewayAPI`, configure a DNS name, and terminate
TLS. Plain HTTP is unsafe for authentication credentials even though synchronized history content is end-to-end
encrypted.

When `atuin.path` is non-empty, configure the same prefix in the route. Large sync requests may require
controller-specific body-size settings. Metrics use a separate Service on port 9001 and are never attached to Ingress or
HTTPRoute.
