# MySQL

MySQL for Kubernetes with explicit `standalone` and `replication` modes, documented bootstrap behavior, optional init scripts, and optional metrics.

## Install

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install mysql helmforge/mysql -f values.yaml
```

### OCI registry

```bash
helm install mysql oci://ghcr.io/helmforgedev/helm/mysql -f values.yaml
```

## Supported architectures

| Architecture | When to use | Document |
|-------------|-------------|----------|
| `standalone` | development, simpler production environments, or workloads where one writable MySQL instance is acceptable | [docs/standalone.md](docs/standalone.md) |
| `replication` | one writable source plus asynchronous read replicas for read traffic and horizontal read scaling | [docs/replication.md](docs/replication.md) |

## What this chart covers

- explicit architecture selection through `architecture`
- MySQL on the official `mysql` image
- generated or externally-managed passwords through `existingSecret`
- application database and application user bootstrap on first initialization
- optional extra init scripts
- fixed-source asynchronous replication for read replicas
- role-aware readiness checks for source and replicas in replication mode
- optional metrics through `mysqld-exporter`
- optional `ServiceMonitor`
- built-in S3 backup CronJob using `mysqldump --all-databases`
- dedicated metrics Services separated from client traffic
- topology-specific Services for client traffic, source traffic, and read replicas

## How to choose the architecture

- use `standalone` when operational simplicity matters more than read scaling
- use `replication` when you need separate write and read endpoints, but you are not asking the chart to solve automatic failover

Recommended reading before installation:

- [Standalone](docs/standalone.md)
- [Replication](docs/replication.md)
- [Replication Operations](docs/replication-operations.md)
- [Backup and Restore](docs/backup-restore.md)
- [Secret Rotation](docs/secret-rotation.md)
- [Configuration Profiles](docs/configuration-profiles.md)

## Official product references

- MySQL replication: https://dev.mysql.com/doc/refman/8.4/en/replication.html
- MySQL encrypted connections: https://dev.mysql.com/doc/refman/8.4/en/using-encrypted-connections.html
- MySQL group replication: https://dev.mysql.com/doc/refman/8.4/en/group-replication.html
- MySQL official image: https://hub.docker.com/_/mysql

## Operational direction

- for production needing automatic failover, use an operator or another HA-specific solution instead of stretching this chart beyond its scope
- `replication` in this chart means one fixed source with asynchronous read replicas
- built-in logical backup to S3 is available for standalone and replication topologies

## Read traffic model

In `replication` mode, the chart exposes separate Services for different traffic patterns:

- the base client Service for general in-cluster access
- a dedicated source Service for write traffic
- a dedicated replicas Service for read-only traffic

The replicas Service is the endpoint to use for horizontal read scaling when an application or service can work against asynchronous read-only replicas.

Important limits:

- Kubernetes Service balancing distributes connections across available replicas, but it is not a MySQL-aware query router
- replica reads may lag behind the source because replication is asynchronous
- workloads that require immediate read-after-write consistency should stay on the source endpoint

## Quick start

Minimal standalone example:

```yaml
architecture: standalone

auth:
  existingSecret: mysql-auth

standalone:
  persistence:
    enabled: true
    size: 20Gi
```

Replication example:

```yaml
architecture: replication

auth:
  existingSecret: mysql-auth

replication:
  source:
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
- keep client access internal unless there is a strong reason to expose MySQL outside the cluster network
- enable `tls.enabled=true` with an externally-managed certificate secret when clients must use encrypted TCP connections
- use `tls.requireSecureTransport=true` only when your clients and replication flows are ready to use TLS
- use `networkPolicy.enabled=true` or external platform controls when possible
- if metrics are scraped through Prometheus, pair `networkPolicy.enabled=true` with `networkPolicy.metrics.enabled=true`
- rotate passwords through secret management workflows instead of editing values inline

### Replication and availability

- treat `replication` as read scaling and operational recovery help, not full HA
- place source and replicas across different nodes or zones when the cluster supports it
- use `pdb.enabled=true` when running multiple replicas and planning maintenance windows
- review the default replication PDB and placement behavior before overriding them globally
- consider `replication.readReplicas.probes.requireRunningReplication=true` for environments where replica readiness should confirm replication threads are healthy
- keep `startupProbe` conservative for MySQL, especially on larger volumes and replica catch-up paths

### Initialization

- use `initdb.scripts` for deterministic first-boot SQL or shell customization
- use `initdb.existingConfigMap` when scripts are already managed elsewhere
- remember that `docker-entrypoint-initdb.d` runs only during first initialization of a fresh data directory

### Observability

- enable `metrics.enabled=true` in monitored environments
- enable `metrics.serviceMonitor.enabled=true` when Prometheus Operator is available
- metrics are exposed through dedicated metrics Services, not through the client database Services
- monitor connection count, replica lag, disk growth, and binary log retention

### Configuration UX

- use `config.preset` for a small set of opinionated MySQL defaults
- use workload-oriented presets such as `oltp`, `read-heavy`, or `analytics` when the generic size presets are too vague
- keep `config.myCnf` for raw overrides when the preset is not enough
- keep `auth.database`, `auth.username`, and `auth.replicationUsername` as plain values; `existingSecret` is intentionally limited to sensitive runtime data

## Production notes

- use `auth.existingSecret` instead of inline passwords
- use `tls.existingSecret` for server certificates instead of trying to inline PEM material in values
- keep persistence enabled for every stateful topology
- define node placement rules for `replication`, especially when the cluster spans multiple nodes or zones
- use the `client` or `source` Service only for writes
- use the `replicas` Service only for read traffic
- use the `replicas` Service when you need horizontal scale for read-only workloads
- when enabling TLS, plan certificate rotation as a rollout event because mounted secrets are not hot-reloaded by mysqld
- built-in backup dumps all MySQL databases from the writable source endpoint and uploads the compressed archive to S3-compatible storage
- treat restore validation, retention policy, and failover as operational workflows that still require explicit runbooks
- review the architecture guides before promoting `replication` to production

Operational documents:

- [Replication Operations](docs/replication-operations.md)
- [Backup and Restore](docs/backup-restore.md)
- [Secret Rotation](docs/secret-rotation.md)
- [Configuration Profiles](docs/configuration-profiles.md)

## Main values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `architecture` | `standalone` or `replication` | `standalone` |
| `image.repository` | MySQL image repository | `mysql` |
| `image.tag` | MySQL image tag | `8.4` |
| `auth.database` | App database created at bootstrap | `app` |
| `auth.username` | App user created at bootstrap | `app` |
| `auth.existingSecret` | Existing secret for passwords | `""` |
| `auth.replicationUsername` | Replication username | `replicator` |
| `config.preset` | Optional MySQL config preset | `none` |
| `standalone.resourcesPreset` | Standalone resource preset | `none` |
| `replication.source.resourcesPreset` | Source resource preset | `none` |
| `replication.readReplicas.resourcesPreset` | Replica resource preset | `none` |
| `metrics.resourcesPreset` | Exporter resource preset | `none` |
| `initdb.existingConfigMap` | External ConfigMap for extra init scripts | `""` |
| `networkPolicy.enabled` | Enable ingress-only NetworkPolicy | `false` |
| `networkPolicy.metrics.enabled` | Allow metrics scraping through NetworkPolicy | `false` |
| `tls.enabled` | Enable server TLS from an existing secret | `false` |
| `tls.existingSecret` | Existing secret with CA, certificate, and key | `""` |
| `tls.requireSecureTransport` | Require TLS for TCP client connections | `false` |
| `tls.client.enabled` | Use TLS for chart-managed TCP clients | `false` |
| `tls.client.sslMode` | MySQL CLI SSL mode for internal chart-managed clients | `REQUIRED` |
| `backup.enabled` | Enable built-in S3 backup CronJob | `false` |
| `backup.schedule` | Backup schedule | `"0 3 * * *"` |
| `backup.s3.endpoint` | S3-compatible endpoint URL | `""` |
| `backup.s3.bucket` | Target bucket name | `""` |
| `backup.database.mysqldumpArgs` | Extra `mysqldump` flags used before `--all-databases` | `"--single-transaction --quick --skip-lock-tables --no-tablespaces --routines --events --triggers"` |
| `livenessProbe.enabled` | Enable livenessProbe | `true` |
| `readinessProbe.enabled` | Enable readinessProbe | `true` |
| `startupProbe.enabled` | Enable startupProbe | `true` |
| `replication.source.probes.requireWritable` | Require source readiness to confirm writable state | `true` |
| `replication.readReplicas.probes.requireReadOnly` | Require replica readiness to confirm read-only state | `true` |
| `replication.readReplicas.probes.requireRunningReplication` | Require replica readiness to confirm replication threads are running | `false` |
| `replication.binlog.format` | Binlog format used by the source | `ROW` |
| `replication.binlog.retentionDays` | Binlog retention in days | `7` |
| `replication.pdb.enabled` | Enable replication PDB by default | `true` |
| `replication.scheduling.enableDefaultPodAntiAffinity` | Enable default anti-affinity in replication mode | `true` |
| `replication.scheduling.enableDefaultTopologySpread` | Enable default topology spread in replication mode | `true` |
| `replication.replicaTuning.parallelWorkers` | Parallel applier workers on replicas | `4` |
| `standalone.persistence.enabled` | Enable PVC for standalone | `true` |
| `replication.readReplicas.replicaCount` | Number of async read replicas | `2` |
| `metrics.enabled` | Enable `mysqld-exporter` sidecar | `false` |
| `metrics.serviceMonitor.enabled` | Enable ServiceMonitor | `false` |

## CI scenarios

The `ci/` scenarios validate the main chart behaviors:

- `standalone.yaml`
- `replication.yaml`
- `initdb.yaml`
- `existing-secret.yaml`
- `metrics.yaml`
- `existing-configmap.yaml`
- `replication-metrics.yaml`
- `replication-recovery-check.yaml`
- `replication-binlog-tuning.yaml`
- `config-preset.yaml`
- `resources-preset.yaml`
- `tls.yaml`
- `tls-networkpolicy.yaml`

## Examples

See `examples/`:

- `standalone.yaml`
- `replication.yaml`
- `initdb-metrics.yaml`
- `config-preset.yaml`
- `resources-preset.yaml`
- `tls.yaml`
- `replication-production.yaml`

## Important notes

- `replication` here is asynchronous replication with one fixed writable source
- this chart does not implement automatic source promotion
- init scripts run only on first initialization of a fresh data directory
- for failover-oriented production operations, use an operator or dedicated HA solution instead of trying to turn this chart into one

<!-- @AI-METADATA
type: chart-readme
title: MySQL Helm Chart
description: MySQL chart with standalone and replication modes, TLS, metrics

keywords: mysql, database, replication, sql, tls

purpose: Usage guide for the MySQL Helm chart with standalone and replication modes
scope: Chart

relations:
  - charts/mysql/DESIGN.md
  - charts/mysql/docs/standalone.md
  - charts/mysql/docs/replication.md
  - charts/mysql/docs/backup-restore.md
path: charts/mysql/README.md
version: 1.0
date: 2026-03-31
-->
