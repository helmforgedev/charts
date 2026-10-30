# Exposure

Atuin clients use HTTP APIs on `service.port`, which defaults to 8888 and
targets the named application port. `containerPorts.http` configures the real
Atuin listener through `ATUIN_PORT`; it also defaults to 8888. Enable either
`ingress` or `gatewayAPI`, configure a DNS name, and terminate TLS. Plain HTTP
is unsafe for authentication credentials even though synchronized history
content is end-to-end encrypted.

When `atuin.path` is non-empty, configure the same prefix in the route. Large sync requests may require
controller-specific body-size settings. Metrics use a separate Service on
`metrics.port` (9001 by default) and are never attached to Ingress or
HTTPRoute.
