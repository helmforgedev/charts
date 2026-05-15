# PostgreSQL

PostgreSQL for Kubernetes with explicit `standalone` and `replication` modes, documented bootstrap behavior, optional init scripts, and optional metrics.

Defaults are intentionally lightweight for development and simple internal environments.
Production deployments should layer explicit values for Secrets, persistence, resources,
network boundaries, backup, observability, scheduling, and security hardening.

## Install

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install postgresql helmforge/postgresql -f values.yaml
```

### OCI registry

```bash
helm install postgresql oci://ghcr.io/helmforgedev/helm/postgresql -f values.yaml
```

## Supported architectures

| Architecture | When to use | Document |
|-------------|-------------|----------|
| `standalone` | development, simple production environments, or workloads where a single writable database is acceptable | [docs/standalone.md](docs/standalone.md) |
| `replication` | one writable primary plus asynchronous read replicas for read scaling and simpler recovery workflows | [docs/replication.md](docs/replication.md) |

## What this chart covers

- explicit architecture selection through `architecture`
- PostgreSQL on the official `postgres` image
- generated passwords, manually managed `existingSecret`, or optional External Secrets Operator resources
- app user and app database bootstrap on first initialization
- optional extra init scripts
- fixed-primary asynchronous replication with `pg_basebackup`
- role-aware readiness checks for primary and replicas in replication mode
- optional metrics through `postgres_exporter`
- optional `ServiceMonitor`
- built-in S3 backup CronJob using `pg_dumpall`
- dedicated metrics Services separated from client traffic
- topology-specific Services for client traffic, primary traffic, and read replicas
- optional dual-stack Service fields through `service.ipFamilyPolicy` and `service.ipFamilies`
- optional `ExternalSecret` resources for clusters that already run External Secrets Operator

## How to choose the architecture

- use `standalone` when operational simplicity matters more than read scaling
- use `replication` when you need separate write and read endpoints, but you are not asking the chart to solve automatic failover

Recommended reading before installation:

- [Standalone](docs/standalone.md)
- [Replication](docs/replication.md)
- [Production](docs/production.md)
- [Replication Operations](docs/replication-operations.md)
- [HA and Scope Boundaries](docs/ha-and-scope-boundaries.md)
- [Backup and Restore](docs/backup-restore.md)
- [Secret Rotation](docs/secret-rotation.md)

## Official product references

- PostgreSQL streaming replication: <https://www.postgresql.org/docs/current/warm-standby.html>
- PostgreSQL `pg_isready`: <https://www.postgresql.org/docs/current/app-pg-isready.html>
- PostgreSQL official image: <https://hub.docker.com/_/postgres>

## Operational direction

- for production needing automatic failover, use a PostgreSQL operator instead of stretching this chart beyond its scope
- `replication` in this chart means one fixed primary with asynchronous replicas
- built-in logical backup to S3 is available for standalone and replication topologies

## Read traffic model

In `replication` mode, the chart exposes separate Services for different traffic patterns:

- the base client Service for general in-cluster access
- a dedicated primary Service for write traffic
- a dedicated replicas Service for read-only traffic

The replicas Service is the endpoint to use for horizontal read scaling when an application, reporting stack, or other read-heavy component can work against asynchronous read-only replicas.

Important limits:

- Kubernetes Service balancing distributes connections across available replicas, but it is not a PostgreSQL-aware query router
- replica reads may lag behind the primary because replication is asynchronous
- workloads that require immediate read-after-write consistency should stay on the primary endpoint

## Scope boundary

This chart intentionally stays on the Helm-chart side of the boundary:

- it manages PostgreSQL pods, services, storage, init scripts, metrics, TLS, and basic replication operations
- it does not attempt to behave like a cluster manager
- it does not implement automatic failover, leader election, fencing, or reconciliation loops

If you need automated failover, self-healing topology management, switchover workflows,
or lifecycle orchestration across primary and replicas,
use a PostgreSQL operator instead of extending this chart into that territory.

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

Production hardening example:

```yaml
architecture: replication

auth:
  existingSecret: postgresql-auth

config:
  allowedClientCIDRs:
    - 10.42.0.0/16
  allowedReplicationCIDRs:
    - 10.42.0.0/16

tls:
  enabled: true
  existingSecret: postgresql-tls
  volumePermissions:
    enabled: true

replication:
  wal:
    keepSize: 2GB
    maxSlotWalKeepSize: 8GB
    idleReplicationSlotTimeout: 24h
    walSenderTimeout: 60s
  slots:
    enabled: true

metrics:
  enabled: true
  serviceMonitor:
    enabled: true

networkPolicy:
  enabled: true
  egress:
    enabled: true

serviceAccount:
  create: true
  automountServiceAccountToken: false
```

See [examples/production.yaml](examples/production.yaml) for a fuller production-oriented values file.

External Secrets Operator example:

```yaml
auth:
  database: app
  username: app

tls:
  enabled: true

backup:
  enabled: true
  s3:
    endpoint: https://minio.example.com
    bucket: postgresql-backups

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  auth:
    enabled: true
    postgresPasswordRemoteRef:
      key: postgresql/auth
      property: postgres-password
    userPasswordRemoteRef:
      key: postgresql/auth
      property: user-password
  tls:
    enabled: true
    certRemoteRef:
      key: postgresql/tls
      property: tls.crt
    keyRemoteRef:
      key: postgresql/tls
      property: tls.key
    caRemoteRef:
      key: postgresql/tls
      property: ca.crt
  backup:
    enabled: true
    accessKeyRemoteRef:
      key: postgresql/backup
      property: access-key
    secretKeyRemoteRef:
      key: postgresql/backup
      property: secret-key
```

The chart renders only `ExternalSecret` resources. External Secrets Operator and
the referenced `SecretStore` or `ClusterSecretStore` must already exist.

## Best practices

### Security

- prefer `auth.existingSecret` in production
- use `externalSecrets.enabled=true` only on clusters where External Secrets Operator and the referenced store already exist
- keep the password Secret aligned with the password stored in any existing PVC; PostgreSQL does not rewrite `pg_authid` just because a Kubernetes Secret changed
- keep client access internal unless there is a strong reason to expose PostgreSQL outside the cluster network
- use `networkPolicy.enabled=true` or external platform controls when possible
- use `networkPolicy.egress.enabled=true` when the cluster enforces egress isolation
- keep `serviceAccount.automountServiceAccountToken=false` unless an integration requires Kubernetes API access from the pod
- rotate passwords through secret management workflows instead of editing values inline
- when `externalSecrets.auth.enabled=true`, the native auth Secret is suppressed and PostgreSQL consumes the materialized target Secret
- use `tls.enabled=true` with certificate material from a managed secret when PostgreSQL traffic must be encrypted
- enable `tls.volumePermissions.enabled=true` when PostgreSQL rejects mounted Secret key permissions
- restrict `config.allowedClientCIDRs` and `config.allowedReplicationCIDRs` to pod/client networks that should reach PostgreSQL

### Replication and availability

- treat `replication` as read scaling and operational recovery help, not full HA
- place primary and replicas across different nodes or zones when the cluster supports it
- use `pdb.enabled=true` when running multiple replicas and planning maintenance windows
- review the default replication PDB and placement behavior before overriding them globally
- keep `startupProbe` conservative for PostgreSQL, especially on larger volumes and recovery paths
- enable `replication.slots.enabled=true` only when WAL retention limits and disk monitoring are also in place
- use `replication.wal.maxSlotWalKeepSize`, `replication.wal.idleReplicationSlotTimeout`, and `replication.wal.walSenderTimeout` to bound replication slot risk

### Initialization

- use `initdb.scripts` for deterministic first-boot SQL or shell customization
- use `initdb.existingConfigMap` when scripts are already managed elsewhere
- set `initdb.runDefaultScript=false` when you want only custom or externally managed first-boot scripts
- remember that `docker-entrypoint-initdb.d` runs only during first initialization of a fresh data directory
- the chart keeps internal maintenance traffic on PostgreSQL's standard `postgres` database
- when an older reused PVC is missing `postgres`, the primary pod repairs that database during startup before probes and internal clients depend on it

### Observability

- enable `metrics.enabled=true` in monitored environments
- enable `metrics.serviceMonitor.enabled=true` when Prometheus Operator is available
- metrics are exposed through dedicated metrics Services, not through the client database Services
- monitor connection count, replication lag, disk growth, checkpoint behavior, and WAL retention

### Configuration UX

- use `config.preset` for a small set of opinionated PostgreSQL defaults
- use `config.allowedClientCIDRs` and `config.allowedReplicationCIDRs` for structured `pg_hba.conf` network access
- use `config.pgHbaEntries` when you need structured host-based access rules
- keep `config.localAuthMethod=scram-sha-256` for production so local socket clients do not bypass password auth
- use `*.resourcesPreset` for small and predictable environment sizing before reaching for fully custom resources
- keep `config.postgresql` and `config.pgHba` for raw overrides when structured values are not enough
- keep `auth.database`, `auth.username`, and `auth.replicationUsername` as plain values; `existingSecret` is intentionally limited to sensitive runtime data
- use `service.ipFamilyPolicy` and `service.ipFamilies` only when the target cluster supports the requested IP family behavior

## Production notes

- use `auth.existingSecret` instead of inline passwords
- use `externalSecrets.auth.enabled=true` when the platform standard is External Secrets Operator instead of pre-created Secrets
- keep persistence enabled for every stateful topology
- define node placement rules for `replication`, especially when the cluster spans multiple nodes or zones
- define explicit CPU and memory resources
- restrict generated `pg_hba.conf` CIDRs and enable NetworkPolicy for defense in depth
- enable ServiceMonitor or equivalent scraping for PostgreSQL and replication health
- use the `client` or `primary` Service only for writes
- use the `replicas` Service only for read traffic
- use the `replicas` Service when you need horizontal scale for read-only workloads
- built-in backup dumps all PostgreSQL databases and global objects from the writable primary endpoint and uploads the compressed archive to S3-compatible storage
- internal probes, metrics, backup, and administrative validation commands are expected to succeed against `postgres`
- treat restore validation, retention policy, WAL strategy, and failover as operational workflows that still require explicit runbooks
- review the operational guides before promoting `replication` to production

Operational documents:

- [Replication Operations](docs/replication-operations.md)
- [HA and Scope Boundaries](docs/ha-and-scope-boundaries.md)
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
| `config.allowedClientCIDRs` | CIDRs allowed for regular PostgreSQL client connections in generated `pg_hba.conf` | `["0.0.0.0/0", "::/0"]` |
| `config.allowedReplicationCIDRs` | CIDRs allowed for replica bootstrap, replication slot checks, and streaming replication in generated `pg_hba.conf` | `["0.0.0.0/0", "::/0"]` |
| `config.pgHbaEntries` | Structured pg_hba entries | `[]` |
| `standalone.resourcesPreset` | Resource preset for standalone mode | `none` |
| `replication.primary.resourcesPreset` | Resource preset for the primary pod | `none` |
| `replication.readReplicas.resourcesPreset` | Resource preset for replica pods | `none` |
| `initdb.runDefaultScript` | Run the chart-generated first-boot app/replication user script | `true` |
| `initdb.existingConfigMap` | External ConfigMap for extra init scripts | `""` |
| `tls.enabled` | Enable PostgreSQL TLS | `false` |
| `tls.existingSecret` | Existing secret with TLS material | `""` |
| `tls.sslMode` | Internal libpq sslmode | `require` |
| `tls.volumePermissions.enabled` | Copy TLS material into an owned `emptyDir` and set private key mode `0600` | `false` |
| `externalSecrets.enabled` | Render optional ExternalSecret resources | `false` |
| `externalSecrets.secretStoreRef.name` | SecretStore or ClusterSecretStore name | `""` |
| `externalSecrets.auth.enabled` | Manage the PostgreSQL auth Secret with External Secrets Operator | `false` |
| `externalSecrets.tls.enabled` | Manage the TLS Secret with External Secrets Operator | `false` |
| `externalSecrets.backup.enabled` | Manage backup S3 credentials with External Secrets Operator | `false` |
| `backup.enabled` | Enable built-in S3 backup CronJob | `false` |
| `backup.schedule` | Backup schedule | `"0 3 * * *"` |
| `backup.s3.endpoint` | S3-compatible endpoint URL | `""` |
| `backup.s3.bucket` | Target bucket name | `""` |
| `backup.database.pgDumpAllArgs` | Extra `pg_dumpall` flags | `"--clean --if-exists"` |
| `networkPolicy.enabled` | Enable ingress-only NetworkPolicy | `false` |
| `networkPolicy.egress.enabled` | Add egress rules to the NetworkPolicy | `false` |
| `networkPolicy.egress.allowDNS` | Allow TCP/UDP DNS egress | `true` |
| `networkPolicy.egress.allowHTTPS` | Allow HTTPS egress for S3-compatible backups | `true` |
| `networkPolicy.egress.allowSameNamespacePostgreSQL` | Allow same-namespace PostgreSQL egress for internal traffic | `true` |
| `livenessProbe.enabled` | Enable livenessProbe | `true` |
| `readinessProbe.enabled` | Enable readinessProbe | `true` |
| `startupProbe.enabled` | Enable startupProbe | `true` |
| `replication.primary.probes.requireWritable` | Require primary readiness to confirm writable state | `true` |
| `replication.readReplicas.probes.requireRecoveryMode` | Require replica readiness to confirm recovery mode | `true` |
| `replication.wal.keepSize` | Local WAL retention target | `512MB` |
| `replication.wal.maxSlotWalKeepSize` | Maximum WAL retained by replication slots | `""` |
| `replication.wal.idleReplicationSlotTimeout` | Inactive replication slot timeout | `""` |
| `replication.wal.walSenderTimeout` | WAL sender timeout | `""` |
| `replication.slots.enabled` | Use physical replication slots for read replicas | `false` |
| `replication.slots.namePrefix` | Prefix for deterministic replica slot names | `replica` |
| `replication.pdb.enabled` | Enable replication PDB by default | `true` |
| `replication.scheduling.enableDefaultPodAntiAffinity` | Enable default anti-affinity in replication mode | `true` |
| `replication.scheduling.enableDefaultTopologySpread` | Enable default topology spread in replication mode | `true` |
| `standalone.persistence.enabled` | Enable PVC for standalone | `true` |
| `replication.readReplicas.replicaCount` | Number of async read replicas | `2` |
| `metrics.enabled` | Enable `postgres_exporter` sidecar | `false` |
| `metrics.resourcesPreset` | Resource preset for `postgres_exporter` | `none` |
| `metrics.serviceMonitor.enabled` | Enable ServiceMonitor | `false` |
| `pdb.enabled` | Enable PodDisruptionBudget | `false` |
| `serviceAccount.automountServiceAccountToken` | Mount Kubernetes API credentials into PostgreSQL and backup pods | `false` |
| `service.ipFamilyPolicy` | Service IP family policy: `SingleStack`, `PreferDualStack`, or `RequireDualStack` | omitted |
| `service.ipFamilies` | Ordered Service IP families: `IPv4`, `IPv6` | omitted |

## CI scenarios

The `ci/` scenarios validate the main chart behaviors:

- `standalone.yaml`
- `replication.yaml`
- `initdb.yaml`
- `initdb-custom-only.yaml`
- `existing-secret.yaml`
- `external-secrets.yaml`
- `metrics.yaml`
- `existing-configmap.yaml`
- `replication-metrics.yaml`
- `scheduling.yaml`
- `tls.yaml`
- `tls-networkpolicy.yaml`
- `config-preset.yaml`
- `structured-pghba.yaml`
- `resources-preset.yaml`
- `replication-recovery-check.yaml`
- `replication-wal-tuning.yaml`
- `production-hardening.yaml`

## Examples

See `examples/`:

- `standalone.yaml`
- `replication.yaml`
- `initdb-metrics.yaml`
- `tls.yaml`
- `structured-config.yaml`
- `resources-preset.yaml`
- `external-secrets.yaml`
- `replication-production.yaml`
- `production.yaml`

## Important notes

- `replication` here is asynchronous replication with one fixed writable primary
- this chart does not implement automatic primary election
- init scripts run only on first initialization of a fresh data directory
- for failover-oriented production operations, use an operator instead of trying to turn this chart into one

<!-- @AI-METADATA
type: chart-readme
title: PostgreSQL Helm Chart
description: PostgreSQL chart with standalone/replication, TLS, metrics, resource presets

keywords: postgresql, postgres, database, replication, sql

purpose: Usage guide for the PostgreSQL Helm chart with standalone and replication modes
scope: Chart

relations:
  - charts/postgresql/DESIGN.md
  - charts/postgresql/docs/standalone.md
  - charts/postgresql/docs/replication.md
  - charts/postgresql/docs/backup-restore.md
path: charts/postgresql/README.md
version: 1.0
date: 2026-03-31
-->
