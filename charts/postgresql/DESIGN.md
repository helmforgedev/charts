# PostgreSQL Chart Design

## Scope

This chart provides a Helm-native PostgreSQL deployment for development, simple production, and fixed-primary replication use cases.

Supported architectures:

- `standalone`: one writable PostgreSQL pod backed by one PVC
- `replication`: one fixed writable primary plus asynchronous read replicas

The chart intentionally keeps defaults lightweight with the `small` resource
presets. Production users should apply explicit values for credentials,
persistence, workload sizing, network boundaries, backup, metrics, and
scheduling.

## Architecture: Standalone

```mermaid
flowchart LR
  app[Application pods] --> svc[Client Service]
  svc --> pg[PostgreSQL StatefulSet pod-0]
  pg --> pvc[(PVC)]
  pg --> cfg[Generated postgresql.conf / pg_hba.conf]
  pg --> secret[Password Secret]
  eso[External Secrets Operator optional] -. materializes .-> secret
```

Standalone mode is appropriate for development, test, internal tooling, and production workloads where restore-based recovery is acceptable.

## Architecture: Fixed-Primary Replication

```mermaid
flowchart TB
  write[Write clients] --> primarySvc[Primary Service]
  read[Read clients] --> replicaSvc[Replicas Service]

  primarySvc --> primary[Primary StatefulSet pod-0]
  replicaSvc --> replica0[Replica StatefulSet pod-0]
  replicaSvc --> replica1[Replica StatefulSet pod-1]

  primary -. streaming replication .-> replica0
  primary -. streaming replication .-> replica1

  primary --> primaryPVC[(Primary PVC)]
  replica0 --> replicaPVC0[(Replica PVC 0)]
  replica1 --> replicaPVC1[(Replica PVC 1)]
```

Replication mode is read scaling and recovery assistance, not automatic HA. The primary is fixed. Promotion, fencing, failover, and reconciliation remain operational workflows outside this chart.

## Architecture: Production Hardening

```mermaid
flowchart TB
  apps[Authorized client namespaces] --> np[NetworkPolicy ingress]
  np --> svc[Client or Primary Service]
  svc --> pg[PostgreSQL pod]

  pg --> pvc[(Persistent Volume)]
  pg --> metrics[postgres_exporter sidecar]
  pg --> tls[TLS Secret copied to owned emptyDir]
  pg --> hba[Structured pg_hba CIDRs]
  eso[External Secrets Operator] -. optional auth/tls/backup Secrets .-> pg

  backup[CronJob pg_dumpall] --> s3[S3-compatible storage]
  metrics --> prom[Prometheus / ServiceMonitor]
```

Production hardening uses opt-in controls:

- `auth.existingSecret`
- `externalSecrets.auth.enabled`
- `config.allowedClientCIDRs`
- `config.allowedReplicationCIDRs`
- `tls.volumePermissions.enabled`
- `replication.slots.enabled`
- `replication.wal.maxSlotWalKeepSize`
- `networkPolicy.egress.enabled`
- `serviceAccount.automountServiceAccountToken=false`

## Main Design Choices

- Use the official `postgres` image as the database runtime.
- Use StatefulSets and PVCs for stable pod identity and storage.
- Keep StatefulSet PVC retention explicit and independently configurable for standalone, primary, and replica data.
- Render `postgresql.conf` and `pg_hba.conf` from structured values first, with raw escape hatches for advanced cases.
- Bootstrap replicas with `pg_basebackup -R`.
- Keep replication slots optional because they improve WAL safety for lagging replicas but can retain disk indefinitely without limits and monitoring.
- Keep PgBouncer/Pgpool out of scope. Pooling belongs in a separate chart or application/platform layer.
- Render External Secrets Operator resources only when requested. The chart does not install the operator or own provider-side secret stores.
- Isolate S3 workload identity on a dedicated backup ServiceAccount; static credentials remain available through Secret or ExternalSecret.
- Keep HA automation out of scope. Use a PostgreSQL operator for automated failover and lifecycle reconciliation.

## Explicit Non-Goals

- automatic failover
- primary election
- fencing
- Patroni, repmgr, or operator-like orchestration
- bundled PgBouncer or Pgpool
- major version migration automation
- PITR controller logic
- backup controller logic inside the chart

## Production Boundary

This chart can be used in production when the operator accepts fixed-primary semantics and provides runbooks for backup, restore, scaling, failover decisions, and incident response.

Use an operator when requirements include:

- automated failover
- switchover workflows
- continuous physical backup and PITR reconciliation
- declarative replica lifecycle management
- synchronous replication policies with failover awareness

## Security Boundary

The chart configures the main StatefulSet containers to run as non-root and drop Linux capabilities, disables
service-account token automount by default, and can render TLS, structured `pg_hba.conf` rules, ExternalSecret
resources, and ingress and egress NetworkPolicies. The official PostgreSQL image needs writable runtime and data paths,
so the main container does not claim a read-only root filesystem. TLS certificate issuance, SecretStore configuration,
credential rotation, and encryption of backup objects remain operator responsibilities.

NetworkPolicy enforcement depends on a compatible cluster network plugin. The default client and replication CIDRs
preserve broad connectivity and must be restricted for production. Server TLS protects PostgreSQL connections when
enabled, but the chart does not terminate TLS for the optional metrics endpoint or create a certificate authority.

## Observability Boundary

Optional `postgres_exporter` sidecars and Services expose PostgreSQL metrics, and an optional ServiceMonitor integrates
with an existing Prometheus Operator installation. PostgreSQL logs, Kubernetes events, replication views, backup Job
status, PVC capacity, and exporter scrape health remain the primary operational signals.

The chart does not install Prometheus, a log collector, dashboards, tracing, or opinionated alert rules. Operators must
define service-level objectives and alerts for connection saturation, replication lag, WAL retention, storage growth,
backup freshness, restore testing, and certificate or credential expiry.

## Known Gaps

- replication uses a fixed primary and does not automate promotion, fencing, failback, or split-brain prevention
- the built-in backup CronJob creates logical dumps but does not provide continuous archiving or point-in-time recovery
- replication slots can retain WAL until storage is exhausted unless operators configure limits and alerts
- major PostgreSQL upgrades and storage-class migrations require an external migration plan
- TLS certificates and database credentials are not issued or rotated automatically by this chart
- connection pooling and automatic read/write routing require separate platform components
