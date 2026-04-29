# Open WebUI Helm Chart

Self-hosted AI chat platform with Ollama and OpenAI support, RAG pipelines, multi-model conversations,
and an extensible plugin system. This chart deploys Open WebUI on Kubernetes with optional PostgreSQL and Redis subcharts.

## Features

- Single-container deployment with health probes
- SQLite (default) or PostgreSQL for production persistence
- Optional Redis for multi-instance WebSocket coordination
- Ollama backend integration
- OpenAI-compatible API support (any provider)
- Configurable ingress with TLS
- S3-compatible backup CronJob for PostgreSQL data
- Auto-generated session secret key
- Telemetry disabled by default

## Quick Start

```bash
helm install open-webui oci://ghcr.io/helmforgedev/helm/open-webui
```

With Ollama backend:

```bash
helm install open-webui oci://ghcr.io/helmforgedev/helm/open-webui \
  --set openWebui.ollamaBaseUrl=http://ollama.default.svc:11434
```

With PostgreSQL (production):

```bash
helm install open-webui oci://ghcr.io/helmforgedev/helm/open-webui \
  --set postgresql.enabled=true
```

With ingress:

```bash
helm install open-webui oci://ghcr.io/helmforgedev/helm/open-webui \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=chat.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix
```

## Database Modes

Open WebUI supports three database modes controlled by `database.mode`:

| Mode | Description |
|------|-------------|
| `auto` (default) | Uses PostgreSQL subchart if `postgresql.enabled=true`, otherwise SQLite |
| `sqlite` | Always uses embedded SQLite (single instance only) |
| `external` | Uses `database.url` or `database.existingSecret` for an external PostgreSQL |

### External PostgreSQL

```yaml
postgresql:
  enabled: false
database:
  mode: external
  url: "postgresql://user:password@host:5432/openwebui"
```

Or with an existing secret:

```yaml
postgresql:
  enabled: false
database:
  mode: external
  existingSecret: my-db-secret
  existingSecretKey: database-url
```

## Redis for Multi-Instance

When running multiple replicas, Redis coordinates WebSocket sessions:

```yaml
redis:
  enabled: true
```

Or with an external Redis:

```yaml
redisConfig:
  mode: external
  url: "redis://:password@redis.example.com:6379/0"
```

## OpenAI-Compatible Providers

Connect to any OpenAI-compatible API (OpenAI, Azure, Anthropic proxy, LiteLLM):

```yaml
openWebui:
  openaiBaseUrl: https://api.openai.com/v1
  openaiApiKey: sk-...
```

Or with an existing secret:

```yaml
openWebui:
  openaiBaseUrl: https://api.openai.com/v1
  openaiExistingSecret: my-openai-secret
  openaiExistingSecretKey: openai-api-key
```

## S3 Backup

When using PostgreSQL, enable scheduled backups to S3-compatible storage:

```yaml
postgresql:
  enabled: true
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: http://minio.minio.svc:9000
    bucket: open-webui-backups
    accessKey: minioadmin
    secretKey: minioadmin
```

## Default Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `ghcr.io/open-webui/open-webui` | Container image |
| `image.tag` | `""` (uses appVersion) | Image tag |
| `openWebui.port` | `8080` | Application port |
| `openWebui.ollamaBaseUrl` | `""` | Ollama backend URL |
| `openWebui.doNotTrack` | `true` | Disable telemetry |
| `database.mode` | `auto` | Database mode: auto, sqlite, external |
| `persistence.enabled` | `true` | Enable PVC for /app/backend/data |
| `persistence.size` | `10Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `traefik` | Ingress class (also supports `nginx`) |
| `postgresql.enabled` | `false` | Deploy PostgreSQL subchart |
| `redis.enabled` | `false` | Deploy Redis subchart |
| `backup.enabled` | `false` | Enable S3 backup CronJob |

See [`values.yaml`](values.yaml) for the full configuration reference.

<!-- @AI-METADATA
type: chart-readme
path: charts/open-webui/README.md
date: 2026-04-02
relations:
  - charts/open-webui/values.yaml
  - charts/open-webui/Chart.yaml
-->
