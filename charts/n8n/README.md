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
- **Gateway API** — HTTPRoute for clusters running Envoy Gateway or similar
- **Dual-stack networking** — IPv4/IPv6 service support
- **External Secrets Operator** — ExternalSecret for Vault, AWS Secrets Manager, and more

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

## Dual-Stack Service

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

## Gateway API (HTTPRoute)

Requires Gateway API CRDs and a compatible controller (e.g. Envoy Gateway).

```yaml
gateway:
  enabled: true
  gatewayName: envoy-gateway
  gatewayNamespace: envoy-gateway-system
  hostnames:
    - n8n.example.com
```

> **Note:** `gateway.gatewayName` is required when `gateway.enabled=true`.

## External Secrets Operator (ESO)

Set `encryptionKey.existingSecret` so the chart-managed encryption key Secret is suppressed
and the ExternalSecret is the single source of truth.

```yaml
encryptionKey:
  existingSecret: n8n-eso-secret
  existingSecretKey: encryption-key

externalSecrets:
  enabled: true
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  data:
    - secretKey: encryption-key
      remoteRef:
        key: n8n/credentials
        property: encryption-key
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
| `service.ipFamilyPolicy` | `~` | IP family policy (`SingleStack`, `PreferDualStack`, `RequireDualStack`) |
| `service.ipFamilies` | `[]` | IP families override (`IPv4`, `IPv6`) |
| `gateway.enabled` | `false` | Enable Gateway API HTTPRoute |
| `gateway.gatewayName` | `""` | Gateway name (required when `gateway.enabled=true`) |
| `gateway.gatewayNamespace` | `""` | Gateway namespace |
| `gateway.hostnames` | `[]` | HTTPRoute hostnames |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resource |
| `externalSecrets.apiVersion` | `external-secrets.io/v1` | ExternalSecret API version |
| `externalSecrets.refreshInterval` | `"0"` | Refresh interval (`"0"` = one-time sync) |
| `externalSecrets.secretStoreRef.name` | `""` | SecretStore name (required when enabled) |
| `externalSecrets.secretStoreRef.kind` | `SecretStore` | SecretStore kind |
| `externalSecrets.data` | `[]` | Remote key mappings (must include `encryption-key` entry) |

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
| HTTPRoute | `gateway.enabled` |
| ExternalSecret | `externalSecrets.enabled` |
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

keywords: n8n, workflow, automation, integration, helm, kubernetes, queue, redis, gateway-api, external-secrets, dual-stack

purpose: User-facing chart documentation with install, features, examples, and values reference
scope: Chart

relations:
  - charts/n8n/values.yaml
  - charts/n8n/docs/database.md
  - charts/n8n/docs/queue-mode.md
  - charts/n8n/docs/backup.md
path: charts/n8n/README.md
version: 1.1
date: 2026-04-30
-->
