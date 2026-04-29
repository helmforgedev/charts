# Production Mode

## When to use it

Use `mode: production` for real reverse-proxy deployments where Keycloak is backed by an external database.

## What it delivers

- external database configuration
- explicit hostname and proxy modeling
- separated management service for health and metrics
- optional separate public and admin ingresses
- optional multi-replica runtime
- optional realm import
- optional providers and themes mounting
- optional Gateway API `HTTPRoute` resources that attach to existing Gateways
- optional External Secrets Operator `ExternalSecret` resources for clusters that already run the operator
- first-class production runtime controls for proxy trust, management path, database pool/schema/timeouts, features, logging, telemetry, and tracing

## What it does not deliver

- bundled production database
- operator-style realm reconciliation
- management ingress exposure

## Best practices

- always configure `hostname.hostname`
- prefer a separate admin hostname when operationally possible
- use a separate admin ingress when the admin console must use a different ingress class or an internal load balancer policy
- keep the management service internal
- document the reverse proxy behavior alongside the chart values
- use multiple replicas only when the shared database and cache expectations are understood
- review [Reverse Proxy and Hostname](reverse-proxy.md) before exposing the chart
- review [Scaling and Clustering](scaling-and-clustering.md) before increasing replica count
- review [Security and Trust](security-and-trust.md) when database TLS or private CAs are involved
- review [Extensions and Themes](extensions-and-themes.md) before mounting providers, themes, or sidecars
- review [Scope and Automation Boundaries](scope-and-automation-boundaries.md) before treating the chart like an operator or autoscaling control plane
- review [Production Capacity](production-capacity.md) before choosing explicit `resources` and `priorityClassName`

## Operational notes

- production mode assumes the reverse proxy is part of the deployment design, not an optional add-on
- the public ingress and the admin ingress both route to the application service only
- the management interface remains internal even when both ingresses are enabled
- a safe production rollout validates hostname resolution, login flow, admin access, and health endpoints together
- external secret and truststore rotation require a controlled rollout plan
- HPA is intentionally not modeled by the current chart scope
- `hostname.admin` must be set when the admin ingress is enabled in production mode
- Gateway API support creates only `HTTPRoute`; platform teams must provide Gateway API CRDs, controller, `GatewayClass`, and `Gateway`
- External Secrets support creates only `ExternalSecret`; platform teams must provide External Secrets Operator and the referenced `SecretStore` or `ClusterSecretStore`
- `serviceAccount.automountServiceAccountToken=false` is available for hardening, but it also prevents Keycloak from seeing the Kubernetes service account CA files used by upstream truststore auto-discovery
- NetworkPolicy egress is disabled by default; enabling it requires explicit DNS, database, S3, telemetry, and other destination rules

## Lifecycle strategy

The default Deployment strategy is:

```yaml
deployment:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
```

Keep readiness probes enabled when using rolling updates. For slower bootstrap profiles, use `probes.profile: heavy-startup` rather than disabling probes.

## Production hardening values

Use the first-class values when the platform contract is known:

```yaml
mode: production

hostname:
  hostname: https://sso.example.com

proxy:
  headers: xforwarded
  trustedAddresses: 10.0.0.0/8

management:
  relativePath: /management

database:
  external:
    host: postgresql.example.com
    password: change-me
    schema: keycloak
    pool:
      initialSize: 2
      minSize: 1
      maxSize: 20
      maxLifetime: 30m
    transaction:
      xaEnabled: "false"
      timeout: 60s

metrics:
  enabled: true
  cacheHistograms: true

logging:
  console:
    output: json
    jsonFormat: ecs
```

Use `optimized.enabled=true` only with a custom image that was built for optimized startup.

## Gateway API

Gateway API support is opt-in:

```yaml
gateway:
  public:
    enabled: true
    parentRefs:
      - name: public-gateway
        namespace: gateway-system
    hostnames:
      - sso.example.com
```

The chart does not create a `Gateway` and never routes the management service through Gateway API.

## External Secrets Operator

External Secrets support is opt-in for clusters that already run https://github.com/external-secrets/external-secrets:

```yaml
externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  admin:
    enabled: true
    usernameRemoteRef:
      key: keycloak/admin
      property: username
    passwordRemoteRef:
      key: keycloak/admin
      property: password
  database:
    enabled: true
    passwordRemoteRef:
      key: keycloak/database
      property: password
```

When an ExternalSecret owns a target Secret, the native generated Secret for that credential is suppressed and Keycloak consumes the materialized Kubernetes Secret.

## Keycloak 26.6.x rollout notes

The default image is `quay.io/keycloak/keycloak:26.6.1`.

Before rolling this version into production:

- read the official 26.6.x release notes
- validate database startup and migration logs
- validate readiness and liveness on the management service
- validate login, token refresh, logout, and admin console access through the real reverse proxy path
- keep `terminationGracePeriodSeconds` and proxy connection draining aligned with the upstream graceful HTTP shutdown behavior
- verify private CA and truststore behavior when running on Kubernetes or OpenShift with internal certificate authorities
- keep a rollback plan that covers image, chart values, database migration expectations, proxy routing, and mounted providers/themes

Official references:

- Keycloak downloads: https://www.keycloak.org/downloads
- Keycloak release notes: https://www.keycloak.org/docs/latest/release_notes/index.html
- Keycloak production configuration: https://www.keycloak.org/server/configuration-production

<!-- @AI-METADATA
type: chart-docs
title: Keycloak - Production Mode
description: Production deployment with database and TLS

keywords: keycloak, production, database, tls

purpose: Production deployment guide for Keycloak with external database and TLS
scope: Chart Architecture

relations:
  - charts/keycloak/README.md
  - charts/keycloak/docs/dev.md
path: charts/keycloak/docs/production.md
version: 1.0
date: 2026-03-20
-->
