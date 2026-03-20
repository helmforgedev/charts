---
title: Vaultwarden - Ingress
description: Ingress and domain config
keywords: [vaultwarden, ingress, domain, tls]
scope: chart-docs
audience: users
---

# Ingress and Domain

## Why it matters

Vaultwarden relies on a correct public domain for features such as attachment links and client-facing URLs.

## Recommended pattern

- set `domain` to the external HTTPS URL
- enable ingress with the same hostname
- terminate TLS at ingress or reverse proxy
- if the public URL includes a path or non-default port, keep that exact external URL in `domain`

## Domain examples

Public hostname:

```yaml
domain: https://vaultwarden.example.com
```

Public hostname with non-default port:

```yaml
domain: https://vaultwarden.example.com:8443
```

Public hostname behind a path:

```yaml
domain: https://example.com/vaultwarden
```

## Example

```yaml
domain: https://vaultwarden.example.com

ingress:
  enabled: true
  ingressClassName: traefik
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    - host: vaultwarden.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - vaultwarden.example.com
      secretName: vaultwarden-tls
```

## WebSocket note

WebSocket notifications use the same HTTP service and ingress path in this chart. No separate websocket service is required in v1.

For most ingress controllers, the normal HTTP ingress path is enough. If operators use aggressive idle timeouts or proxy buffering defaults, they should validate websocket behavior explicitly after deployment.

## Reverse proxy note

Keep `vaultwarden.proxy.ipHeader` aligned with the actual reverse proxy behavior:

- `X-Real-IP` is a common default
- use `X-Forwarded-For` only when that is what your ingress controller actually forwards
- use `none` if you want Vaultwarden to rely only on the direct remote address

<!-- @AI-METADATA
type: chart-docs
title: Vaultwarden - Ingress
description: Ingress and domain config

keywords: vaultwarden, ingress, domain, tls

purpose: Ingress and domain configuration with TLS for Vaultwarden
scope: Chart Architecture

relations:
  - charts/vaultwarden/README.md
path: charts/vaultwarden/docs/ingress-and-domain.md
version: 1.0
date: 2026-03-20
-->
