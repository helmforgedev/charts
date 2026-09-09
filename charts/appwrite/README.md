# Appwrite Helm Chart

Self-hosted backend-as-a-service platform for web, mobile, and Flutter developers. This chart deploys Appwrite with MariaDB and Redis on Kubernetes.

## Features

- Appwrite API server, console, and realtime WebSocket service
- Side-effect-free API health probes using `/v1/health/version`
- 15 background workers for jobs, screenshots, executions, notifications, webhooks, deletes, databases, builds, certificates, functions, mails, messaging, migrations, and stats
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
| Console | `appwrite/new` image | 1 |
| Realtime | `app/realtime.php` | Configurable |
| Workers (15) | `app/worker.php` | Configurable per worker |
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
| `image.repository` | `docker.io/appwrite/appwrite` | Appwrite server image |
| `image.tag` | `2.0.0` | Image tag |
| `console.image.repository` | `docker.io/appwrite/new` | Console image |
| `console.image.tag` | `1.1.16` | Console image tag |
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

## Upgrade Notes

### Appwrite 2.0.0

Back up MariaDB, all shared PVCs and the application Secret before upgrading from
1.9.x. Keep traffic paused during the upgrade and migration. This chart retains
MariaDB explicitly; the upstream installer's new PostgreSQL default does not move
existing data between engines.

Use `helm upgrade --reset-then-reuse-values` (or explicitly set the new image tag),
then run `kubectl exec -n <namespace> deploy/<api-deployment> -c api -- migrate`.
Verify the API, worker logs and existing projects before restoring traffic. For
rollback, restore the database, volumes, Secret and matching old images together.

Console IV uses `appwrite/new:1.1.16` on port 3000 with the API on the same origin;
the console Service still exposes port 80. `worker-audits` was removed upstream:
set `workers.audits.enabled=false` in retained values. Jobs, screenshots,
executions and notifications now have separate worker toggles, alongside the
remaining workers. Disabled workers do not process their respective queues.

Generated encryption and JWT Secret entries are retained on upgrade. Supplying a
new `appwrite.openSslKeyV1` overrides the retained key and requires an application
key-rotation procedure; it is not an automatic data re-encryption mechanism.

DocumentsDB, VectorsDB, embeddings and execution-log dual writes remain disabled.
This chart does not provision the extra engines, embedding server, executor or
orchestrator needed for those features and Functions/Sites execution. Provision
and configure those dependencies separately before opting in through extraEnv.

Usage statistics now require ClickHouse. `appwrite.usageStats` defaults to
`disabled`; to retain or enable usage reporting, provision a private ClickHouse
service (the HelmForge ClickHouse chart can provide it) and supply its HTTP DSN
through a Secret:

```yaml
appwrite:
  usageStats: enabled
  extraEnv:
    - name: _APP_CONNECTIONS_DB_USAGE
      valueFrom:
        secretKeyRef:
          name: appwrite-usage
          key: dsn
```

The DSN has the form `http://user:password@clickhouse:8123/appwrite`; URL-encode
credentials containing reserved characters. Run `usage-setup` in the API pod to
verify schema initialization before enabling traffic. Plan retention of historical usage data separately from new usage schema setup.

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

All 15 workers are enabled by default. Disable unused workers to save resources:

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

### Security Scan: `appwrite`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **79.50%** |

Kubescape v4.0.13; default manifests including MariaDB and Redis.

<!-- @AI-METADATA
type: chart-readme
path: charts/appwrite/README.md
date: 2026-03-31
relations:
  - charts/appwrite/values.yaml
  - charts/appwrite/docs/architecture.md
-->
