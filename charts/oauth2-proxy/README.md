# OAuth2 Proxy Helm Chart

OAuth2 Proxy is a reverse proxy and authentication gateway for OAuth2 and OIDC
providers. This HelmForge chart deploys the official upstream image with secure
Kubernetes defaults, Gateway API support, ExternalSecret integration, metrics,
and runtime validation.

## Highlights

- Official `quay.io/oauth2-proxy/oauth2-proxy` image.
- `v7.15.2` default, including the upstream security fixes for critical
  authentication bypass advisories.
- Reverse proxy header trust disabled by default, with required explicit
  `trusted_proxy_ips` CIDRs when enabled behind ingress controllers, gateways,
  or service mesh edge proxies.
- Chart-managed Secret, existing Secret, or ExternalSecret credential modes.
- Config validation init container using `--config-test`.
- Dual-stack Service defaults, Ingress with `ingressClassName`, Gateway API `HTTPRoute`, ServiceMonitor,
  HPA, PDB, and optional NetworkPolicy.

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

## Reverse Proxy Hardening

OAuth2 Proxy `v7.15.2` introduced `trusted_proxy_ips` to prevent trusting
client-supplied `X-Forwarded-*` headers from untrusted sources. Keep this list
narrow and aligned with the IP ranges used by your ingress controller, Gateway
implementation, or edge proxy.

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

## Alpha Config

When `alphaConfig.enabled=true`, the chart renders the structured
`alpha-config.yaml` without the legacy TOML file. To keep Kubernetes probes,
Service traffic, and metrics reachable, the chart injects
`server.bindAddress: 0.0.0.0:4180` and `metricsServer.bindAddress` when those
fields are not set explicitly.

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
