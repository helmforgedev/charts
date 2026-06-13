# Listmonk Helm Chart

Deploy [Listmonk](https://listmonk.app), a self-hosted newsletter and mailing
list manager, on Kubernetes with a PostgreSQL backend, persistent uploads,
idempotent database bootstrap, optional ingress, and optional S3-compatible
database backups.

Current application version: `6.1.0`.

## Features

- Official `docker.io/listmonk/listmonk:v6.1.0` image
- HelmForge PostgreSQL subchart or external PostgreSQL mode
- Init containers for `listmonk --install --idempotent` and `--upgrade`
- Persistent upload storage mounted at `/listmonk/uploads`
- Ingress with TLS support
- Optional PostgreSQL backup CronJob using `pg_dump` and S3-compatible upload
- Existing Secret support for external database and backup credentials
- Extra environment variables for SMTP and application automation

## Installation

HTTPS repository:

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install listmonk helmforge/listmonk -f values.yaml
```

OCI registry:

```bash
helm install listmonk oci://ghcr.io/helmforgedev/helm/listmonk -f values.yaml
```

## Examples

The chart includes example values under `examples/`:

- `examples/simple.yaml` - bundled PostgreSQL with persistent uploads.
- `examples/ingress.yaml` - TLS ingress and explicit resources.
- `examples/external-db.yaml` - managed external PostgreSQL.
- `examples/backup.yaml` - S3-compatible PostgreSQL backup CronJob.

Render an example before adapting it:

```bash
helm template listmonk charts/listmonk -f charts/listmonk/examples/ingress.yaml
```

## Architecture Guides

- [Design rationale](DESIGN.md)
- [Architecture guide](docs/architecture.md)
- [Operations guide](docs/operations.md)

## Quick Start

Install with bundled PostgreSQL:

```bash
helm install listmonk helmforge/listmonk
kubectl port-forward svc/listmonk 9000:80
```

Open `http://localhost:9000`, create the first Super Admin user in the setup
wizard, and configure SMTP from the Listmonk UI under Settings > SMTP.

## Database Modes

Default mode deploys the HelmForge PostgreSQL subchart:

```yaml
postgresql:
  enabled: true
database:
  mode: auto
```

External PostgreSQL disables the subchart and reads the password from either an
inline value or an existing Secret:

```yaml
postgresql:
  enabled: false

database:
  mode: external
  external:
    host: postgres.example.com
    port: 5432
    name: listmonk
    username: listmonk
    existingSecret: listmonk-db
    existingSecretPasswordKey: database-password
    sslMode: require
```

External databases must already allow Listmonk to create required objects and
must provide the PostgreSQL extensions Listmonk expects.

## Key Values

| Key | Default | Description |
| --- | --- | --- |
| `replicaCount` | `1` | Number of Listmonk replicas |
| `image.repository` | `docker.io/listmonk/listmonk` | Listmonk image |
| `image.tag` | `"v6.1.0"` | Listmonk image tag |
| `database.mode` | `auto` | Database mode: `auto`, `external`, or `postgresql` |
| `postgresql.enabled` | `true` | Deploy the PostgreSQL subchart |
| `storage.enabled` | `true` | Persist uploaded media |
| `storage.size` | `5Gi` | Uploads PVC size |
| `backup.enabled` | `false` | Enable PostgreSQL backup CronJob |
| `backup.schedule` | `"0 3 * * *"` | Backup cron schedule |
| `backup.s3.existingSecret` | `""` | Existing S3 credential Secret |
| `ingress.enabled` | `false` | Enable Ingress |
| `listmonk.extraEnv` | `[]` | Extra Listmonk environment variables |

## Security Scan

Security Scan: Kubescape on rendered default manifests.

| Framework | Score |
| --- | --- |
| MITRE | 100.00% |
| NSA | 70.00% |
| SOC2 | 90.00% |
| Aggregate | 86.67% |

Default findings are driven by intentionally unset platform-specific controls:
resource limits, container hardening context, service account token mounting, and
NetworkPolicy boundaries. Set `resources`, `securityContext`,
`podSecurityContext`, and platform NetworkPolicies according to your cluster
baseline.

## Backups

Backups are opt-in. Use an existing Secret for S3 credentials in production:

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: listmonk-backups
    prefix: listmonk
    existingSecret: listmonk-s3-credentials
```

The backup CronJob dumps the configured PostgreSQL database and uploads the
archive with the configured object prefix.

## Quality Gates

Before proposing a merge for this chart, run:

```bash
make deps-check CHART=listmonk
make standards-check CHART=listmonk
make validate-chart CHART=listmonk
make site-sync-check CHART=listmonk
```

## Limitations

- Keep `replicaCount=1` unless the database, uploads storage, sessions, and
  operational model have been validated for concurrent Listmonk pods.
- The chart does not manage SMTP credentials as first-class values; use the UI or
  `listmonk.extraEnv` with Secrets.
- Built-in backups cover PostgreSQL. Uploaded media on the uploads PVC needs a
  separate storage backup plan.

## More Information

- [Listmonk documentation](https://listmonk.app/docs)
- [Listmonk source](https://github.com/knadh/listmonk)
- [HelmForge chart source](https://github.com/helmforgedev/charts/tree/main/charts/listmonk)
