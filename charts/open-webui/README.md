<!-- SPDX-License-Identifier: Apache-2.0 -->
# Open WebUI Helm chart

Open WebUI is a self-hosted AI interface for Ollama and OpenAI-compatible model
providers. This chart deploys a single Open WebUI instance with persistent data,
optional PostgreSQL and Redis dependencies, ingress, and PostgreSQL backups.

## Features

- SQLite evaluation mode or PostgreSQL for production data.
- Bundled or external PostgreSQL and Redis integrations.
- Secret-backed application, provider, database, Redis, and S3 credentials.
- HTTP startup, liveness, and database-aware readiness probes.
- S3-compatible PostgreSQL backup CronJob.
- Dedicated tokenless ServiceAccount and ingress-isolating NetworkPolicy.
- Recreate upgrades to prevent concurrent migrations and SQLite access.
- Strict values schema and fail-fast validation for incompatible modes.

## Architecture

One web Deployment exposes a named HTTP port through a Service. The Service
selects only `web` component pods, while backup Jobs use a separate component
label. The data PVC stores SQLite, uploads, and embedding assets. Optional
PostgreSQL and Redis dependencies provide production data and WebSocket paths.
The [design document](DESIGN.md) explains why the chart remains single-replica.

## Installation

Install from the signed OCI registry:

```bash
helm install open-webui oci://ghcr.io/helmforgedev/helm/open-webui \
  --namespace open-webui \
  --create-namespace
```

Wait for the initial embedding-model download and application startup:

```bash
kubectl wait --namespace open-webui \
  --for=condition=Available deployment/open-webui-open-webui \
  --timeout=15m
kubectl port-forward --namespace open-webui \
  service/open-webui-open-webui 8080:80
```

Open <http://localhost:8080> and create the initial administrator account.

## Configuration

### Model providers

Connect Ollama:

```yaml
openWebui:
  ollamaBaseUrl: http://ollama.ollama.svc.cluster.local:11434
```

Connect an OpenAI-compatible endpoint. Prefer a pre-created Secret:

```bash
kubectl create secret generic openai-credentials \
  --namespace open-webui \
  --from-literal=openai-api-key='replace-me'
```

```yaml
openWebui:
  openaiBaseUrl: https://api.openai.com/v1
  openaiExistingSecret: openai-credentials
  openaiExistingSecretKey: openai-api-key
```

An endpoint that does not require authentication may set only
`openWebui.openaiBaseUrl`; the chart does not create a dangling API-key
reference.

### Database modes

| Mode | Configuration | Intended use |
|---|---|---|
| SQLite | `database.mode: auto` with PostgreSQL disabled | Evaluation and small single-user installs on local storage |
| Bundled PostgreSQL | `postgresql.enabled: true` | Convenient production starting point |
| External PostgreSQL | `database.mode: external` | Operator-managed production database |

Bundled PostgreSQL:

```yaml
postgresql:
  enabled: true
  auth:
    database: openwebui
    username: openwebui
```

External PostgreSQL with a Secret containing the full connection URL:

```bash
kubectl create secret generic open-webui-database \
  --namespace open-webui \
  --from-literal=database-url='postgresql://openwebui:replace-me@postgres.example:5432/openwebui'
```

```yaml
database:
  mode: external
  existingSecret: open-webui-database
  existingSecretKey: database-url
```

SQLite must not use NFS, SMB, CephFS, Azure Files, or another network-backed
volume. Use PostgreSQL when the storage is not directly attached local SSD/NVMe.

### Redis and WebSockets

Redis is optional for the supported single-replica topology. Enable the bundled
dependency when preparing integrations that rely on Redis:

```yaml
redis:
  enabled: true
```

For an external Redis instance, provide the complete URL through a Secret:

```yaml
redisConfig:
  mode: external
  existingSecret: open-webui-redis
  existingSecretKey: redis-url
```

The chart configures both `REDIS_URL` and `WEBSOCKET_REDIS_URL` and enables the
Redis WebSocket manager when Redis is active.

### Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: chat.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - chat.example.com
      secretName: open-webui-tls
```

Enabling ingress without at least one host fails during rendering.

### PostgreSQL backups

The backup job streams `pg_dump` output to S3-compatible storage. Use an
existing Secret for object-storage credentials:

```yaml
postgresql:
  enabled: true
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.example.com
    bucket: open-webui-backups
    existingSecret: open-webui-s3
    existingSecretAccessKeyKey: access-key
    existingSecretSecretKeyKey: secret-key
```

External PostgreSQL backups additionally require `backup.database.host`,
`port`, `name`, `username`, and a Secret containing only the database password.
See the [configuration guide](docs/configuration.md).

### Key values

| Value | Default | Description |
|---|---:|---|
| `image.repository` | `ghcr.io/open-webui/open-webui` | Official application image |
| `image.tag` | `v0.11.0` | Pinned application image tag |
| `openWebui.port` | `8080` | Application listener and container port |
| `openWebui.ollamaBaseUrl` | `""` | Ollama API URL |
| `database.mode` | `auto` | SQLite, bundled PostgreSQL, or external PostgreSQL selection |
| `redisConfig.mode` | `auto` | Bundled, external, or disabled Redis selection |
| `persistence.enabled` | `true` | Persist `/app/backend/data` |
| `persistence.size` | `10Gi` | Data PVC request |
| `service.port` | `80` | Kubernetes Service port |
| `networkPolicy.enabled` | `true` | Isolate inbound application traffic |
| `backup.enabled` | `false` | Schedule PostgreSQL backups |

See [`values.yaml`](values.yaml) for the complete contract and
[`examples/production.yaml`](examples/production.yaml) for a production-oriented
starting point.

## Examples

- [`examples/postgresql-multiuser.yaml`](examples/postgresql-multiuser.yaml)
  enables PostgreSQL and Redis with measured resource placeholders.
- [`examples/production.yaml`](examples/production.yaml) adds existing Secrets,
  TLS ingress, larger persistence, backup, and NetworkPolicy guidance.

## Security

The chart creates a dedicated ServiceAccount without an API token, enables
`RuntimeDefault` seccomp, disables privilege escalation, drops Linux
capabilities, and restricts inbound traffic to the named HTTP port. Egress is
open because model endpoints and identity providers are operator-selected; set
`networkPolicy.egress` to an environment-specific allowlist where possible.

The official image runs as UID 0 and needs writable application and home paths.
Consequently, the chart does not claim `runAsNonRoot` or a read-only root
filesystem by default. This exception and its operational consequences are
documented in the [security guide](docs/security.md).

Avoid inline production credentials. Existing Secrets keep credentials out of
rendered workload specs, but Helm values and Kubernetes Secret access still
need strict RBAC. Terminate TLS at the ingress and protect the initial
administrator enrollment path.

## Operations

The first startup can take several minutes while Open WebUI downloads its RAG
embedding model. The startup probe allows approximately ten minutes. Readiness
uses `/health/db`, while startup and liveness use `/health`.

Read the [operations guide](docs/operations.md) before upgrades. It covers
backup verification, restore drills, probe diagnosis, database connectivity,
Redis connectivity, and the deliberate single-replica boundary.

## Troubleshooting

Start with pod events, logs, Service endpoints, and both health routes:

```bash
kubectl describe pod --namespace open-webui \
  --selector app.kubernetes.io/name=open-webui
kubectl logs --namespace open-webui \
  deployment/open-webui-open-webui --tail=100
kubectl get endpointslice --namespace open-webui
```

Use the symptom-based procedures in the [operations guide](docs/operations.md)
for startup downloads, database readiness, Redis WebSockets, PVC binding, and
backup failures.

## Upgrade notes

- Back up PostgreSQL or the full data PVC before upgrading.
- The Deployment uses `Recreate`, causing brief downtime while protecting
  SQLite and migration integrity.
- PostgreSQL and Redis subcharts are independent stateful dependencies; review
  their release notes before dependency-major upgrades.
- Do not run mixed Open WebUI versions against one database.

## Documentation

- [Chart design and boundaries](DESIGN.md)
- [Configuration reference](docs/configuration.md)
- [Operations and recovery](docs/operations.md)
- [Security model](docs/security.md)
- [PostgreSQL multi-user example](examples/postgresql-multiuser.yaml)
- [Production example](examples/production.yaml)
- [Open WebUI documentation](https://docs.openwebui.com/)

### Security Scan: `open-webui`

| Framework | Score |
|---|---:|
| MITRE + NSA + SOC2 | **79.29293%** |

Security posture acceptable. The score is refreshed by CI from the rendered
manifests and does not replace application-image vulnerability scanning.
