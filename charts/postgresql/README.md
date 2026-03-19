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
- dedicated metrics Services separated from client traffic
- topology-specific Services for client traffic, primary traffic, and read replicas

## How to choose the architecture

- use `standalone` when operational simplicity matters more than read scaling
- use `replication` when you need separate write and read endpoints, but you are not asking the chart to solve automatic failover

Recommended reading before installation:

- [Standalone](docs/standalone.md)
- [Replication](docs/replication.md)
- [Replication Operations](docs/replication-operations.md)
- [Backup and Restore](docs/backup-restore.md)
- [Secret Rotation](docs/secret-rotation.md)

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
- use `networkPolicy.enabled=true` or external platform controls when possible
- rotate passwords through secret management workflows instead of editing values inline
- use `tls.enabled=true` with certificate material from a managed secret when PostgreSQL traffic must be encrypted

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
- metrics are exposed through dedicated metrics Services, not through the client database Services
- monitor connection count, replication lag, disk growth, checkpoint behavior, and WAL retention

### Configuration UX

- use `config.preset` for a small set of opinionated PostgreSQL defaults
- use `config.pgHbaEntries` when you need structured host-based access rules
- use `*.resourcesPreset` for small and predictable environment sizing before reaching for fully custom resources
- keep `config.postgresql` and `config.pgHba` for raw overrides when structured values are not enough
- keep `auth.database`, `auth.username`, and `auth.replicationUsername` as plain values; `existingSecret` is intentionally limited to sensitive runtime data

## Production notes

- use `auth.existingSecret` instead of inline passwords
- keep persistence enabled for every stateful topology
- define node placement rules for `replication`, especially when the cluster spans multiple nodes or zones
- use the `client` or `primary` Service only for writes
- use the `replicas` Service only for read traffic
- treat backup, restore, and failover as operational workflows external to the chart
- review the operational guides before promoting `replication` to production

Operational documents:

- [Replication Operations](docs/replication-operations.md)
- [Backup and Restore](docs/backup-restore.md)
- [Secret Rotation](docs/secret-rotation.md)

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
| `config.preset` | Optional PostgreSQL config preset | `none` |
| `config.pgHbaEntries` | Structured pg_hba entries | `[]` |
| `standalone.resourcesPreset` | Resource preset for standalone mode | `none` |
| `replication.primary.resourcesPreset` | Resource preset for the primary pod | `none` |
| `replication.readReplicas.resourcesPreset` | Resource preset for replica pods | `none` |
| `initdb.existingConfigMap` | External ConfigMap for extra init scripts | `""` |
| `tls.enabled` | Enable PostgreSQL TLS | `false` |
| `tls.existingSecret` | Existing secret with TLS material | `""` |
| `tls.sslMode` | Internal libpq sslmode | `require` |
| `networkPolicy.enabled` | Enable ingress-only NetworkPolicy | `false` |
| `livenessProbe.enabled` | Enable livenessProbe | `true` |
| `readinessProbe.enabled` | Enable readinessProbe | `true` |
| `startupProbe.enabled` | Enable startupProbe | `true` |
| `standalone.persistence.enabled` | Enable PVC for standalone | `true` |
| `replication.readReplicas.replicaCount` | Number of async read replicas | `2` |
| `metrics.enabled` | Enable `postgres_exporter` sidecar | `false` |
| `metrics.resourcesPreset` | Resource preset for `postgres_exporter` | `none` |
| `metrics.serviceMonitor.enabled` | Enable ServiceMonitor | `false` |
| `pdb.enabled` | Enable PodDisruptionBudget | `false` |

## CI scenarios

The `ci/` scenarios validate the main chart behaviors:

- `standalone.yaml`
- `replication.yaml`
- `initdb.yaml`
- `existing-secret.yaml`
- `metrics.yaml`
- `existing-configmap.yaml`
- `replication-metrics.yaml`
- `scheduling.yaml`
- `tls.yaml`
- `tls-networkpolicy.yaml`
- `config-preset.yaml`
- `structured-pghba.yaml`
- `resources-preset.yaml`

## Examples

See `examples/`:

- `standalone.yaml`
- `replication.yaml`
- `initdb-metrics.yaml`
- `tls.yaml`
- `structured-config.yaml`
- `resources-preset.yaml`

## Important notes

- `replication` here is asynchronous replication with one fixed writable primary
- this chart does not implement automatic primary election
- init scripts run only on first initialization of a fresh data directory
- for failover-oriented production operations, use an operator instead of trying to turn this chart into one
