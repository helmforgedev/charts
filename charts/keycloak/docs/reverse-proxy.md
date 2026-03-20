---
title: Keycloak - Reverse Proxy
description: Reverse proxy and ingress config
keywords: [keycloak, reverse-proxy, ingress]
scope: chart-docs
audience: users
---

# Reverse Proxy and Hostname

## When to read this

Read this guide before exposing Keycloak through an ingress controller, API gateway, or reverse proxy.

## What this chart expects

- `mode: production`
- an explicit public hostname in `hostname.hostname`
- a reverse proxy or ingress in front of Keycloak
- the management interface kept internal on port `9000`

## Public and admin traffic

The chart supports two separate ingresses:

- `ingress.public` for user-facing traffic
- `ingress.admin` for the admin console and admin endpoints

This separation is useful when:

- the admin console must use a different `ingressClassName`
- the admin console should sit behind an internal load balancer
- the organization applies different WAF, IP allowlist, or authentication rules to admin traffic

Both ingresses still route only to the application service. They do not expose the management interface.

## Hostname model

Use these values together:

- `hostname.hostname`
- `hostname.admin`
- `proxy.headers`
- `http.relativePath`

Recommended production pattern:

```yaml
mode: production

hostname:
  hostname: https://sso.example.com
  admin: https://admin-sso.example.com

proxy:
  headers: xforwarded
```

## Ingress guidance

Public ingress example:

```yaml
ingress:
  public:
    enabled: true
    ingressClassName: traefik
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt
    hosts:
      - host: sso.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - hosts:
          - sso.example.com
        secretName: keycloak-tls
```

Admin ingress example:

```yaml
ingress:
  admin:
    enabled: true
    ingressClassName: internal-nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-internal
    hosts:
      - host: admin-sso.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - hosts:
          - admin-sso.example.com
        secretName: keycloak-admin-tls
```

## Sticky sessions

Sticky sessions are often useful for Keycloak, especially during login-heavy workloads and multi-step browser flows.

The chart does not force sticky-session annotations because the implementation depends on the ingress controller in front of Keycloak. Configure session affinity at the ingress or gateway layer used in the environment.

Examples:

- Traefik: cookie-based stickiness on the service or ingress route layer
- NGINX Ingress: cookie affinity annotations
- cloud load balancers or API gateways: platform-specific persistence settings

Treat sticky sessions as a reverse-proxy responsibility, not as an application-service toggle.

## Relative path

If Keycloak must live below a path prefix, configure `http.relativePath` and align the ingress path with it.

Example:

```yaml
http:
  relativePath: /auth

ingress:
  public:
    hosts:
      - host: sso.example.com
        paths:
          - path: /auth
            pathType: Prefix
```

Do not change the relative path in production without validating discovery documents, redirect URIs, and upstream clients.

## Rollout checklist

- verify public hostname resolves to the intended ingress
- verify admin hostname resolves only through the intended admin exposure path
- verify TLS certificates are mounted and valid at both hostnames
- verify login, logout, and admin console flows after rollout
- verify readiness and liveness endpoints through the management service, not through ingress

## Official product references

- Keycloak production configuration: https://www.keycloak.org/server/configuration-production
- Keycloak hostname configuration: https://www.keycloak.org/server/hostname

<!-- @AI-METADATA
type: chart-docs
title: Keycloak - Reverse Proxy
description: Reverse proxy and ingress config

keywords: keycloak, reverse-proxy, ingress

purpose: Reverse proxy and ingress configuration guide for Keycloak
scope: Chart Architecture

relations:
  - charts/keycloak/README.md
  - charts/keycloak/docs/security-and-trust.md
path: charts/keycloak/docs/reverse-proxy.md
version: 1.0
date: 2026-03-20
-->
