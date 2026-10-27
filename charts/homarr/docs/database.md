# Homarr Database and Backup Modes

## Auto Detection

When `database.mode=auto`, the chart chooses a database in this order:

1. external database when `database.external.host` or `database.external.existingSecret` is set
2. bundled PostgreSQL when `postgresql.enabled=true`
3. SQLite when no database backend is configured

Only one database backend should be enabled at a time.

## SQLite

SQLite is the default and stores data under `/appdata`:

```yaml
database:
  mode: sqlite

persistence:
  enabled: true
  size: 1Gi
```

Use SQLite for simple single-replica dashboards. Do not use it for multi-replica deployments.

## Bundled PostgreSQL

```yaml
database:
  mode: postgresql

postgresql:
  enabled: true
  auth:
    database: homarr
    username: homarr
    password: "change-me"
```

The chart includes bootstrap grants and a pre-upgrade hook that reapplies ownership and `CREATE` permissions for existing
bundled PostgreSQL databases.

Legacy `postgresql.primary.*` values from older dependency layouts are not
accepted when the bundled PostgreSQL subchart is enabled. Move those overrides to
`postgresql.standalone.*` before upgrading.

## External Database

```yaml
database:
  mode: external
  external:
    vendor: postgres
    host: postgres.example.com
    port: "5432"
    name: homarr
    username: homarr
    existingSecret: homarr-db
    existingSecretPasswordKey: database-password
```

External databases must already provide the permissions Homarr needs to create and migrate its schema.

## Backup

The backup CronJob is database-aware:

- SQLite archives `/appdata`
- PostgreSQL uses `pg_dump`

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.example.com
    bucket: homarr-backups
    existingSecret: homarr-s3
```

Test restore procedures before relying on backups for production recovery.

## Migrating Historical MySQL Installations

Homarr v2.6.0 supports SQLite and PostgreSQL only. Before upgrading an older
release that used bundled or external MySQL, use Homarr's official
[MySQL-to-SQLite converter](https://homarr.dev/docs/advanced/mysql-to-sqlite/),
deploy the converted SQLite database, and validate it with the target Homarr
version before completing the chart upgrade. The converter does not write
PostgreSQL data. Selecting PostgreSQL afterward requires a separate,
operator-controlled and validated data migration. The chart does not run either
migration automatically because each changes the storage engine and requires a
backup and verification point.

<!-- @AI-METADATA
type: chart-doc
title: Homarr Database and Backup Modes
description: Database and backup guide for the Homarr Helm chart

keywords: homarr, sqlite, postgresql, backup, restore, helm, kubernetes

purpose: Explain database selection, bundled and external database modes, and backup behavior
scope: Chart Documentation

relations:
  - charts/homarr/README.md
  - charts/homarr/DESIGN.md
path: charts/homarr/docs/database.md
version: 1.0
date: 2026-06-02
-->
