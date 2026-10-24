<!-- SPDX-License-Identifier: Apache-2.0 -->
# Open WebUI configuration

## Runtime contract

The application listens on `openWebui.port`, which controls the `PORT`
environment variable, container port, probes, and named Service target. The
Service-facing port is independent and configured with `service.port`.

Open WebUI runs as one replica with a `Recreate` Deployment strategy. This is a
deliberate safety boundary for SQLite, `ReadWriteOnce` persistence, and database
migrations rather than an omitted scaling knob.

## Application and provider settings

| Value | Default | Purpose |
|---|---:|---|
| `openWebui.port` | `8080` | Application listener |
| `openWebui.secretKey` | `""` | Inline session key; generated when empty |
| `openWebui.existingSecret` | `""` | Existing Secret for the session key |
| `openWebui.existingSecretKey` | `secret-key` | Session-key field |
| `openWebui.ollamaBaseUrl` | `""` | Ollama API URL |
| `openWebui.openaiBaseUrl` | `""` | OpenAI-compatible API URL |
| `openWebui.openaiApiKey` | `""` | Inline API key stored in a generated Secret |
| `openWebui.openaiExistingSecret` | `""` | Existing API-key Secret |
| `openWebui.openaiExistingSecretKey` | `openai-api-key` | API-key field |
| `openWebui.doNotTrack` | `true` | Disable supported telemetry |
| `openWebui.extraEnv` | `[]` | Additional environment variables |

The generated session key is reused from the retained Secret during upgrades.
Do not configure both an inline value and an existing Secret for the same
credential; rendering fails to make precedence explicit.

## Database

`database.mode=auto` selects the bundled PostgreSQL chart when
`postgresql.enabled=true`; otherwise it uses SQLite. `database.mode=sqlite`
forces SQLite and cannot be combined with the subchart. `database.mode=external`
requires either `database.url` or `database.existingSecret` and cannot be
combined with the subchart.

| Value | Default | Purpose |
|---|---:|---|
| `database.mode` | `auto` | Database selection |
| `database.url` | `""` | Inline external PostgreSQL URL stored in a generated Secret |
| `database.existingSecret` | `""` | Existing Secret containing the complete URL |
| `database.existingSecretKey` | `database-url` | URL field |
| `postgresql.enabled` | `false` | Enable the HelmForge PostgreSQL dependency |

SQLite on network filesystems is unsupported by Open WebUI and SQLite. Select
PostgreSQL for Kubernetes storage backed by NFS, SMB, CephFS, Azure Files, or
similar network services.

## Redis

`redisConfig.mode=auto` uses the bundled dependency when enabled and otherwise
disables Redis. External mode requires a URL or existing Secret. The URL must
include authentication and database selection when required by the server.

| Value | Default | Purpose |
|---|---:|---|
| `redisConfig.mode` | `auto` | Redis selection |
| `redisConfig.url` | `""` | Inline Redis URL stored in a generated Secret |
| `redisConfig.existingSecret` | `""` | Existing Redis URL Secret |
| `redisConfig.existingSecretKey` | `redis-url` | URL field |
| `redis.enabled` | `false` | Enable the HelmForge Redis dependency |

Active Redis configures `REDIS_URL`, `WEBSOCKET_REDIS_URL`,
`WEBSOCKET_MANAGER=redis`, and `ENABLE_WEBSOCKET_SUPPORT=true`.

## Persistence

The PVC mounts at `/app/backend/data` and stores the SQLite database, uploads,
and downloaded embedding assets. `persistence.existingClaim` disables chart PVC
creation. Changing a Stateful storage class or shrinking a PVC is not handled by
the chart.

## Probes

Startup and liveness default to `/health`; readiness defaults to `/health/db`.
The startup budget is intentionally long because the first RAG embedding model
download can take several minutes. Shorten it only after measuring cold starts
in the target environment.

## Network policy

`networkPolicy.enabled=true` allows ingress to the named HTTP port. Additional
rules in `networkPolicy.ingress` are appended. Egress defaults to `[{}]` because
Open WebUI connects to arbitrary model APIs and identity providers. Replace the
egress list with DNS and destination allowlists supported by the cluster CNI.

## Backups

Backups require PostgreSQL, an S3 endpoint and bucket, plus credentials. With
bundled PostgreSQL, connection fields are derived from the subchart. External
PostgreSQL additionally requires:

```yaml
backup:
  database:
    host: postgres.example.com
    port: 5432
    name: openwebui
    username: openwebui
    existingSecret: open-webui-database-password
    existingSecretKey: database-password
```

The external backup Secret contains the password only. This is separate from
the application's complete `DATABASE_URL` Secret because Helm templates do not
parse or transform credentials from another Secret.

The archive includes PostgreSQL only. Back up uploads and other files from the
data PVC separately when they are required for recovery.

## Scheduling and extensions

`nodeSelector`, `tolerations`, `affinity`, `topologySpreadConstraints`, and
`priorityClassName` control application placement. `extraVolumes`,
`extraVolumeMounts`, `openWebui.extraEnv`, and `extraManifests` are extension
points; their validity and security remain operator responsibilities.

`podLabels` cannot override the name, instance, or component selector labels.
Failing early prevents an invalid Deployment selector or unintended Service
endpoints.
