# Database Configuration

Apache Answer supports three database backends: **SQLite** (default), **PostgreSQL**, and **MySQL**.

## Database Mode Detection

The chart uses automatic mode detection (`database.mode: auto`):

| Priority | Condition | Result |
|----------|-----------|--------|
| 1 | `database.external.host` or `database.external.existingSecret` | External database |
| 2 | `postgresql.enabled: true` | PostgreSQL subchart |
| 3 | `mysql.enabled: true` | MySQL subchart |
| 4 | None of the above | SQLite (default) |

Set `database.mode` explicitly to override auto-detection.

## SQLite (Default)

Zero configuration required. Data is stored in `/data/answer.db` inside the persistent volume.

```yaml
# No database configuration needed — SQLite is the default
persistence:
  enabled: true
  size: 5Gi
```

SQLite is suitable for small teams and evaluation. For production with higher concurrency, use PostgreSQL or MySQL.

## PostgreSQL Subchart

```yaml
postgresql:
  enabled: true
  auth:
    database: answer
    username: answer
    password: "strong-password"
  primary:
    persistence:
      size: 20Gi
```

## MySQL Subchart

```yaml
mysql:
  enabled: true
  auth:
    database: answer
    username: answer
    password: "strong-password"
  primary:
    persistence:
      size: 20Gi
```

## External Database

Connect to an existing PostgreSQL or MySQL instance:

```yaml
database:
  external:
    vendor: postgres   # or mysql
    host: db.example.com
    name: answer
    username: answer
    existingSecret: answer-db-credentials
```

The secret must contain a key named `database-password` (configurable via `existingSecretPasswordKey`).

<!-- @AI-METADATA
type: chart-docs
title: Database Configuration
description: Guide for configuring SQLite, PostgreSQL, or MySQL with the Apache Answer Helm chart

keywords: database, sqlite, postgresql, mysql, external, subchart, configuration

purpose: Help operators choose and configure the right database backend
scope: Chart

relations:
  - charts/answer/README.md
  - charts/answer/values.yaml
path: charts/answer/docs/database.md
version: 1.0
date: 2026-03-23
-->
