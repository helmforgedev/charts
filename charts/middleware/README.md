# Middleware Helm Chart

Deploy [Middleware](https://github.com/middlewarehq/middleware), the open-source
DORA metrics platform, with the official `middlewareeng/middleware` image and a
separate PostgreSQL database. The chart preserves the application's encryption
keys, runs database migrations before startup, and validates the complete
frontend, analytics, sync, and embedded Redis process set before a pod becomes
ready.

## Features

- Measures deployment frequency, lead time for changes, change failure rate,
  and time to restore.
- Uses the HelmForge PostgreSQL subchart or an operator-managed PostgreSQL.
- Runs the upstream-supported embedded Redis process on loopback.
- Persists encryption keys at the path used by Middleware 0.3.1.
- Applies database migrations in an init container before the application.
- Supports configurable application and Service ports, Ingress, scheduling,
  additional volumes, and extra manifests.
- Creates a tokenless ServiceAccount, RuntimeDefault seccomp profile,
  capability drop, and NetworkPolicy by default.
- Rejects ambiguous datastore modes and unsupported remote Redis settings.

## Installation

Using the HTTPS repository:

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install middleware helmforge/middleware --namespace middleware --create-namespace
```

Using OCI:

```bash
helm install middleware oci://ghcr.io/helmforgedev/helm/middleware \
  --namespace middleware \
  --create-namespace
```

The default installation creates one Middleware Deployment, a PVC for the
application encryption keys, and a standalone PostgreSQL release. Redis runs
inside the official application container because the upstream 0.3.1 remote
Redis client does not support password authentication and unconditionally uses
TLS for non-loopback hosts.

## Architecture

Middleware packages three processes in one container:

| Process | Default port | Purpose |
|---|---:|---|
| Frontend | `3333` | Next.js user interface |
| Analytics API | `9696` | DORA data and API operations |
| Sync server | `9697` | Provider ingestion and synchronization |

The Service exposes only the frontend through the named `http` port. Startup
and readiness probes require all three application listeners plus the loopback
Redis listener. Changing
`middleware.frontendPort`, `middleware.analyticsPort`, or
`middleware.syncPort` changes both the Kubernetes ports and the upstream
process environment.

Before the application starts, an init container runs the migrations shipped
in the same official image. It uses `dbmate --wait`, then writes the signal the
upstream analytics process expects in a shared `emptyDir`. This is required
because disabling the image's embedded PostgreSQL also disables its original
initializer.

## Configuration

| Key | Default | Description |
|---|---|---|
| `middleware.frontendPort` | `3333` | Frontend listener port. |
| `middleware.analyticsPort` | `9696` | Analytics listener port. |
| `middleware.syncPort` | `9697` | Sync listener port. |
| `middleware.environment` | `prod` | Runtime and frontend environment. |
| `middleware.timezone` | `UTC` | IANA timezone used for metric windows. |
| `postgresql.enabled` | `true` | Deploy the PostgreSQL subchart. |
| `externalDatabase.enabled` | `false` | Use an operator-managed PostgreSQL. |
| `externalDatabase.existingSecret` | `""` | Secret containing the database password. |
| `externalDatabase.sslMode` | `disable` | libpq SSL mode for an external database. |
| `persistence.enabled` | `true` | Persist the Middleware encryption keys. |
| `persistence.size` | `1Gi` | Key PVC capacity. |
| `service.port` | `80` | Service port mapped to the frontend. |
| `ingress.enabled` | `false` | Render an Ingress. |
| `networkPolicy.enabled` | `true` | Restrict application ingress to the frontend port. |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount a Kubernetes API token. |

The complete contract is documented in [configuration.md](docs/configuration.md)
and enforced by `values.schema.json` plus template validation.

## Examples

### Bundled PostgreSQL

The defaults are sufficient. For a durable production password, create a
Secret and let the subchart consume it:

```bash
read -r -s -p 'PostgreSQL superuser password: ' MIDDLEWARE_POSTGRES_PASSWORD
printf '\n'
read -r -s -p 'PostgreSQL application password: ' MIDDLEWARE_DB_PASSWORD
printf '\n'
kubectl create namespace middleware --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic middleware-postgresql-credentials \
  --namespace middleware \
  --from-literal=postgres-password="$MIDDLEWARE_POSTGRES_PASSWORD" \
  --from-literal=user-password="$MIDDLEWARE_DB_PASSWORD"
unset MIDDLEWARE_POSTGRES_PASSWORD MIDDLEWARE_DB_PASSWORD
```

```yaml
postgresql:
  enabled: true
  auth:
    database: mhq-oss
    username: middleware
    existingSecret: middleware-postgresql-credentials
    existingSecretUserPasswordKey: user-password

persistence:
  enabled: true
  size: 1Gi
```

Replication mode additionally requires the configured replication password key.

### External PostgreSQL

```yaml
postgresql:
  enabled: false

externalDatabase:
  enabled: true
  host: postgres.database.svc.cluster.local
  port: 5432
  name: mhq-oss
  user: middleware
  existingSecret: middleware-database
  existingSecretPasswordKey: password
  sslMode: require
```

Create `middleware-database` before installation, or source it through an
external secret controller. The chart also accepts an inline
`externalDatabase.password` for development and places it in a chart-managed
Secret; do not commit that value to source control.

### Custom application and Service ports

```yaml
middleware:
  frontendPort: 4333
  analyticsPort: 10696
  syncPort: 10697

service:
  port: 8080
```

The Service continues to target the named frontend port, so `service.port`
does not need to match `middleware.frontendPort`.

## Security

The default pod does not receive a Kubernetes API token. The pod uses the
RuntimeDefault seccomp profile, while both the migration and application
containers disallow privilege escalation and drop all Linux capabilities. The
upstream image starts as root and expands packaged runtime artifacts on first
startup, so this chart cannot safely set `runAsNonRoot` or a read-only root
filesystem without a rebuilt upstream image.

The default NetworkPolicy permits inbound traffic only to the named frontend
port. Egress remains unrestricted because Middleware connects to operator-
selected Git, issue tracker, and CI providers. Restrict egress at the platform
layer only after enumerating all required destinations.

Database passwords are referenced from Kubernetes Secrets. Inline external
passwords are moved into a Secret and are never placed directly in the
Deployment environment. Prefer `externalDatabase.existingSecret` in GitOps
environments.

See [security.md](docs/security.md) for the threat boundaries and residual
upstream constraints.

## Operations

Back up both PostgreSQL and the key PVC. PostgreSQL contains DORA records and
integration metadata; the persisted `config.ini` contains the RSA key pair used
to encrypt stored integration credentials. Restoring only one of these data
sets can make provider credentials unusable.

The application Deployment uses `Recreate` and a single replica. The key PVC
defaults to `ReadWriteOnce`, and upstream does not define a multi-replica
coordination model. Scale and protect PostgreSQL independently, but keep the
application tier at one replica.

Detailed backup, restore, rollout, and diagnostic commands are in
[operations.md](docs/operations.md).

## Troubleshooting

Inspect migration and application logs separately:

```bash
kubectl logs -n middleware deployment/middleware-middleware -c migrate-database
kubectl logs -n middleware deployment/middleware-middleware -c middleware --tail=200
kubectl describe pod -n middleware -l app.kubernetes.io/instance=middleware
```

If the init container waits for PostgreSQL, verify the resolved Service name,
Secret key, network path, and `externalDatabase.sslMode`. If the frontend is
open but the pod is not Ready, inspect the analytics and sync listener logs;
the readiness probe intentionally checks all three processes.

If integrations cannot be decrypted after a restore, confirm that the PVC was
restored from the same recovery point as PostgreSQL and contains
`mhq/config/config.ini` at the mounted application path.

## Upgrade notes

- Preserve the existing key PVC across upgrades.
- Restore or reuse PostgreSQL credential Secrets when PostgreSQL PVCs already
  contain data; generating a new password will not change the database user.
- Remote or subchart Redis values are rejected because Middleware 0.3.1 cannot
  consume them safely. Remove legacy `redis.enabled: true` and
  `externalRedis.enabled: true` overrides.
- Verify all three listeners after an image change because they are supervised
  independently inside the container.

## Documentation

- [Chart design](DESIGN.md)
- [Configuration reference](docs/configuration.md)
- [External database guide](docs/external-datastores.md)
- [Operations and recovery](docs/operations.md)
- [Security model](docs/security.md)
- [Production example](examples/production.yaml)
- [External database example](examples/external-database.yaml)
- [Upstream source](https://github.com/middlewarehq/middleware)

### Security Scan: `middleware`

| Framework | Score |
|---|---:|
| MITRE + NSA + SOC2 | **79.29292%** |

The score is refreshed by CI from rendered manifests. It does not replace
application-image vulnerability scanning or a review of external provider
credentials.
