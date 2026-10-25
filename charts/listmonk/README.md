# Listmonk Helm Chart

Deploy [Listmonk](https://listmonk.app), a self-hosted newsletter and mailing
list manager, on Kubernetes with the official
`docker.io/listmonk/listmonk:v6.2.0` image, a PostgreSQL backend, persistent
uploads, and optional S3-compatible database backups.

## Features

- **Ready on first start**: init containers run `listmonk --install
  --idempotent` and `--upgrade`, and create the superadmin from a Secret
- **Hardened pod**: non-root uid 65534, read-only root filesystem, no
  privilege escalation, every capability dropped, `RuntimeDefault` seccomp
- **PostgreSQL backend**: HelmForge PostgreSQL subchart or an external server
- **Configurable listener**: `listmonk.port` changes the real HTTP listener
- **Persistent uploads** mounted at `/listmonk/uploads`
- **Exposure**: Ingress or Gateway API HTTPRoutes
- **S3 backups**: scheduled `pg_dump` archives uploaded to S3-compatible storage
- **External Secrets Operator** integration for credentials

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install listmonk helmforge/listmonk
```

**OCI registry:**

```bash
helm install listmonk oci://ghcr.io/helmforgedev/helm/listmonk
```

## Quick Start

```bash
helm install listmonk helmforge/listmonk
kubectl rollout status deploy/listmonk --timeout=300s
kubectl get secret listmonk-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl port-forward svc/listmonk 9000:80
```

Open `http://localhost:9000/admin` and log in as `admin` with the password
above, then configure SMTP under Settings > SMTP. A release whose name
contains `listmonk` uses it as the resource prefix; other releases use
`<release>-listmonk`.

## Architecture

The pod runs `wait-for-postgresql` (`pg_isready` with a timeout), `db-init`
(idempotent install, superadmin creation on a fresh database, and upgrade),
and the `listmonk` container. See [DESIGN.md](DESIGN.md),
[docs/architecture.md](docs/architecture.md), and
[docs/operations.md](docs/operations.md).

## Configuration

### Application

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `docker.io/listmonk/listmonk` | Listmonk image |
| `image.tag` | `"v6.2.0"` | Pinned Listmonk image tag |
| `replicaCount` | `1` | Keep 1: several active instances process the same campaigns |
| `listmonk.port` | `9000` | HTTP listener (`LISTMONK_app__address`), 1024-65535 |
| `listmonk.extraEnv` | `[]` | Extra `LISTMONK_*` variables for the app and `db-init` |
| `listmonk.admin.username` | `admin` | Superadmin created by the first install |
| `listmonk.admin.password` | `""` | Superadmin password (8+ characters); generated once when empty |
| `listmonk.admin.existingSecret` | `""` | Existing Secret with the superadmin password |
| `listmonk.admin.existingSecretPasswordKey` | `admin-password` | Key in that Secret |
| `setup.waitImage` | `docker.io/library/postgres:18.6-alpine` | Image for the PostgreSQL wait |
| `setup.databaseWaitTimeoutSeconds` | `300` | Seconds to wait for PostgreSQL |

### Database

| Key | Default | Description |
| --- | --- | --- |
| `database.mode` | `auto` | `auto`, `external`, or `postgresql` |
| `postgresql.enabled` | `true` | Deploy the HelmForge PostgreSQL subchart |
| `database.external.host` / `port` | `""` / `5432` | External PostgreSQL endpoint |
| `database.external.name` / `username` | `listmonk` | External database and user |
| `database.external.password` | `""` | Inline password, stored in a chart Secret |
| `database.external.existingSecret` | `""` | Existing Secret with the database password |
| `database.external.sslMode` | `disable` | PostgreSQL SSL mode |

External databases must let the Listmonk user create objects and the
`pgcrypto` extension, or provide it beforehand.

### Exposure, probes, storage, and backups

| Key | Default | Description |
| --- | --- | --- |
| `service.type` / `service.port` | `ClusterIP` / `80` | Service type and port |
| `ingress.enabled` | `false` | Render an Ingress |
| `gatewayAPI.enabled` | `false` | Render Gateway API HTTPRoutes |
| `gatewayAPI.httpRoutes` | `[]` | HTTPRoutes; each requires `parentRefs` |
| `startupProbe.path` / `livenessProbe.path` / `readinessProbe.path` | `/health` | Probe paths |
| `storage.enabled` / `storage.size` | `true` / `5Gi` | Uploads PVC |
| `backup.enabled` | `false` | Scheduled `pg_dump` upload to S3 |
| `backup.images.postgresql` | `docker.io/library/postgres:18.6-alpine` | `pg_dump` image; must not be older than the server |
| `backup.s3.existingSecret` | `""` | Existing S3 credential Secret |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resources |

Every key is documented in `values.yaml` and validated by
`values.schema.json`.

## Examples

- [examples/simple.yaml](examples/simple.yaml): bundled PostgreSQL with persistent uploads
- [examples/ingress.yaml](examples/ingress.yaml): TLS Ingress and explicit resources
- [examples/external-db.yaml](examples/external-db.yaml): managed external PostgreSQL
- [examples/backup.yaml](examples/backup.yaml): S3-compatible PostgreSQL backups

## Security

- The pod runs as uid 65534 with a read-only root filesystem, no privilege
  escalation, no capabilities, `RuntimeDefault` seccomp, and no ServiceAccount
  token. `/tmp` and `/listmonk/uploads` are the only writable paths.
- The superadmin is created from a Secret on a fresh database, so the instance
  never exposes the first-run admin setup page.
- Credentials accept existing Secrets or ExternalSecret resources.
- The generated superadmin password is read back with `lookup` on upgrade.
  Renderers without cluster access (client-side GitOps rendering) generate a
  new value on every render; set `listmonk.admin.password` or
  `listmonk.admin.existingSecret` in those setups.
- Add NetworkPolicies for your cluster; the chart does not render them.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Pod stuck in `Init:0/2` | `kubectl logs deploy/<name> -c wait-for-postgresql`; the database is unreachable |
| Pod stuck in `Init:1/2` | `kubectl logs deploy/<name> -c db-init`; credentials or privileges are wrong |
| Login rejected after reinstall | The password applies only to a fresh database; read `<name>-admin` from the first install |
| Backup job fails with a version mismatch | Set `backup.images.postgresql` to a client at least as new as the server |

## More Information

- [Listmonk documentation](https://listmonk.app/docs)
- [Listmonk source](https://github.com/knadh/listmonk)
- [HelmForge chart source](https://github.com/helmforgedev/charts/tree/main/charts/listmonk)

### Security Scan: `listmonk`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **90.90909%** |

> Security posture acceptable.
