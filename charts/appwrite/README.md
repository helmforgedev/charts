# Appwrite Helm Chart

Self-hosted backend-as-a-service platform for web, mobile, and Flutter developers. This chart deploys Appwrite with MariaDB and Redis on Kubernetes.

## Features

- Appwrite API server, console, and realtime WebSocket service
- 12 background workers for audits, webhooks, deletes, databases, builds, certificates, functions, mails, messaging, migrations, and stats
- Schedulers for functions, messages, and executions
- Maintenance task for automated housekeeping
- MariaDB subchart (HelmForge) or external database
- Redis subchart (HelmForge) or external cache
- Shared PVC volumes for uploads, cache, certificates, functions, builds, and sites
- Ingress with path-based routing (API, console, realtime)
- Configurable SMTP for outgoing emails
- Auto-generated encryption key and JWT secret

## Quick Start

```bash
helm install appwrite oci://ghcr.io/helmforgedev/helm/appwrite
```

With ingress:

```bash
helm install appwrite oci://ghcr.io/helmforgedev/helm/appwrite \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=appwrite.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix
```

## Architecture

This chart deploys Appwrite as multiple Kubernetes Deployments, each running a different entrypoint of the same `appwrite/appwrite` image:

| Component | Entrypoint | Replicas |
|-----------|-----------|----------|
| API | `app/http.php` | Configurable |
| Console | `appwrite/console` image | 1 |
| Realtime | `app/realtime.php` | Configurable |
| Workers (12) | `app/worker.php` | Configurable per worker |
| Schedulers (3) | `app/tasks.php` | 1 each |
| Maintenance | `app/tasks.php maintenance` | 1 |

> **Note:** The openruntimes-executor, assistant, and browser services are not included in this alpha release. Functions execution requires a separate executor setup.

## Ingress Routing

When ingress is enabled, requests are routed by path:

- `/v1/realtime` → Realtime service (WebSocket)
- `/v1/*` → API service
- `/*` → Console (web UI)

## Default Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `appwrite/appwrite` | Appwrite server image |
| `image.tag` | `""` (uses appVersion) | Image tag |
| `console.image.repository` | `appwrite/console` | Console image |
| `console.image.tag` | `7.5.7` | Console image tag |
| `appwrite.locale` | `en` | Application locale |
| `appwrite.domain` | `""` (auto-detected) | Appwrite domain |
| `appwrite.openSslKeyV1` | `""` (auto-generated) | 64-char hex encryption key |
| `api.replicaCount` | `1` | API server replicas |
| `realtime.replicaCount` | `1` | Realtime server replicas |
| `persistence.enabled` | `true` | Enable shared PVCs |
| `persistence.uploads.size` | `10Gi` | Uploads PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `traefik` | Ingress class |
| `mariadb.enabled` | `true` | Deploy MariaDB subchart |
| `redis.enabled` | `true` | Deploy Redis subchart |

See [`values.yaml`](values.yaml) for the full configuration reference.

## External Database

To use an external MariaDB instead of the subchart:

```yaml
mariadb:
  enabled: false
database:
  mode: external
  external:
    host: mariadb.example.com
    rootUser: root
    rootPassword: "secret"
    name: appwrite
```

Or with an existing secret:

```yaml
mariadb:
  enabled: false
database:
  mode: external
  external:
    host: mariadb.example.com
    existingSecret: my-db-secret
    existingSecretPasswordKey: mariadb-root-password
```

## External Redis

```yaml
redis:
  enabled: false
cache:
  mode: external
  external:
    host: redis.example.com
    password: "secret"
```

## Workers

All 12 workers are enabled by default. Disable unused workers to save resources:

```yaml
workers:
  builds:
    enabled: false
  functions:
    enabled: false
  certificates:
    enabled: false
```

## Examples

- [Standalone with ingress](examples/standalone.yaml)
- [External database](examples/external-database.yaml)

<!-- @AI-METADATA
type: chart-readme
path: charts/appwrite/README.md
date: 2026-03-31
relations:
  - charts/appwrite/values.yaml
  - charts/appwrite/docs/architecture.md
-->
