# Langflow Helm Chart

Langflow is a visual builder for AI workflows, RAG applications, agents, and integrations with model providers and vector databases.
This HelmForge chart deploys the official `docker.io/langflowai/langflow:1.12.0` image with persistent local state by default and explicit
production paths for secret management, PostgreSQL-compatible databases, ingress, Gateway API, and horizontal scaling.

Langflow 1.12 adds authorization changes, database migrations and curated default
component bundles. Advanced runtime settings can be supplied through `app.env` or
`app.envFrom`. Review the migration notes below before upgrading existing data.

The chart generates a URL-safe Fernet encryption key and initial superuser password on first install when `auth.existingSecret` and inline
credentials are empty. These values are reused on upgrades. Runtime probes use Langflow's `/health_check` endpoint so a pod is not marked ready
until application services and the database are healthy.

Authentication is required by default (`auth.autoLogin=false`). Automatic login
is available only as an explicit development setting. The Deployment uses
`Recreate` so old processes stop before a new version starts database migrations.

## Upgrade to 1.12

Before upgrading, stop writers, back up the database and encryption Secret, and
export important flows. Start one replica for Alembic migrations; confirm health
and flow execution before restoring the desired replica count. `Recreate` causes
an upgrade maintenance window. Changing the database URL does not copy SQLite
data to PostgreSQL. Do not run destructive migration repair against the only copy.

Existing generated keys are preserved. Older chart releases generated 64-character
alphanumeric keys, which are not valid Fernet keys. Audit the existing key before
upgrading or enabling production preflight. Restore the original valid key when
encrypted data depends on it; do not silently replace a key or discard credentials.
If the old key is unusable, plan recovery of provider credentials and session
invalidation before explicitly supplying a new key. New valid keys can be created
with `python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'`
in an environment with `cryptography` installed. Store the result in a Secret.

The chart explicitly retains the official image's authenticated default. Only
isolated development deployments should opt in with `auth.autoLogin=true`.

The default image includes curated components and no longer installs PyTorch or
every historical integration. Inventory flows that use removed bundles before
upgrading; upstream offers `langflowai/langflow-all` for the extended profile.
Pin and validate an appropriate supported image profile for those integrations.
RBAC/provider policy and MCP authentication changes also require integration tests.

External OpenTelemetry dashboards must account for the new HTTP semantic
conventions: duration changes from milliseconds to seconds under
`http.server.request.duration`, with renamed method/status/path attributes.
The upstream `OTEL_SEMCONV_STABILITY_OPT_IN=http/dup` setting provides migration
compatibility when needed. This chart does not provision an OpenTelemetry collector.

Sources: [1.12 release](https://github.com/langflow-ai/langflow/releases/tag/v1.12.0),
[database migration guide](https://github.com/langflow-ai/langflow/blob/v1.12.0/docs/docs/Develop/database-migrations.mdx).

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install langflow helmforge/langflow
```

The default deployment starts one Langflow pod on port `7860` and persists `/app/langflow`, which contains local configuration and the default SQLite database.
Ingress class rendering is optional. Set `ingress.ingressClassName: ""` to omit `spec.ingressClassName`.
When `networkPolicy.enabled=true`, ingress is restricted to the configured peers.
It also enables egress isolation with built-in DNS and HTTPS allowances, then appends `networkPolicy.extraEgress` for database, provider, or proxy rules.
Set `networkPolicy.dnsEgressPeers` when your cluster DNS pods do not use the default kube-system/kube-dns labels.

## Production Configuration

For production, use an existing Secret so credentials remain under your secret-management lifecycle:

```yaml
auth:
  existingSecret: langflow-auth
  secretKeyKey: secret-key
  superuserKey: superuser
  superuserPasswordKey: superuser-password
```

Use an external PostgreSQL-compatible database before scaling horizontally:

```yaml
replicaCount: 3
database:
  mode: external
  existingSecret: langflow-database
persistence:
  accessModes:
    - ReadWriteMany
pdb:
  enabled: true
```

The chart refuses `replicaCount > 1` unless `database.url` or `database.existingSecret` is set.
When persistence stays enabled for multiple replicas, the PVC must be shared safely with `ReadWriteMany`; otherwise disable persistence for ephemeral local config or keep a single replica.

## Provider Secrets

Flows often need provider credentials such as OpenAI, Anthropic, GitHub, Hugging Face, or vector database keys. Use `app.env` for explicit entries or `app.envFrom` to import a Secret:

```yaml
app:
  envFrom:
    - secretRef:
        name: langflow-provider-keys
```

## Security Scan: `langflow`

| Framework | Score |
|---|---|
| Overall | **75.76%** |
| MITRE | **100.00%** |
| NSA | **65.00%** |
| SOC2 | **80.00%** |

> Security posture acceptable.

## Documentation

- [Operations](docs/operations.md)
- [Security](docs/security.md)
- [Database](docs/database.md)
- [Scaling](docs/scaling.md)
- [Langflow environment variables](https://docs.langflow.org/environment-variables)
- [Langflow Kubernetes production guide](https://docs.langflow.org/deployment-kubernetes-prod)
- [Langflow authentication](https://docs.langflow.org/api-keys-and-authentication)
