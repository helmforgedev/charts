---
title: Strapi Database Modes
description: Guide for configuring Strapi with SQLite, PostgreSQL, or MySQL in the HelmForge chart
keywords: [strapi, sqlite, postgresql, mysql, database, helm]
scope: chart-docs
audience: users, operators
---

# Strapi Database Modes

The Strapi chart supports three database strategies:

1. SQLite for simple environments
2. PostgreSQL with a bundled or external server
3. MySQL with a bundled or external server

## Mode Detection

When `database.mode=auto`, the chart chooses the database in this order:

1. `database.external.host` or `database.external.existingSecret` -> external database
2. `postgresql.enabled=true` -> PostgreSQL subchart
3. `mysql.enabled=true` -> MySQL subchart
4. fallback -> SQLite

If more than one mode is configured at the same time, rendering fails early.

## SQLite

SQLite is the default because it keeps the first install small and self-contained.

```yaml
database:
  mode: sqlite
```

In SQLite mode, the chart mounts the PVC to:

- uploads: `persistence.uploads.mountPath`
- database: `database.sqlite.directory`

The database file path exported to Strapi is:

```text
DATABASE_FILENAME=<database.sqlite.directory>/<database.sqlite.filename>
```

SQLite is practical for local labs and small internal instances, but a server-based database is the safer production path.

## PostgreSQL Subchart

Enable the bundled PostgreSQL dependency when you want a single Helm release:

```yaml
postgresql:
  enabled: true
  auth:
    database: strapi
    username: strapi
    password: "strong-password"
```

The chart automatically wires:

- `DATABASE_CLIENT=postgres`
- `DATABASE_HOST=<release>-postgresql`
- `DATABASE_PORT=5432`

## MySQL Subchart

Enable the bundled MySQL dependency when MySQL fits your environment better:

```yaml
mysql:
  enabled: true
  auth:
    database: strapi
    username: strapi
    password: "strong-password"
```

The chart automatically wires:

- `DATABASE_CLIENT=mysql`
- `DATABASE_HOST=<release>-mysql`
- `DATABASE_PORT=3306`

## External Database

Use an external database when backup, HA, or shared platform ownership already exist outside the chart:

```yaml
database:
  mode: external
  external:
    vendor: postgres
    host: db.example.com
    port: 5432
    name: strapi
    username: strapi
    existingSecret: strapi-db-credentials
```

Supported vendors:

- `postgres`
- `mysql`

If `port` is omitted, the chart defaults to `5432` for PostgreSQL and `3306` for MySQL.

## Existing Secrets

For external databases, the password can come from an existing secret:

```yaml
database:
  external:
    existingSecret: strapi-db-credentials
    existingSecretPasswordKey: database-password
```

For bundled PostgreSQL or MySQL, the chart creates a release-scoped database secret unless the subchart values already provide a password.

## Operational Guidance

- use SQLite only when you explicitly accept single-node local storage behavior
- prefer PostgreSQL for most production Strapi workloads
- use `database.mode=external` when the database lifecycle is managed by another team or platform
- keep uploads persistence enabled even with an external database unless your Strapi project already uses object storage

<!-- @AI-METADATA
type: chart-docs
title: Strapi Database Modes
description: Guide for configuring Strapi with SQLite, PostgreSQL, or MySQL in the HelmForge chart

keywords: strapi, sqlite, postgresql, mysql, database, helm

purpose: Explain supported database modes, auto-detection, and operational tradeoffs for the Strapi chart
scope: Chart

relations:
  - charts/strapi/README.md
  - charts/strapi/values.yaml
path: charts/strapi/docs/database.md
version: 1.0
date: 2026-03-29
-->
