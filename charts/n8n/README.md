# n8n Helm Chart

Deploy [n8n](https://n8n.io/) on Kubernetes — a workflow automation platform for technical teams.

## Features

- **SQLite by default** — zero database configuration needed
- **PostgreSQL subchart** — bundled via HelmForge dependency
- **MySQL subchart** — bundled via HelmForge dependency
- **External database** — connect to existing PostgreSQL or MySQL
- **Queue mode** — Redis-backed horizontal scaling with worker pods
- **Redis subchart** — bundled via HelmForge dependency for queue mode
- **Scheduled backups** — database-aware CronJob with S3 upload
- **Ingress support** — TLS with cert-manager, auto-detected webhook URL
- **Encryption key** — auto-generated and persisted across upgrades

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install n8n helmforge/n8n
```

**OCI registry:**

```bash
helm install n8n oci://ghcr.io/helmforgedev/helm/n8n
```

## Basic Example (SQLite)

```yaml
# values.yaml
persistence:
  enabled: true
  size: 5Gi
```

## PostgreSQL + Queue Mode Example

```yaml
postgresql:
  enabled: true
  auth:
    database: n8n
    username: n8n
    password: "strong-password"

queue:
  enabled: true
  workers: 2

redis:
  enabled: true
  auth:
    password: "redis-password"

ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: n8n.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: n8n-tls
      hosts:
        - n8n.example.com
```

## External Database Example

```yaml
database:
  external:
    vendor: postgres
    host: db.example.com
    name: n8n
    username: n8n
    existingSecret: n8n-db-credentials
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `n8n.encryptionKey` | `""` | Encryption key for credentials (auto-generated) |
| `n8n.webhookUrl` | `""` | Webhook URL (auto-detected from ingress) |
| `n8n.logLevel` | `info` | Log level (info, warn, error, debug) |
| `database.mode` | `auto` | Database mode (auto, sqlite, external, postgresql, mysql) |
| `postgresql.enabled` | `false` | Deploy PostgreSQL subchart |
| `mysql.enabled` | `false` | Deploy MySQL subchart |
| `queue.enabled` | `false` | Enable queue mode (requires Redis) |
| `queue.workers` | `1` | Number of worker replicas |
| `queue.concurrency` | `10` | Concurrent workflows per worker |
| `redis.enabled` | `false` | Deploy Redis subchart |
| `persistence.enabled` | `true` | Enable persistent storage |
| `persistence.size` | `5Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `backup.enabled` | `false` | Enable S3 backups |

## Resources Generated

| Resource | Condition |
|----------|-----------|
| Deployment (main) | Always |
| Deployment (worker) | `queue.enabled` |
| Service | Always |
| Secret (encryption) | `encryptionKey.existingSecret` is empty |
| Secret (database) | Database mode is not sqlite and no existing secret |
| Secret (redis) | `queue.enabled` with Redis password configured |
| Secret (backup) | `backup.enabled` and no `backup.s3.existingSecret` |
| PVC | `persistence.enabled` and no `persistence.existingClaim` |
| Ingress | `ingress.enabled` |
| ServiceAccount | `serviceAccount.create` |
| CronJob (backup) | `backup.enabled` |
| ConfigMap (backup scripts) | `backup.enabled` |

## More Information

- [Database configuration](docs/database.md)
- [Queue mode](docs/queue-mode.md)
- [Backup and restore](docs/backup.md)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/n8n)

<!-- @AI-METADATA
type: chart-readme
title: n8n Helm Chart
description: Helm chart for deploying n8n workflow automation platform on Kubernetes

keywords: n8n, workflow, automation, integration, helm, kubernetes, queue, redis

purpose: User-facing chart documentation with install, features, examples, and values reference
scope: Chart

relations:
  - charts/n8n/values.yaml
  - charts/n8n/docs/database.md
  - charts/n8n/docs/queue-mode.md
  - charts/n8n/docs/backup.md
path: charts/n8n/README.md
version: 1.0
date: 2026-03-23
-->
