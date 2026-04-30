# MariaDB Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/helmforge)](https://artifacthub.io/packages/search?repo=helmforge)

Helm chart for deploying [MariaDB](https://mariadb.org/) on Kubernetes using the official [`mariadb`](https://hub.docker.com/_/mariadb) Docker image. Supports standalone and GTID-based replication architectures.

## Supported Architectures

| Architecture | Description |
|---|---|
| **standalone** | Single MariaDB instance with persistent storage (default) |
| **replication** | One fixed source with asynchronous GTID-based read replicas |

## Features

- **Official MariaDB image** from Docker Hub
- **Standalone and replication** modes with explicit configuration
- **GTID-based replication** using MariaDB-native GTID (`MASTER_USE_GTID=slave_pos`)
- **Configuration presets** small, medium, large, oltp, read-heavy, analytics
- **Resource presets** small, medium, large for easy right-sizing
- **Init scripts** support via ConfigMap or inline values
- **TLS** server-side encryption with optional client enforcement
- **Prometheus metrics** via mysqld-exporter sidecar and ServiceMonitor
- **S3-compatible backup** CronJob with mariadb-dump and minio/mc upload
- **NetworkPolicy** for ingress traffic control
- **PodDisruptionBudget** for availability during maintenance
- **Password management** auto-generated or from existing Secret
- **Dual-stack networking** — IPv4/IPv6 service support across all 6 Service objects
- **External Secrets Operator** — ExternalSecret for Vault, AWS Secrets Manager, and more

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install mariadb helmforge/mariadb
```

### OCI Registry

```bash
helm install mariadb oci://ghcr.io/helmforgedev/helm/mariadb
```

## Architecture Selection

```yaml
# Standalone (default)
architecture: standalone

# Replication with 2 read replicas
architecture: replication
replication:
  readReplicas:
    replicaCount: 2
```

## Main Values

| Key | Default | Description |
|-----|---------|-------------|
| `architecture` | `standalone` | Deployment mode: standalone or replication |
| `image.repository` | `mariadb` | MariaDB image |
| `image.tag` | `11.4` | MariaDB version (LTS) |
| `auth.rootPassword` | `""` | Root password (auto-generated if empty) |
| `auth.database` | `app` | Application database |
| `auth.username` | `app` | Application user |
| `auth.password` | `""` | Application password (auto-generated if empty) |
| `auth.replicationUsername` | `replicator` | Replication user |
| `auth.existingSecret` | `""` | Existing secret with passwords |
| `config.preset` | `none` | Configuration preset |
| `config.myCnf` | `""` | Extra my.cnf content |
| `standalone.persistence.size` | `8Gi` | Standalone PVC size |
| `replication.source.persistence.size` | `20Gi` | Source PVC size |
| `replication.readReplicas.replicaCount` | `2` | Number of read replicas |
| `replication.readReplicas.persistence.size` | `20Gi` | Replica PVC size |
| `replication.binlog.format` | `ROW` | Binlog format |
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `3306` | MariaDB port |
| `metrics.enabled` | `false` | Enable mysqld-exporter |
| `tls.enabled` | `false` | Enable server TLS |
| `backup.enabled` | `false` | Enable S3 backup CronJob |
| `backup.schedule` | `"0 3 * * *"` | Backup cron schedule |
| `networkPolicy.enabled` | `false` | Enable NetworkPolicy |
| `pdb.enabled` | `false` | Enable PodDisruptionBudget |
| `service.ipFamilyPolicy` | `~` | IP family policy (`SingleStack`, `PreferDualStack`, `RequireDualStack`) |
| `service.ipFamilies` | `[]` | IP families override (`IPv4`, `IPv6`) |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resource |
| `externalSecrets.apiVersion` | `external-secrets.io/v1` | ExternalSecret API version |
| `externalSecrets.refreshInterval` | `1h` | Refresh interval |
| `externalSecrets.secretStoreRef.name` | `""` | SecretStore name (required when enabled) |
| `externalSecrets.secretStoreRef.kind` | `SecretStore` | SecretStore kind |
| `externalSecrets.data` | `[]` | Remote key mappings |

## Dual-Stack Services

All 6 Service objects (client, metrics, source, source-metrics, replicas, replicas-metrics)
carry the same `ipFamilyPolicy` and `ipFamilies` settings.

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

## External Secrets Operator (ESO)

`auth.existingSecret` is required alongside `externalSecrets.enabled=true` to prevent
credential drift between the chart-managed Secret and the ExternalSecret.

```yaml
auth:
  existingSecret: mariadb-credentials

externalSecrets:
  enabled: true
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  data:
    - secretKey: mariadb-root-password
      remoteRef:
        key: mariadb/credentials
        property: root-password
    - secretKey: mariadb-user-password
      remoteRef:
        key: mariadb/credentials
        property: user-password
```

## Differences from MySQL Chart

This chart uses MariaDB-native features:

- **GTID replication** uses `MASTER_USE_GTID=slave_pos` (MariaDB GTID is always enabled, no `gtid_mode` toggle)
- **Commands** use `mariadb`, `mariadb-admin`, `mariadb-dump` (not `mysql`, `mysqladmin`, `mysqldump`)
- **Environment variables** use `MARIADB_*` prefix (not `MYSQL_*`)
- **Replication** uses `CHANGE MASTER TO` with MariaDB-specific options
- **No mysqlx** protocol (MySQL-specific)

## CI Scenarios

| File | Description |
|------|-------------|
| `standalone.yaml` | Basic standalone mode |
| `replication.yaml` | Replication with 2 replicas |
| `initdb.yaml` | Init scripts with example table |
| `existing-secret.yaml` | External secret reference |
| `metrics.yaml` | Metrics sidecar enabled |
| `replication-metrics.yaml` | Replication with metrics |
| `config-preset.yaml` | OLTP config preset |
| `resources-preset.yaml` | Resource presets for replication |
| `tls.yaml` | TLS with existingSecret |
| `tls-networkpolicy.yaml` | TLS + replication + NetworkPolicy |
| `backup.yaml` | Backup with S3 |
| `dual-stack.yaml` | Dual-stack IPv4/IPv6 services |
| `external-secrets.yaml` | External Secrets Operator integration |

## More Information

- [MariaDB documentation](https://mariadb.com/kb/en/)
- [Chart source](https://github.com/helmforgedev/charts/tree/main/charts/mariadb)

<!-- @AI-METADATA
type: chart-readme
title: MariaDB Helm Chart
description: MariaDB with standalone and GTID-based replication modes, TLS, metrics, backup, and configuration presets

keywords: mariadb, database, replication, gtid, backup, dual-stack, external-secrets

purpose: Chart README with install, config, architecture, and values reference
scope: Chart

relations:
  - charts/mariadb/values.yaml
  - charts/mysql/README.md
path: charts/mariadb/README.md
version: 1.0
date: 2026-04-30
-->
