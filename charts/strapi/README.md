# Strapi Helm Chart

Deploy [Strapi](https://strapi.io/) on Kubernetes as a headless CMS for APIs, websites, and custom admin experiences.

This chart is designed for a prebuilt Strapi project image. It does not build application source code inside the cluster.

## Features

- **SQLite by default** for simple environments
- **PostgreSQL subchart** bundled via HelmForge dependency
- **MySQL subchart** bundled via HelmForge dependency
- **External database** support for existing PostgreSQL or MySQL
- **Application secrets** auto-generated and preserved across upgrades
- **Uploads persistence** using a single PVC with dedicated subpaths
- **Scheduled backups** for SQLite or database dump workflows with S3 upload
- **Ingress support** with `ingressClassName` and TLS

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install strapi helmforge/strapi
```

**OCI registry:**

```bash
helm install strapi oci://ghcr.io/helmforgedev/helm/strapi
```

## Basic Example (SQLite)

```yaml
# values.yaml
image:
  repository: ghcr.io/example/my-strapi
  tag: "1.0.0"

persistence:
  enabled: true
  size: 5Gi
```

## PostgreSQL Example

```yaml
image:
  repository: ghcr.io/example/my-strapi
  tag: "1.0.0"

postgresql:
  enabled: true
  auth:
    database: strapi
    username: strapi
    password: "strong-password"

ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: cms.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: strapi-tls
      hosts:
        - cms.example.com
```

## External Database Example

```yaml
image:
  repository: ghcr.io/example/my-strapi
  tag: "1.0.0"

database:
  external:
    vendor: postgres
    host: db.example.com
    name: strapi
    username: strapi
    existingSecret: strapi-db-credentials
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `vshadbolt/strapi` | Container image for the Strapi project |
| `strapi.url` | `""` | Public URL (auto-detected from ingress if empty) |
| `strapi.port` | `1337` | Container port |
| `strapi.telemetryDisabled` | `true` | Disable telemetry |
| `database.mode` | `auto` | Database mode (auto, sqlite, external, postgresql, mysql) |
| `database.sqlite.directory` | `/opt/app/.tmp` | SQLite directory |
| `database.sqlite.filename` | `data.db` | SQLite filename |
| `database.external.vendor` | `postgres` | External DB vendor (postgres, mysql) |
| `database.external.host` | `""` | External DB host |
| `postgresql.enabled` | `false` | Deploy PostgreSQL subchart |
| `mysql.enabled` | `false` | Deploy MySQL subchart |
| `persistence.enabled` | `true` | Enable uploads and SQLite persistence |
| `persistence.size` | `5Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `backup.enabled` | `false` | Enable S3 backups |
| `secrets.existingSecret` | `""` | Use an existing secret for Strapi app secrets |

## Resources Generated

| Resource | Condition |
|----------|-----------|
| Deployment | Always |
| Service | Always |
| Secret (app) | `secrets.existingSecret` is empty |
| Secret (database) | Database mode is not sqlite and no existing secret |
| Secret (backup) | `backup.enabled` and no `backup.s3.existingSecret` |
| PVC | `persistence.enabled` and no `persistence.existingClaim` |
| Ingress | `ingress.enabled` |
| ServiceAccount | `serviceAccount.create` |
| CronJob (backup) | `backup.enabled` |
| ConfigMap (backup scripts) | `backup.enabled` |

## Notes

- The default image is `vshadbolt/strapi`, pinned to the chart `appVersion`. Override it if your deployment uses a custom Strapi build.
- SQLite is supported for simple deployments, but server-based databases are recommended for production workloads.
- Horizontal scaling is intentionally out of scope for this v1 chart because default local uploads persistence is single-writer oriented.
- For ingress, set `ingress.ingressClassName` to the class used in your cluster, such as `traefik`, `nginx`, or another supported controller.

## More Information

- [Database configuration](docs/database.md)
- [Backup and restore](docs/backup.md)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/strapi)

<!-- @AI-METADATA
type: chart-readme
title: Strapi Helm Chart
description: Helm chart for deploying Strapi headless CMS on Kubernetes

keywords: strapi, headless-cms, cms, nodejs, helm, kubernetes

purpose: User-facing chart documentation with install, features, examples, and values reference
scope: Chart

relations:
  - charts/strapi/values.yaml
  - charts/strapi/docs/database.md
  - charts/strapi/docs/backup.md
path: charts/strapi/README.md
version: 1.0
date: 2026-03-29
-->
