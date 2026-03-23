# Apache Answer Helm Chart

Deploy [Apache Answer](https://answer.apache.org/) on Kubernetes — an open-source Q&A platform for teams and communities.

## Features

- **SQLite by default** — zero database configuration needed
- **PostgreSQL subchart** — bundled via HelmForge dependency
- **MySQL subchart** — bundled via HelmForge dependency
- **External database** — connect to existing PostgreSQL or MySQL
- **Auto-install** — unattended setup via environment variables
- **Scheduled backups** — database-aware CronJob with S3 upload
- **Ingress support** — TLS with cert-manager
- **Persistence** — PVC for `/data` (uploads, config, SQLite)

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install answer helmforge/answer
```

**OCI registry:**

```bash
helm install answer oci://ghcr.io/helmforgedev/helm/answer
```

## Basic Example (SQLite)

```yaml
# values.yaml
answer:
  siteName: "My Q&A"

admin:
  name: admin
  password: "change-me"

persistence:
  enabled: true
  size: 5Gi
```

## PostgreSQL Example

```yaml
postgresql:
  enabled: true
  auth:
    database: answer
    username: answer
    password: "strong-password"

ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: qa.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: answer-tls
      hosts:
        - qa.example.com
```

## External Database Example

```yaml
database:
  external:
    vendor: postgres
    host: db.example.com
    name: answer
    username: answer
    existingSecret: answer-db-credentials
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `answer.siteName` | `Apache Answer` | Site name |
| `answer.siteUrl` | `""` | Full external URL (auto-detected from ingress) |
| `answer.language` | `en-US` | Default UI language |
| `answer.autoInstall` | `true` | Enable unattended setup |
| `answer.logLevel` | `INFO` | Log level (DEBUG, INFO, WARN, ERROR) |
| `admin.name` | `admin` | Admin username |
| `admin.password` | `""` | Admin password (auto-generated) |
| `admin.email` | `admin@example.com` | Admin email |
| `database.mode` | `auto` | Database mode (auto, sqlite, external, postgresql, mysql) |
| `database.sqlite.file` | `/data/answer.db` | SQLite file path |
| `database.external.vendor` | `postgres` | External DB vendor (postgres, mysql) |
| `database.external.host` | `""` | External DB host |
| `postgresql.enabled` | `false` | Deploy PostgreSQL subchart |
| `mysql.enabled` | `false` | Deploy MySQL subchart |
| `persistence.enabled` | `true` | Enable persistent storage |
| `persistence.size` | `5Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `backup.enabled` | `false` | Enable S3 backups |
| `backup.schedule` | `0 3 * * *` | Backup cron schedule |

## Resources Generated

| Resource | Condition |
|----------|-----------|
| Deployment | Always |
| Service | Always |
| Secret (admin) | `admin.existingSecret` is empty |
| Secret (database) | Database mode is not sqlite and no existing secret |
| Secret (backup) | `backup.enabled` and no `backup.s3.existingSecret` |
| PVC | `persistence.enabled` and no `persistence.existingClaim` |
| Ingress | `ingress.enabled` |
| ServiceAccount | `serviceAccount.create` |
| CronJob (backup) | `backup.enabled` |
| ConfigMap (backup scripts) | `backup.enabled` |

## More Information

- [Database configuration](docs/database.md)
- [Backup and restore](docs/backup.md)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/answer)

<!-- @AI-METADATA
type: chart-readme
title: Apache Answer Helm Chart
description: Helm chart for deploying Apache Answer Q&A platform on Kubernetes

keywords: answer, apache-answer, qa, forum, knowledge-base, helm, kubernetes

purpose: User-facing chart documentation with install, features, examples, and values reference
scope: Chart

relations:
  - charts/answer/values.yaml
  - charts/answer/docs/database.md
  - charts/answer/docs/backup.md
path: charts/answer/README.md
version: 1.0
date: 2026-03-23
-->
