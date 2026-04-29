# Keycloak

Keycloak for Kubernetes with explicit `dev` and `production` modes, external database modeling for real deployments, and a clear separation between public traffic and the management interface.

## Install

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install keycloak helmforge/keycloak -f values.yaml
```

### OCI registry

```bash
helm install keycloak oci://ghcr.io/helmforgedev/helm/keycloak -f values.yaml
```

## Supported modes

| Mode | When to use | Document |
|------|-------------|----------|
| `dev` | local testing, bootstrap validation, temporary environments | [docs/dev.md](docs/dev.md) |
| `production` | reverse-proxy deployments with an external database | [docs/production.md](docs/production.md) |

## Architecture guides

- [Production Mode](docs/production.md)
- [Reverse Proxy and Hostname](docs/reverse-proxy.md)
- [Scaling and Clustering](docs/scaling-and-clustering.md)
- [Security and Trust](docs/security-and-trust.md)
- [Extensions and Themes](docs/extensions-and-themes.md)
- [Backup and Restore](docs/backup.md)
- [Scope and Automation Boundaries](docs/scope-and-automation-boundaries.md)
- [Production Capacity](docs/production-capacity.md)

## What this chart covers

- explicit `dev` and `production` runtime modes
- official `quay.io/keycloak/keycloak` image
- bootstrap admin credentials through generated secret or `existingSecret`
- external database as the production path
- explicit hostname and proxy configuration
- separate management service for health and metrics
- optional realm import through `/opt/keycloak/data/import`
- optional provider and theme mounts
- optional separate ingresses for public and admin traffic
- optional Gateway API `HTTPRoute` resources for public and admin traffic
- optional truststore and external database TLS material
- optional External Secrets Operator `ExternalSecret` resources for clusters that already run the operator
- optional IPv4/IPv6 dual-stack Service fields
- optional database-aware S3 backup CronJob for PostgreSQL/MySQL-backed modes
- controlled extension hooks through `extraEnvFrom`, `initContainers`, and `extraContainers`
- optional `ServiceMonitor`
- first-class production options for trusted proxies, management relative path, database pool/schema/timeouts, features, logging, telemetry, and tracing
- rollout strategy, service account token mounting, capacity profiles, and optional egress NetworkPolicy controls

## How to choose the mode

- use `dev` when you need quick startup and disposable local behavior
- use `production` when you need external URLs, reverse proxy correctness, and an external database

Recommended reading before installation:

- [Dev Mode](docs/dev.md)
- [Production Mode](docs/production.md)
- [Reverse Proxy and Hostname](docs/reverse-proxy.md)
- [Scaling and Clustering](docs/scaling-and-clustering.md)
- [Security and Trust](docs/security-and-trust.md)
- [Extensions and Themes](docs/extensions-and-themes.md)
- [Backup and Restore](docs/backup.md)
- [Scope and Automation Boundaries](docs/scope-and-automation-boundaries.md)
- [Production Capacity](docs/production-capacity.md)

## Official product references

- [Keycloak downloads](https://www.keycloak.org/downloads)
- [Keycloak release notes](https://www.keycloak.org/docs/latest/release_notes/index.html)
- [Keycloak production configuration](https://www.keycloak.org/server/configuration-production)
- [Keycloak hostname configuration](https://www.keycloak.org/server/hostname)
- [Keycloak caching and transport stacks](https://www.keycloak.org/server/caching)
- [Keycloak general configuration](https://www.keycloak.org/server/configuration)
- [Keycloak all configuration](https://www.keycloak.org/server/all-config)
- [Kubernetes Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/)
- [External Secrets Operator](https://external-secrets.io/latest/)

## Keycloak 26.6.x alignment

This chart tracks the official Keycloak server image `quay.io/keycloak/keycloak:26.6.1`.

Relevant 26.6.x operational changes to account for during rollout:

- zero-downtime patch releases are supported within the same minor stream, but still require readiness, proxy, and database validation
- the HTTP stack supports graceful shutdown, so keep `terminationGracePeriodSeconds` aligned with connection draining at the proxy layer
- Kubernetes and OpenShift truststore initialization improved upstream; keep custom `truststore` and database CA mounts explicit when the platform uses private CAs
- database operations and timeout behavior changed in the 26.6 stream; validate startup, migration, and failover logs before widening traffic
- `KCRAW_` is available upstream for preserving literal environment values; continue using `extraEnv` for advanced options that are not first-class chart values yet

## Phase 3 production controls

This chart exposes common Keycloak production options as first-class values:

- `proxy.trustedAddresses` maps to `KC_PROXY_TRUSTED_ADDRESSES`
- `proxy.protocolEnabled` maps to `KC_PROXY_PROTOCOL_ENABLED` and cannot be used with `proxy.headers`
- `management.relativePath` maps to `KC_HTTP_MANAGEMENT_RELATIVE_PATH` and updates probes and ServiceMonitor paths
- `database.external.schema`, `database.external.pool.*`, `database.external.logSlowQueriesThreshold`, and `database.external.transaction.*` map to Keycloak database runtime settings
- `features.enabled` and `features.disabled` map to `KC_FEATURES` and `KC_FEATURES_DISABLED`
- `optimized.enabled` adds `--optimized` for custom pre-built production images
- `metrics.userEvents`, `metrics.cacheHistograms`, `telemetry.*`, `tracing.*`, and `logging.*` map to Keycloak observability settings
- `deployment.strategy.*` controls Kubernetes rollout behavior
- `serviceAccount.automountServiceAccountToken` controls whether Kubernetes mounts the service account token and cluster CA files
- `truststore.kubernetes.enabled` maps to `KC_TRUSTSTORE_KUBERNETES_ENABLED`
- `capacity.profile` can render conservative `small`, `medium`, or `large` resource presets when `resources` is not set

Gateway API support is optional and renders only `HTTPRoute` resources. The chart does not create `GatewayClass` or `Gateway` resources.

External Secrets support is optional and intended only for clusters that already have External Secrets Operator and a
`SecretStore` or `ClusterSecretStore`. The chart renders `ExternalSecret` resources that materialize the Kubernetes
Secrets consumed by the existing `admin`, `database`, and `truststore` paths; it does not install the operator or create
provider stores.

## Operational direction

- `production` is the normal path for real environments
- production expects a reverse proxy or ingress in front of Keycloak
- the management interface is kept separate and must not be exposed through the public or admin ingress
- multi-replica runtime is supported, but it must be treated as a cache/discovery concern and not just a Deployment scaling flag

## Quick start

Minimal local example:

```yaml
mode: dev
```

Production with external database:

```yaml
mode: production

hostname:
  hostname: https://sso.example.com

database:
  external:
    vendor: postgres
    host: postgresql-rw.default.svc
    name: keycloak
    username: keycloak
    existingSecret: keycloak-db
```

Production with PostgreSQL subchart:

```yaml
mode: production

hostname:
  hostname: https://sso.example.com

postgresql:
  enabled: true
  auth:
    database: keycloak
    username: keycloak
    password: change-me
```

Dev with PostgreSQL subchart:

```yaml
mode: dev

postgresql:
  enabled: true
  auth:
    database: keycloak
    username: keycloak
    password: devpassword
```

## Best practices

### Security

- use `mode: production` for all real environments
- prefer `admin.existingSecret` and `database.external.existingSecret`
- keep the management service internal
- restrict admin exposure at the reverse proxy layer when using a dedicated admin hostname
- use [Security and Trust](docs/security-and-trust.md) when database TLS or custom internal CAs are involved
- if `ingress.admin.enabled=true`, always set `hostname.admin` explicitly

### Reverse proxy and hostname

- always set `hostname.hostname` in production mode
- set `hostname.admin` when the admin console should live on a separate host
- align `proxy.headers` with your ingress or reverse proxy behavior
- use the public ingress for user-facing traffic and a separate admin ingress when the admin console should sit behind a different ingress class or internal load balancer
- review [Reverse Proxy and Hostname](docs/reverse-proxy.md) before exposing the chart publicly

### Database and runtime

- treat the external database as part of the critical-path design
- prefer PostgreSQL for production examples and guidance
- enable built-in backup only when the release uses PostgreSQL, MySQL, or MariaDB instead of embedded H2
- do not use `dev` mode as a hidden production shortcut
- review [Scaling and Clustering](docs/scaling-and-clustering.md) before raising `replicaCount`
- review [Scope and Automation Boundaries](docs/scope-and-automation-boundaries.md) before asking the chart to solve autoscaling or operator-style concerns
- review [Production Capacity](docs/production-capacity.md) before choosing explicit `resources` and `priorityClassName`

### Realm import and extensions

- use realm import for bootstrap and lower-environment seeding
- do not treat startup import as a full reconciliation control plane
- mount providers and themes explicitly so restart behavior stays predictable
- review [Extensions and Themes](docs/extensions-and-themes.md) before adding providers, themes, or sidecars

## Production notes

- production mode fails fast when hostname or database configuration is missing
- management health and metrics stay on the management service
- public and admin ingresses both route only to the application service
- the admin ingress exists to separate exposure policy, hostname, and ingress class from the public ingress
- if `replicaCount > 1`, keep cache and cluster expectations explicit in the deployment plan
- if `replicaCount > 1` and no custom scheduling is set, the chart applies soft pod anti-affinity and topology spread defaults
- prefer separate public and admin hostnames when the admin console needs tighter exposure rules
- keep sticky-session behavior aligned with the ingress controller in front of Keycloak
- treat `jdbc-ping` as discovery and cache transport plumbing, not as a substitute for a Keycloak operator
- plan image rollouts and rollbacks together with the external database and reverse-proxy layer
- generated admin and database secrets trigger rollout on Helm upgrades
- built-in backup targets the selected Keycloak database and uploads the compressed dump to S3-compatible storage
- externally managed secret or truststore changes still require an explicit rollout or restart
- provider and theme source changes can be rolled forward predictably with `rolloutToken`
- HPA remains intentionally out of scope as a built-in feature for the current chart scope
- `ingress.admin.enabled=true` requires `hostname.admin` in production mode
- `probes.profile=heavy-startup` is available for slower bootstrap profiles with heavier providers or themes

## Main values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mode` | `dev` or `production` | `dev` |
| `image.repository` | Keycloak image repository | `quay.io/keycloak/keycloak` |
| `image.tag` | Keycloak image tag | `26.6.1` |
| `admin.existingSecret` | Existing secret for bootstrap admin credentials | `""` |
| `http.port` | Application HTTP port | `8080` |
| `http.managementPort` | Management port for health and metrics | `9000` |
| `http.relativePath` | Relative HTTP path | `/` |
| `management.relativePath` | Optional management relative path | `""` |
| `deployment.strategy.type` | Deployment strategy | `RollingUpdate` |
| `deployment.strategy.rollingUpdate.maxUnavailable` | Max unavailable pods during rollout | `0` |
| `deployment.strategy.rollingUpdate.maxSurge` | Max surge pods during rollout | `1` |
| `hostname.hostname` | Public hostname or URL | `""` |
| `hostname.admin` | Dedicated admin hostname or URL | `""` |
| `proxy.headers` | Proxy headers mode | `xforwarded` |
| `proxy.trustedAddresses` | Trusted proxy IPs/CIDRs | `""` |
| `proxy.protocolEnabled` | Enable HAProxy PROXY protocol | `false` |
| `database.external.vendor` | External database vendor | `postgres` |
| `database.external.host` | External database host | `""` |
| `database.external.name` | External database name | `keycloak` |
| `database.external.username` | External database username | `keycloak` |
| `database.external.existingSecret` | Existing secret for database password | `""` |
| `database.external.schema` | Database schema | `""` |
| `database.external.pool.maxSize` | Maximum database pool size | `""` |
| `database.tls.enabled` | Enable database TLS settings | `false` |
| `database.tls.mode` | Keycloak database TLS mode | `""` |
| `database.tls.sslMode` | PostgreSQL SSL mode | `verify-full` |
| `database.tls.existingSecret` | Secret with database CA material | `""` |
| `database.tls.existingConfigMap` | ConfigMap with database CA material | `""` |
| `features.enabled` | Keycloak features to enable | `[]` |
| `optimized.enabled` | Add `--optimized` startup arg | `false` |
| `backup.enabled` | Enable built-in S3 backup CronJob for database-backed modes | `false` |
| `backup.schedule` | Backup schedule | `"0 3 * * *"` |
| `backup.s3.endpoint` | S3-compatible endpoint URL | `""` |
| `backup.s3.bucket` | Target bucket name | `""` |
| `postgresql.enabled` | Enable PostgreSQL subchart | `false` |
| `postgresql.auth.database` | Subchart database name | `keycloak` |
| `postgresql.auth.username` | Subchart database username | `keycloak` |
| `postgresql.auth.password` | Subchart database password | `""` |
| `mysql.enabled` | Enable MySQL subchart | `false` |
| `mysql.auth.database` | Subchart database name | `keycloak` |
| `mysql.auth.username` | Subchart database username | `keycloak` |
| `mysql.auth.password` | Subchart database password | `""` |
| `truststore.enabled` | Enable additional truststore paths | `false` |
| `truststore.existingSecret` | Secret with PEM or PKCS12 trust material | `""` |
| `truststore.existingConfigMap` | ConfigMap with PEM or PKCS12 trust material | `""` |
| `truststore.tlsHostnameVerifier` | Outbound TLS hostname verification mode | `DEFAULT` |
| `truststore.kubernetes.enabled` | Trust Kubernetes/OpenShift service account CAs when mounted | `true` |
| `replicaCount` | Number of Keycloak replicas | `1` |
| `cache.stack` | Cache stack for multi-replica production | `jdbc-ping` |
| `cache.multiReplicaDefaults.enabled` | Apply default scheduling hints for multi-replica workloads | `true` |
| `cache.multiReplicaDefaults.podAntiAffinity` | Generated pod anti-affinity mode | `preferred` |
| `resources` | Explicit CPU and memory requests/limits for the main container | `{}` |
| `capacity.profile` | Resource preset: `custom`, `small`, `medium`, `large` | `custom` |
| `serviceAccount.automountServiceAccountToken` | Mount Kubernetes service account token into the pod | `true` |
| `probes.liveness.enabled` | Enable liveness probe | `true` |
| `probes.readiness.enabled` | Enable readiness probe | `true` |
| `probes.startup.enabled` | Enable startup probe | `true` |
| `probes.profile` | Probe timing profile | `default` |
| `extensions.providers.rolloutToken` | Manual rollout token for provider source changes | `""` |
| `extensions.themes.rolloutToken` | Manual rollout token for theme source changes | `""` |
| `extraEnvFrom` | Extra envFrom sources injected into the main container | `[]` |
| `initContainers` | Additional init containers | `[]` |
| `extraContainers` | Additional sidecars or helper containers | `[]` |
| `realmImport.enabled` | Enable startup realm import | `false` |
| `ingress.public.enabled` | Enable public ingress for Keycloak | `false` |
| `ingress.public.ingressClassName` | Public ingress class name | `traefik` |
| `ingress.admin.enabled` | Enable separate admin ingress | `false` |
| `ingress.admin.ingressClassName` | Admin ingress class name | `traefik` |
| `gateway.public.enabled` | Enable public Gateway API HTTPRoute | `false` |
| `gateway.admin.enabled` | Enable admin Gateway API HTTPRoute | `false` |
| `metrics.enabled` | Enable Keycloak metrics | `false` |
| `metrics.userEvents` | Enable user event metrics | `false` |
| `metrics.serviceMonitor.enabled` | Enable ServiceMonitor | `false` |
| `telemetry.metricsEnabled` | Enable OpenTelemetry metrics export | `false` |
| `tracing.enabled` | Enable tracing | `false` |
| `logging.access.enabled` | Enable HTTP access logs | `false` |
| `externalSecrets.enabled` | Render ExternalSecret resources for existing ESO installs | `false` |
| `networkPolicy.enabled` | Enable NetworkPolicy | `false` |
| `networkPolicy.egress.enabled` | Add egress NetworkPolicy rules | `false` |

## CI scenarios

The `ci/` scenarios validate the main chart behaviors:

- `minimal.yaml`
- `external-db.yaml`
- `realm-import.yaml`
- `ingress.yaml`
- `metrics.yaml`
- `multi-replica.yaml`
- `relative-path.yaml`
- `database-tls.yaml`
- `dual-stack-values.yaml`
- `gateway-api.yaml`
- `external-secrets.yaml`
- `production-hardening.yaml`
- `lifecycle-security.yaml`
- `networkpolicy-egress.yaml`
- `multi-replica-observability.yaml`
- `extensions.yaml`
- `heavy-startup.yaml`
- `production-capacity.yaml`

## Rollout guidance

- treat image updates and chart updates as production changes that require a rollback plan
- test ingress, hostname, and relative path behavior together after every rollout
- if providers or themes are mounted, confirm compatibility against the target Keycloak version before rolling out
- when running multiple replicas, roll out behind a stable reverse proxy and validate cluster convergence before widening traffic

## Examples

See `examples/`:

- `minimal.yaml`
- `external-db-ha.yaml`
- `multi-replica-production.yaml`
- `extensions-and-themes.yaml`
- `heavy-startup.yaml`
- `production-capacity.yaml`
- `realm-import.yaml`
- `relative-path.yaml`
- `postgres-tls.yaml`

<!-- @AI-METADATA
type: chart-readme
title: Keycloak Helm Chart
description: Keycloak IAM chart with dev/production modes, clustering, ingress

keywords: keycloak, iam, sso, oidc, authentication, identity

purpose: Usage guide for the Keycloak Helm chart with dev/production modes and clustering
scope: Chart

relations:
  - charts/keycloak/DESIGN.md
  - charts/keycloak/docs/production.md
  - charts/keycloak/docs/dev.md
  - charts/keycloak/docs/scaling-and-clustering.md
path: charts/keycloak/README.md
version: 1.0
date: 2026-03-31
-->
