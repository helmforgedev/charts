# Homarr Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/helmforge)](https://artifacthub.io/packages/search?repo=helmforge)

Helm chart for deploying [Homarr](https://homarr.dev/) modern application dashboard on Kubernetes using the official
[`ghcr.io/homarr-labs/homarr`](https://github.com/homarr-labs/homarr/pkgs/container/homarr) container image.

Current application version: `v1.60.0`.

## Features

- **Official Homarr image** from `ghcr.io/homarr-labs/homarr`
- **Database backends** SQLite3 (default), PostgreSQL, or MySQL with auto-detection
- **PostgreSQL and MySQL subcharts** optional bundled database deployments using HelmForge PostgreSQL `1.10.0` and MySQL `1.9.1`
- **Encryption key management** auto-generated or existing secret for `SECRET_ENCRYPTION_KEY`
- **Kubernetes integration** optional workload discovery via `ENABLE_KUBERNETES`
- **External Redis** optional external Redis for multi-instance setups
- **Persistent storage** application data in `/appdata`
- **S3-compatible backup** database-aware CronJob (SQLite tar, pg_dump, mysqldump)
- **Ingress support** configurable ingress with TLS
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
| `image.tag` | `"v1.60.0"` | Homarr image tag |
| `replicaCount` | `1` | Number of replicas |
| `homarr.logLevel` | `info` | Log level |
| `homarr.authProviders` | `credentials` | Auth providers (credentials, ldap, oidc) |
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
| `postgresql.primary.persistence.enabled` | `true` | Enable PostgreSQL persistence |
| `mysql.enabled` | `false` | Deploy MySQL subchart |
| `mysql.auth.database` | `homarr` | MySQL database name |
| `mysql.auth.username` | `homarr` | MySQL username |
| `mysql.primary.persistence.enabled` | `true` | Enable MySQL persistence |
| `redis.external` | `false` | Use external Redis |
| `redis.host` | `""` | External Redis host |
| `redis.port` | `6379` | External Redis port |
| `persistence.enabled` | `true` | Enable persistent storage |
| `persistence.size` | `1Gi` | Volume size |
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `7575` | Service port |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `""` | Ingress class |
| `backup.enabled` | `false` | Enable S3 backup CronJob |
| `backup.schedule` | `"0 3 * * *"` | Backup cron schedule |
| `backup.s3.endpoint` | `""` | S3-compatible endpoint URL |
| `backup.s3.bucket` | `""` | S3 bucket name |

## Database Auto-Detection

When `database.mode` is `auto` (default), the chart detects which database to use:

1. If `database.external.host` is set → **external** database
2. If `postgresql.enabled` is `true` → **PostgreSQL subchart**
3. If `mysql.enabled` is `true` → **MySQL subchart**
4. Otherwise → **SQLite3** (zero configuration)

## Encryption Key

Homarr requires a `SECRET_ENCRYPTION_KEY` for encrypting integration secrets. The chart auto-generates one on first install if not provided. To set your own:

```bash
openssl rand -hex 32
```

Then pass it via `encryption.key` or an existing secret.

## Upgrade Notes

This update moves the default image from `v1.57.1` to `v1.60.0`. Review upstream release notes before upgrading production
environments. Homarr `v1.60.0` includes scheduler, OpenAPI documentation and icon updater fixes, with no breaking changes
identified in the upstream release metadata.

For PostgreSQL and MySQL, the chart sets `DB_DIALECT`, `DB_DRIVER`, `DB_URL`, and the discrete database environment variables
so Homarr runs the correct database migrations during startup.

For bundled PostgreSQL, the default `postgresql.initdb.scripts` grants the `homarr` user ownership and `CREATE` permission on
the `homarr` database. Existing external PostgreSQL databases must provide equivalent permissions before the first Homarr
startup because Homarr creates the `drizzle` schema during migration.

After changing database mode or credentials, verify the application pod and selected database backend:

```bash
kubectl get pods -l app.kubernetes.io/instance=<release> -n <namespace>
kubectl logs -l app.kubernetes.io/name=homarr -n <namespace> --all-containers --tail=100
```

## More Information

- [Homarr documentation](https://homarr.dev/docs)
- [Chart source](https://github.com/helmforgedev/charts/tree/main/charts/homarr)

<!-- @AI-METADATA
type: chart-readme
title: Homarr Helm Chart
description: Modern application dashboard with SQLite, PostgreSQL, MySQL, Kubernetes integration, and S3 backup

keywords: homarr, dashboard, homepage, self-hosted, kubernetes

purpose: Chart README with install, config, database, encryption, and values reference
scope: Chart

relations:
  - charts/homarr/values.yaml
path: charts/homarr/README.md
version: 1.0
date: 2026-03-31
-->
