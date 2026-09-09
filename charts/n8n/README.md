# n8n Helm Chart

Deploy [n8n](https://n8n.io/) on Kubernetes — a workflow automation platform for technical teams.

## Features

- **SQLite by default** — zero database configuration needed
- **PostgreSQL subchart** — bundled via HelmForge dependency
- **External database** — connect to existing PostgreSQL
- **Queue mode** — Redis-backed horizontal scaling with worker pods
- **Redis subchart** — bundled via HelmForge dependency for queue mode
- **Worker-aware persistence** — queue workers keep the main data PVC by default for upgrade compatibility, with an opt-out for RWO scheduling
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
  parentRefs:
    - name: envoy-gateway
      namespace: envoy-gateway-system
  hostnames:
    - n8n.example.com
```

> **Note:** `gateway.parentRefs` is required when `gateway.enabled=true`.
> Existing releases that still carry `gatewayAPI.enabled`, `gatewayAPI.gatewayName`,
> and `gatewayAPI.gatewayNamespace` from older chart values remain supported as a
> deprecated upgrade alias. New configuration should use `gateway.parentRefs`.

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
| `image.repository` | `docker.io/n8nio/n8n` | n8n container image repository |
| `image.tag` | `2.38.4` | n8n container image tag |
| `n8n.encryptionKey` | `""` | Encryption key for credentials (auto-generated) |
| `n8n.webhookUrl` | `""` | Webhook URL (auto-detected from ingress) |
| `n8n.logLevel` | `info` | Log level (info, warn, error, debug) |
| `n8n.diagnosticsEnabled` | `false` | Share anonymous diagnostics with n8n |
| `n8n.gracefulShutdownTimeout` | `60` | Graceful shutdown timeout in seconds for main and workers |
| `database.mode` | `auto` | Database mode (auto, sqlite, external, postgresql) |
| `postgresql.enabled` | `false` | Deploy PostgreSQL subchart (`helmforge/postgresql` `2.0.5`) |
| `postgresql.initdb.scripts` | n8n extension bootstrap | Creates PostgreSQL extensions required by n8n migrations |
| `queue.enabled` | `false` | Enable queue mode (requires Redis and a non-SQLite database) |
| `queue.workers` | `1` | Number of worker replicas |
| `queue.concurrency` | `10` | Concurrent workflows per worker |
| `queue.persistence.shareMainVolume` | `true` | Mount the main n8n data PVC into worker pods |
| `terminationGracePeriodSeconds` | `75` | Kubernetes pod shutdown grace period |
| `redis.enabled` | `false` | Deploy Redis subchart (`helmforge/redis` `2.0.1`) |
| `taskRunners.mode` | `external` | Task runner mode (`internal` or `external`) |
| `taskRunners.image.repository` | `docker.io/n8nio/runners` | External task runner sidecar image repository |
| `taskRunners.image.tag` | `""` | External task runner sidecar tag (defaults to `image.tag`) |
| `taskRunners.autoShutdownTimeout` | `15` | External runner launcher idle shutdown timeout |
| `taskRunners.authToken` | `""` | External runner auth token, auto-generated when empty |
| `taskRunners.nativePython.enabled` | `false` | Enable native Python runner integration |
| `persistence.enabled` | `true` | Enable persistent storage |
| `persistence.size` | `5Gi` | PVC size |
| `resources.requests.memory` | `512Mi` | Default memory request for the main pod |
| `securityContext.runAsNonRoot` | `true` | Run n8n containers as the upstream non-root node user |
| `ingress.enabled` | `false` | Enable ingress |
| `backup.enabled` | `false` | Enable S3 backups |
| `service.ipFamilyPolicy` | `~` | IP family policy (`SingleStack`, `PreferDualStack`, `RequireDualStack`) |
| `service.ipFamilies` | `[]` | IP families override (`IPv4`, `IPv6`) |
| `gateway.enabled` | `false` | Enable Gateway API HTTPRoute |
| `gateway.parentRefs` | `[]` | Gateway parentRefs (required when `gateway.enabled=true`) |
| `gateway.hostnames` | `[]` | HTTPRoute hostnames |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resource |
| `externalSecrets.apiVersion` | `external-secrets.io/v1` | ExternalSecret API version |
| `externalSecrets.refreshInterval` | `"0"` | Refresh interval (`"0"` = one-time sync) |
| `externalSecrets.secretStoreRef.name` | `""` | SecretStore name (required when enabled) |
| `externalSecrets.secretStoreRef.kind` | `SecretStore` | SecretStore kind |
| `externalSecrets.data` | `[]` | Remote key mappings (must include `encryption-key` entry) |

## Upgrade Notes

n8n `2.38.4` includes the 2.36–2.38 runner broker and shutdown fixes,
database pool recovery, encryption-key seeding and queue execution fixes. Back
up the database and data volume, preserve the encryption key, and validate
workflows and credentials in staging before upgrading. Keep the app and external
runner tags aligned; an empty `taskRunners.image.tag` inherits `image.tag`.

Use `helm upgrade --reset-then-reuse-values` with `image.tag=2.38.4` and update
any separately pinned runner tag. Existing generated encryption keys and runner
tokens are retained through Helm lookup; use existing Secrets for offline
rendering or GitOps. Automatic database migrations require a recoverable backup.

SQLite updates now use `Recreate` to stop the old main process before the new
version opens the same database. Plan for brief downtime. The Python toggle
`taskRunners.nativePython.enabled` now controls the n8n 2.x variable
`N8N_PYTHON_ENABLED`; it remains disabled by default and requires external runners.

### MySQL and MariaDB storage migration

n8n removed MySQL/MariaDB storage in version 2.0. Earlier chart releases still
exposed these unsupported options. This chart now rejects `mysql.enabled=true`,
`database.mode=mysql` and non-PostgreSQL external vendors, and no longer bundles
MySQL or MySQL backup jobs. The MySQL workflow node is unaffected.

If an older deployment uses MySQL/MariaDB, stop here and migrate its data using
the upstream migration procedure on a compatible source release. Back up the
database and encryption key, migrate into a separate PostgreSQL instance, and
verify credentials, workflows and executions before switching traffic. Changing
`database.mode` alone does not migrate data. Do not apply this release over an
existing bundled MySQL installation until its data has been migrated and its
backup and PVC recovery have been verified.

See the [2.0 storage migration guidance](https://github.com/n8n-io/n8n-docs/blob/main/docs/changelog/v20-breaking-changes.md)
and [upstream releases](https://github.com/n8n-io/n8n/releases).

The chart defaults to `N8N_RUNNERS_MODE=external`. It creates a shared auth
token, opens the broker port, and runs a `docker.io/n8nio/runners` sidecar next
to the main pod and each queue worker. This avoids the missing-Python warning
produced by internal runner mode in the upstream `n8nio/n8n` image and gives
each queue worker its own runner, as required by n8n external task runner
architecture.

Anonymous diagnostics are disabled by default with
`N8N_DIAGNOSTICS_ENABLED=false`, which keeps self-hosted clusters private and
reduces startup log noise. Operators can opt in with
`n8n.diagnosticsEnabled=true`.

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
- [Chart design](DESIGN.md)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/n8n)

### Security Scan: `n8n`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **87.88%** |

Rendered-resource scan with Kubescape 4.0.13. Application and workflow behavior are validated separately.

<!-- @AI-METADATA
type: chart-readme
title: n8n Helm Chart
description: Helm chart for deploying n8n workflow automation platform on Kubernetes

keywords: n8n, workflow, automation, integration, helm, kubernetes, queue, redis, gateway-api, external-secrets, dual-stack

purpose: User-facing chart documentation with install, features, examples, and values reference
scope: Chart

relations:
  - charts/n8n/DESIGN.md
  - charts/n8n/values.yaml
  - charts/n8n/docs/database.md
  - charts/n8n/docs/queue-mode.md
  - charts/n8n/docs/backup.md
path: charts/n8n/README.md
version: 1.2
date: 2026-06-02
-->
