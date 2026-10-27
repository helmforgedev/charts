# OAuth2 Proxy Helm Chart

OAuth2 Proxy is a reverse proxy and authentication gateway for OAuth2 and OIDC
providers. This HelmForge chart deploys the official upstream image with secure
Kubernetes defaults, Gateway API support, ExternalSecret integration, metrics,
and runtime validation.

## Features

- Official `quay.io/oauth2-proxy/oauth2-proxy` image.
- `v7.15.5` default, including upstream authentication-boundary hardening and
  the Go `1.26.8` dependency refresh.
- Reverse proxy header trust disabled by default, with required explicit
  `trusted_proxy_ips` CIDRs when enabled behind ingress controllers, gateways,
  or service mesh edge proxies.
- Chart-managed Secret, existing Secret, or ExternalSecret credential modes.
- Config validation init container using `--config-test`.
- Dual-stack Service defaults, Ingress with `ingressClassName`, Gateway API `HTTPRoute`, ServiceMonitor,
  HPA, PDB, and optional NetworkPolicy.

## Architecture

Client traffic reaches OAuth2 Proxy through its Service, optionally via Ingress
or Gateway API. OAuth2 Proxy authenticates against the configured provider and
forwards accepted requests to one or more upstreams. The chart owns the main
listener through `containerPorts.http` and the metrics listener through
`metrics.port`; both are passed as official command-line flags so legacy and
alpha configuration modes use the same runtime contract. See
[DESIGN.md](DESIGN.md) for trust boundaries and design decisions.

## Install

```bash
helm install oauth2-proxy oci://ghcr.io/helmforgedev/helm/oauth2-proxy \
  --set auth.clientID=example \
  --set auth.clientSecret=example-secret \
  --set auth.cookieSecret=0123456789abcdef0123456789abcdef \
  --set config.provider=github \
  --set config.redirectUrl=https://auth.example.com/oauth2/callback
```

## Credentials

For production, prefer an existing Secret or ExternalSecret:

```yaml
auth:
  existingSecret: oauth2-proxy-auth
  keys:
    clientID: client-id
    clientSecret: client-secret
    cookieSecret: cookie-secret
```

The default chart-managed credentials are local placeholders so `helm install`
can validate and start in disposable environments. Replace them before any
shared or production deployment; keep the cookie secret stable across rollouts
because changing it invalidates sessions.

When `externalSecrets.enabled=true`, `auth.existingSecret` must match the
ExternalSecret target name. Provide either `externalSecrets.data` or
`externalSecrets.dataFrom`.

## Configuration

| Parameter | Default | Description |
| --- | --- | --- |
| `replicaCount` | `2` | Replicas when autoscaling is disabled |
| `containerPorts.http` | `4180` | Real OAuth2 Proxy HTTP listener and pod port |
| `service.port` | `80` | Cluster-facing Service port |
| `metrics.enabled` | `true` | Enable the metrics listener and Service port |
| `metrics.port` | `44180` | Real metrics listener and Service port |
| `auth.existingSecret` | `""` | Existing Secret containing OAuth credentials |
| `config.provider` | `github` | OAuth2 or OIDC provider |
| `config.redirectUrl` | `""` | Explicit OAuth callback URL |
| `config.upstreams` | `[file:///dev/null]` | Protected upstream targets |
| `config.reverseProxy.enabled` | `false` | Trust forwarded proxy headers |
| `config.reverseProxy.trustedProxyIps` | `[]` | Trusted edge proxy CIDRs |
| `alphaConfig.enabled` | `false` | Use structured alpha configuration |
| `networkPolicy.enabled` | `false` | Restrict application ingress and egress |
| `autoscaling.enabled` | `false` | Enable the HPA |
| `pdb.enabled` | `true` | Create a PodDisruptionBudget |

`extraArgs.http-address` and `extraArgs.metrics-address` are rejected because
the chart owns those listeners. Use `containerPorts.http` and `metrics.port`.
The two ports must be different while metrics are enabled.

## Examples

- [Production deployment](examples/production.yaml)
- [Gateway API deployment](examples/gateway.yaml)
- [External Secrets deployment](examples/external-secrets.yaml)

## Reverse Proxy Hardening

OAuth2 Proxy `v7.15.2` introduced `trusted_proxy_ips` to prevent trusting
client-supplied `X-Forwarded-*` headers from untrusted sources. Keep this list
narrow and aligned with the IP ranges used by your ingress controller, Gateway
implementation, or edge proxy.

## Upgrade Notes

OAuth2 Proxy `v7.15.5` keeps the same chart-facing configuration surface as
`v7.15.4`. It fixes authentication bypasses involving ambiguous skip-auth path
matching and untrusted client-IP headers, and prevents callback errors from
exposing credentials. No values change is required for this chart bump.

Review custom `skip_auth_routes` and `skip_auth_regex` expressions before the
upgrade: path matching is intentionally stricter, so ambiguous paths that were
previously skipped may now require authentication. Deployments behind a reverse
proxy must continue to list only the actual proxy CIDRs in
`config.reverseProxy.trustedProxyIps`.

The upstream `--bitbucket-team` option is deprecated. Migrate custom arguments
to `--bitbucket-workspace`; the deprecated option remains available in this
release.

The chart keeps `config.reverseProxy.enabled=false` by default. If you enable
reverse proxy header handling, the chart requires at least one
`config.reverseProxy.trustedProxyIps` CIDR so a missing list cannot fall back to
broad trust.

```yaml
config:
  reverseProxy:
    enabled: true
    trustedProxyIps:
      - 10.42.0.0/16
```

## Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public
  hostnames:
    - auth.example.com
```

## Monitoring

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

## NetworkPolicy

```yaml
networkPolicy:
  enabled: true
  extraEgress: []
```

Use `networkPolicy.extraEgress` to append full custom egress rules without
replacing the chart's generated DNS and HTTP(S) egress defaults.

## Alpha Config

When `alphaConfig.enabled=true`, the chart renders the structured
`alpha-config.yaml` without legacy provider options. The chart enforces
`server.bindAddress` from `containerPorts.http` and `metricsServer.bindAddress`
from `metrics.port`; disabling metrics forces that alpha listener off. Matching
CLI flags are passed to both the config-test init container and runtime.

### Security Scan: oauth2-proxy

| Framework          | Score   |
| ------------------ | ------- |
| MITRE + NSA + SOC2 | **95%** |

Security posture: acceptable.

## Local Validation

```bash
helm lint charts/oauth2-proxy
helm template oauth2-proxy charts/oauth2-proxy -f charts/oauth2-proxy/ci/ci-values.yaml
helm unittest charts/oauth2-proxy
```

## Troubleshooting

- If probes fail, confirm that `containerPorts.http` is not overridden through
  `extraArgs` and inspect the startup log for the effective HTTP address.
- If redirects use the wrong scheme or host, set `config.redirectUrl`; when
  `config.reverseProxy.enabled=true`, restrict `trustedProxyIps` to the actual
  ingress or gateway hops.
- If sign-in loops after a rollout, verify that the cookie Secret remained
  stable and that `config.cookie.secure` matches the external HTTPS boundary.
- If metrics scraping fails, ensure `metrics.enabled=true`, `metrics.port` does
  not collide with the HTTP listener, and the NetworkPolicy admits the scraper.

## Operational Guides

- [Production checklist](docs/production.md)
- [Networking and trusted proxies](docs/networking.md)
- [External Secrets](docs/external-secrets.md)
