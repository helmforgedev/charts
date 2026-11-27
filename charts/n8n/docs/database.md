# Database Configuration

n8n supports two database backends: **SQLite** (default) and **PostgreSQL**.

## Database Mode Detection

The chart uses automatic mode detection (`database.mode: auto`):

External and bundled PostgreSQL settings are mutually exclusive. Configuring
both is rejected; the chart never chooses one database over another silently.

| Priority | Condition | Result |
|----------|-----------|--------|
| 1 | `database.external.host` or `database.external.existingSecret` | External database |
| 2 | `postgresql.enabled: true` | PostgreSQL subchart |
| 3 | None of the above | SQLite (default) |

## SQLite (Default)

Zero configuration required. Data is stored in `/home/node/.n8n/database.sqlite`.

The single-replica main Deployment uses `Recreate` updates in every database
mode so the previous n8n revision stops before its replacement runs migrations.
This avoids old and new application versions sharing SQLite, PostgreSQL, or a
`ReadWriteOnce` data volume during an upgrade. Plan for brief downtime and keep
a recoverable database and data-volume backup. `Recreate` applies only to main
pods. In queue mode, drain and stop the separate worker Deployment before an
upgrade with incompatible migrations. Set `queue.workers=0` in the upgrade that
deploys the new main version and wait for every worker pod to terminate. Manual
scaling is insufficient because Helm reapplies the configured worker count.
After the new main pod is ready, run a second Helm upgrade with the intended
`queue.workers` value.

```yaml
persistence:
  enabled: true
  size: 5Gi
```

SQLite is suitable for single-user or small-team setups. For production with queue mode or higher concurrency, use PostgreSQL.

## PostgreSQL Subchart

```yaml
postgresql:
  enabled: true
  auth:
    database: n8n
    username: n8n
    password: "strong-password"
```

## MySQL and MariaDB storage migration

n8n removed MySQL/MariaDB storage in version 2.0. Earlier chart releases still
exposed these unsupported options. This chart now rejects `mysql.enabled=true`,
`database.mode=mysql` and non-PostgreSQL external vendors, and no longer bundles
MySQL or MySQL backup jobs. The MySQL workflow node is unaffected.

If an older deployment uses MySQL/MariaDB, stop here and migrate its data using
the upstream migration procedure on a compatible source release. Back up the
database and encryption key, migrate into a separate PostgreSQL instance, and
verify credentials, workflows and executions before switching traffic. Changing
`database.mode` alone does not migrate data. Do not apply this release over an
existing bundled MySQL installation until its data has been migrated and its
backup and PVC recovery have been verified.

See the [2.0 storage migration guidance](https://github.com/n8n-io/n8n-docs/blob/main/docs/changelog/v20-breaking-changes.md)
and [upstream releases](https://github.com/n8n-io/n8n/releases).

## External Database

```yaml
database:
  external:
    vendor: postgres
    host: db.example.com
    name: n8n
    username: n8n
    existingSecret: n8n-db-credentials
```

The secret must contain a key named `database-password` (configurable via `existingSecretPasswordKey`).

<!-- @AI-METADATA
type: chart-docs
title: Database Configuration
description: Guide for configuring SQLite or PostgreSQL with the n8n Helm chart

keywords: database, sqlite, postgresql, external, subchart, configuration

purpose: Help operators choose and configure the right database backend
scope: Chart

relations:
  - charts/n8n/README.md
  - charts/n8n/values.yaml
path: charts/n8n/docs/database.md
version: 1.0
date: 2026-03-23
-->
