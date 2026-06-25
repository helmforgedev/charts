# Homarr Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/helmforge)](https://artifacthub.io/packages/search?repo=helmforge)

Helm chart for deploying [Homarr](https://homarr.dev/) modern application dashboard on Kubernetes using the official
[`ghcr.io/homarr-labs/homarr`](https://github.com/homarr-labs/homarr/pkgs/container/homarr) container image.

Current application version: `v1.67.0`.

## Features

- **Official Homarr image** from `ghcr.io/homarr-labs/homarr`
- **Database backends** SQLite3 (default), PostgreSQL, or MySQL with auto-detection
- **PostgreSQL and MySQL subcharts** optional bundled database deployments using HelmForge PostgreSQL `2.0.4` and MySQL `2.0.1`
- **Encryption key management** auto-generated or existing secret for `SECRET_ENCRYPTION_KEY`
- **Kubernetes integration** optional workload discovery via `ENABLE_KUBERNETES`
- **External Redis** optional external Redis for multi-instance setups
- **Persistent storage** application data in `/appdata`
- **S3-compatible backup** database-aware CronJob (SQLite tar, pg_dump, mysqldump)
- **Ingress support** configurable ingress with TLS
- **Gateway API support** optional HTTPRoute for modern Kubernetes ingress controllers
- **Dual-stack ready Service** optional `ipFamilyPolicy` and `ipFamilies`
- **External Secrets Operator** optional projection for the Homarr encryption/auth Secret
- **Chart lock policy** source chart does not commit `Chart.lock`; dependencies are resolved during packaging/validation

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install homarr helmforge/homarr
```

### OCI Registry

```bash
helm install homarr oci://ghcr.io/helmforgedev/helm/homarr
```

## Quick Start

Default installation uses SQLite3 — no external database required:

```bash
helm install homarr helmforge/homarr
```

Access the web UI at `http://<service-ip>:7575` and create your first account.

## Examples

### SQLite with Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: dash.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: homarr-tls
      hosts:
        - dash.example.com
```

### Gateway API HTTPRoute

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: shared-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - dash.example.com
  path: /
  pathType: PathPrefix
```

### External Secrets Operator

```yaml
encryption:
  existingSecret: homarr-encryption
  existingSecretKey: secret-encryption-key

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: secret-encryption-key
      remoteRef:
        key: homarr/credentials
        property: secret-encryption-key
    - secretKey: auth-secret
      remoteRef:
        key: homarr/credentials
        property: auth-secret
```

### PostgreSQL with Kubernetes Integration

```yaml
homarr:
  enableKubernetes: true

postgresql:
  enabled: true
  auth:
    database: homarr
    username: homarr
    password: "db-password"
```

### MySQL Subchart

```yaml
mysql:
  enabled: true
  auth:
    database: homarr
    username: homarr
    password: "db-password"
    rootPassword: "root-password"
```

### External PostgreSQL

```yaml
database:
  mode: external
  external:
    vendor: postgres
    host: postgres.example.com
    port: "5432"
    name: homarr
    username: homarr
    password: "db-password"
```

### External Redis

```yaml
redis:
  external: true
  host: redis.example.com
  port: 6379
```

### S3 Backup

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.example.com
    bucket: homarr-backups
    accessKey: "access-key"
    secretKey: "secret-key"
```

## Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `ghcr.io/homarr-labs/homarr` | Container image repository |
| `image.tag` | `"v1.67.0"` | Homarr image tag |
| `replicaCount` | `1` | Number of replicas |
| `homarr.logLevel` | `info` | Log level |
| `homarr.authProviders` | `credentials` | Auth providers (credentials, ldap, oidc) |
| `homarr.enableDnsCaching` | `false` | Enable Homarr's internal DNS cache. Disabled by default for Kubernetes Service discovery stability |
| `homarr.enableKubernetes` | `false` | Enable K8s workload discovery |
| `encryption.key` | `""` | 32-byte hex encryption key (auto-generated) |
| `encryption.existingSecret` | `""` | Existing secret with encryption key |
| `database.mode` | `auto` | Database mode: auto, sqlite, external, postgresql, mysql |
| `database.sqlite.path` | `/appdata/db/db.sqlite` | SQLite file path |
| `database.external.vendor` | `postgres` | External DB vendor |
| `database.external.host` | `""` | External DB host |
| `database.external.existingSecret` | `""` | Existing secret with external database password |
| `postgresql.enabled` | `false` | Deploy PostgreSQL subchart |
| `postgresql.auth.database` | `homarr` | PostgreSQL database name |
| `postgresql.auth.username` | `homarr` | PostgreSQL username |
| `postgresql.initdb.scripts` | Homarr grants | PostgreSQL bootstrap grants required for Homarr migrations |
| `postgresqlUpgradeJob.enabled` | `true` | Run a pre-upgrade hook that reapplies PostgreSQL grants on existing bundled PostgreSQL PVCs |
| `postgresqlUpgradeJob.requireExistingResources` | `true` | Require an existing bundled PostgreSQL Secret and Service before rendering the pre-upgrade hook |
| `postgresql.standalone.persistence.enabled` | `true` | Enable PostgreSQL persistence |
| `mysql.enabled` | `false` | Deploy MySQL subchart |
| `mysql.auth.database` | `homarr` | MySQL database name |
| `mysql.auth.username` | `homarr` | MySQL username |
| `mysql.standalone.persistence.enabled` | `true` | Enable MySQL persistence |
| `redis.external` | `false` | Use external Redis |
| `redis.host` | `""` | External Redis host |
| `redis.port` | `6379` | External Redis port |
| `persistence.enabled` | `true` | Enable persistent storage |
| `persistence.size` | `1Gi` | Volume size |
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `7575` | Service port |
| `service.ipFamilyPolicy` | `null` | Service IP family policy |
| `service.ipFamilies` | `[]` | Ordered service IP families |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `""` | Ingress class |
| `gateway.enabled` | `false` | Enable Gateway API HTTPRoute |
| `gateway.parentRefs` | `[]` | Parent Gateway references |
| `gateway.hostnames` | `[]` | HTTPRoute hostnames |
| `externalSecrets.enabled` | `false` | Render ExternalSecret for the Homarr encryption/auth Secret |
| `externalSecrets.secretStoreRef.name` | `""` | SecretStore or ClusterSecretStore name |
| `backup.enabled` | `false` | Enable S3 backup CronJob |
| `backup.schedule` | `"0 3 * * *"` | Backup cron schedule |
| `backup.s3.endpoint` | `""` | S3-compatible endpoint URL |
| `backup.s3.bucket` | `""` | S3 bucket name |

## Database Auto-Detection

When `database.mode` is `auto` (default), the chart detects which database to use:

1. If `database.external.host` is set -> **external** database
2. If `postgresql.enabled` is `true` -> **PostgreSQL subchart**
3. If `mysql.enabled` is `true` -> **MySQL subchart**
4. Otherwise -> **SQLite3** (zero configuration)

## Encryption Key

Homarr requires a `SECRET_ENCRYPTION_KEY` for encrypting integration secrets. The chart auto-generates one on first install if not provided. To set your own:

```bash
openssl rand -hex 32
```

Then pass it via `encryption.key` or an existing secret.

## Gateway API

The chart can render a native Kubernetes Gateway API `HTTPRoute` alongside or instead of Ingress. Set
`gateway.enabled=true` and reference an existing shared Gateway with `gateway.parentRefs`. Gateway API CRDs and a
controller such as Envoy Gateway, Cilium, Istio, Traefik, or NGINX Gateway Fabric must be installed separately.

## Dual-Stack Networking

The Service supports Kubernetes dual-stack networking through `service.ipFamilyPolicy` and `service.ipFamilies`. Defaults
omit both fields so existing installs keep the cluster default behavior. Set `service.ipFamilyPolicy=PreferDualStack` for a
portable dual-stack opt-in, or include explicit `ipFamilies` only on clusters that advertise those families.

## External Secrets

Set `externalSecrets.enabled=true` with `encryption.existingSecret` to let External Secrets Operator populate Homarr's
`SECRET_ENCRYPTION_KEY` and `AUTH_SECRET`. The `externalSecrets.data` entries must include `secret-encryption-key` (or the
configured `encryption.existingSecretKey`) and `auth-secret`. The External Secrets Operator and SecretStore are managed
outside this chart.

## Security Defaults

The chart sets resource requests and limits, disables privilege escalation, and applies the `RuntimeDefault` seccomp profile
by default. The official Homarr image configures nginx during startup, so the chart keeps the container root filesystem
writable and does not force a non-root UID or dropped capabilities by default. Override `podSecurityContext` and
`securityContext` only after validating compatible writable mounts for `/etc/nginx` and `/var/lib/nginx`.

## Upgrade Notes

This update moves the default image from `v1.64.0` to `v1.67.0`. Review upstream release notes before upgrading production
environments. Homarr `v1.66.1` fixes the MySQL migration regression introduced in `v1.65.0`, and `v1.67.0` adds
server-side PostHog analytics, total CPU and memory usage display, session cookie isolation, and downloads sorting fixes.
No breaking changes were identified in the upstream release metadata.

For PostgreSQL and MySQL, the chart sets `DB_DIALECT`, `DB_DRIVER`, and discrete database environment variables instead of
rendering a full `DB_URL`; this avoids requiring URL-encoded passwords in Kubernetes Secrets.

The chart sets `ENABLE_DNS_CACHING=false` by default. Homarr documents this setting for DNS/IP edge cases, and k3d
validation showed it avoids transient MySQL connection timeouts when Homarr resolves Kubernetes Services during startup.
Set `homarr.enableDnsCaching=true` only when your cluster DNS behavior is known to be compatible with Homarr's internal
cache.

For bundled PostgreSQL, the default `postgresql.initdb.scripts` grants the `homarr` user ownership and `CREATE` permission on
the `homarr` database for fresh data directories. The `postgresqlUpgradeJob` pre-upgrade hook reapplies those grants before
Homarr starts when an existing bundled PostgreSQL Secret and Service are present. Set
`postgresqlUpgradeJob.requireExistingResources=false` only for controlled migrations where those bundled PostgreSQL resources
are created before the upgrade hook runs. Existing external PostgreSQL databases must provide equivalent permissions before the
first Homarr startup because Homarr creates the `drizzle` schema during migration.

When upgrading from older dependency layouts, move legacy `postgresql.primary.*`
and `mysql.primary.*` overrides to `postgresql.standalone.*` and
`mysql.standalone.*`. The chart fails fast when those legacy blocks are still
present with the corresponding subchart enabled so database persistence settings
are not silently ignored.

After changing database mode or credentials, verify the application pod and selected database backend:

```bash
kubectl get pods -l app.kubernetes.io/instance=<release> -n <namespace>
kubectl logs -l app.kubernetes.io/name=homarr -n <namespace> --all-containers --tail=100
```

## More Information

- [Chart design](DESIGN.md)
- [Database and backup modes](docs/database.md)
- [Homarr documentation](https://homarr.dev/docs)
- [Chart source](https://github.com/helmforgedev/charts/tree/main/charts/homarr)

### Security Scan: `homarr`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **86.580086%** |

> ✅ Security posture acceptable.

<!-- @AI-METADATA
type: chart-readme
title: Homarr Helm Chart
description: Modern application dashboard with SQLite, PostgreSQL, MySQL, Kubernetes integration, and S3 backup

keywords: homarr, dashboard, homepage, self-hosted, kubernetes

purpose: Chart README with install, config, database, encryption, and values reference
scope: Chart

relations:
  - charts/homarr/DESIGN.md
  - charts/homarr/docs/database.md
  - charts/homarr/values.yaml
path: charts/homarr/README.md
version: 1.0
date: 2026-03-31
-->
