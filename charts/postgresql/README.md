# PostgreSQL

PostgreSQL for Kubernetes with explicit `standalone` and `replication` modes, documented bootstrap behavior, optional init scripts, and optional metrics.

## Install

```bash
helm install postgresql oci://ghcr.io/mberlofa/helm/postgresql -f values.yaml
```

## Supported architectures

| Architecture | When to use | Document |
|-------------|-------------|----------|
| `standalone` | development, simple production environments, or workloads where a single writable database is acceptable | [docs/standalone.md](docs/standalone.md) |
| `replication` | one writable primary plus asynchronous read replicas for read scaling and simpler recovery workflows | [docs/replication.md](docs/replication.md) |

## What this chart covers

- explicit architecture selection through `architecture`
- PostgreSQL on the official `postgres` image
- generated or externally-managed passwords through `existingSecret`
- app user and app database bootstrap on first initialization
- optional extra init scripts
- fixed-primary asynchronous replication with `pg_basebackup`
- optional metrics through `postgres_exporter`
- optional `ServiceMonitor`
- topology-specific Services for client traffic, primary traffic, and read replicas

## How to choose the architecture

- use `standalone` when operational simplicity matters more than read scaling
- use `replication` when you need separate write and read endpoints, but you are not asking the chart to solve automatic failover

Recommended reading before installation:

- [Standalone](docs/standalone.md)
- [Replication](docs/replication.md)

## Official product references

- PostgreSQL streaming replication: https://www.postgresql.org/docs/current/warm-standby.html
- PostgreSQL `pg_isready`: https://www.postgresql.org/docs/current/app-pg-isready.html
- PostgreSQL official image: https://hub.docker.com/_/postgres

## Operational direction

- for production needing automatic failover, use a PostgreSQL operator instead of stretching this chart beyond its scope
- `replication` in this chart means one fixed primary with asynchronous replicas
- backups remain an operational concern outside this chart and should be implemented with dedicated tooling

## Quick start

Minimal standalone example:

```yaml
architecture: standalone

auth:
  existingSecret: postgresql-auth

standalone:
  persistence:
    enabled: true
    size: 20Gi
```

Replication example:

```yaml
architecture: replication

auth:
  existingSecret: postgresql-auth

replication:
  primary:
    persistence:
      enabled: true
      size: 50Gi
  readReplicas:
    replicaCount: 2
    persistence:
      enabled: true
      size: 50Gi

metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

## Best practices

### Security

- prefer `auth.existingSecret` in production
- keep client access internal unless there is a strong reason to expose PostgreSQL outside the cluster network
- use external `NetworkPolicy` or equivalent platform controls when possible
- rotate passwords through secret management workflows instead of editing values inline

### Replication and availability

- treat `replication` as read scaling and operational recovery help, not full HA
- place primary and replicas across different nodes or zones when the cluster supports it
- use `pdb.enabled=true` when running multiple replicas and planning maintenance windows

### Initialization

- use `initdb.scripts` for deterministic first-boot SQL or shell customization
- use `initdb.existingConfigMap` when scripts are already managed elsewhere
- remember that `docker-entrypoint-initdb.d` runs only during first initialization of a fresh data directory

### Observability

- enable `metrics.enabled=true` in monitored environments
- enable `metrics.serviceMonitor.enabled=true` when Prometheus Operator is available
- monitor connection count, replication lag, disk growth, checkpoint behavior, and WAL retention

## Main values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `architecture` | `standalone` or `replication` | `standalone` |
| `image.repository` | PostgreSQL image repository | `postgres` |
| `image.tag` | PostgreSQL image tag | `18.3-trixie` |
| `auth.database` | App database created at bootstrap | `app` |
| `auth.username` | App user created at bootstrap | `app` |
| `auth.existingSecret` | Existing secret for passwords | `""` |
| `auth.replicationUsername` | Replication username | `replicator` |
| `initdb.existingConfigMap` | External ConfigMap for extra init scripts | `""` |
| `standalone.persistence.enabled` | Enable PVC for standalone | `true` |
| `replication.readReplicas.replicaCount` | Number of async read replicas | `2` |
| `metrics.enabled` | Enable `postgres_exporter` sidecar | `false` |
| `metrics.serviceMonitor.enabled` | Enable ServiceMonitor | `false` |
| `pdb.enabled` | Enable PodDisruptionBudget | `false` |

## CI scenarios

The `ci/` scenarios validate the main chart behaviors:

- `standalone.yaml`
- `replication.yaml`
- `initdb.yaml`
- `existing-secret.yaml`
- `metrics.yaml`

## Examples

See `examples/`:

- `standalone.yaml`
- `replication.yaml`
- `initdb-metrics.yaml`

## Important notes

- `replication` here is asynchronous replication with one fixed writable primary
- this chart does not implement automatic primary election
- init scripts run only on first initialization of a fresh data directory
- for failover-oriented production operations, use an operator instead of trying to turn this chart into one
