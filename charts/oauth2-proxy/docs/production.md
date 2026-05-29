# OAuth2 Proxy Production Notes

## Credentials

Use an existing Secret or ExternalSecret for `client-id`, `client-secret`, and `cookie-secret`.

The cookie secret must be a high-entropy value accepted by OAuth2 Proxy.
Generate it outside Helm and rotate it deliberately because changing it
invalidates existing sessions.

## Reverse Proxy Headers

When `config.reverseProxy.enabled=true`, set
`config.reverseProxy.trustedProxyIps` to only the ingress controller, Gateway
implementation, or edge proxy CIDRs that are allowed to set `X-Forwarded-*`
headers.

Leaving the list empty avoids broad default trust in direct-client deployments.

## Availability

Use at least two replicas with a PodDisruptionBudget for production. Keep the
chart-managed `config-test` init container enabled because it catches invalid
OAuth2 Proxy configuration before the pod enters service.
