# Homarr Database and Backup Modes

## Auto Detection

When `database.mode=auto`, the chart chooses a database in this order:

1. external database when `database.external.host` or `database.external.existingSecret` is set
2. bundled PostgreSQL when `postgresql.enabled=true`
3. bundled MySQL when `mysql.enabled=true`
4. SQLite when no database backend is configured

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

## Bundled MySQL

```yaml
database:
  mode: mysql

mysql:
  enabled: true
  auth:
    database: homarr
    username: homarr
    password: "change-me"
    rootPassword: "change-root"
```

Use MySQL when it better matches your platform standards or migration plan.

The chart disables Homarr's internal DNS cache by default (`homarr.enableDnsCaching=false`) so MySQL and other Kubernetes
Services are resolved through cluster DNS during startup and background jobs. Local k3d validation showed this prevents a
transient Homarr `sessionCleanup` connection timeout with the bundled MySQL Service. The chart also delays the bundled
MySQL startup probe to avoid first-boot Warning events on slower nodes.

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
- MySQL uses `mysqldump`

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

<!-- @AI-METADATA
type: chart-doc
title: Homarr Database and Backup Modes
description: Database and backup guide for the Homarr Helm chart

keywords: homarr, sqlite, postgresql, mysql, backup, restore, helm, kubernetes

purpose: Explain database selection, bundled and external database modes, and backup behavior
scope: Chart Documentation

relations:
  - charts/homarr/README.md
  - charts/homarr/DESIGN.md
path: charts/homarr/docs/database.md
version: 1.0
date: 2026-06-02
-->
