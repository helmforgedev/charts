# Database Configuration

n8n supports three database backends: **SQLite** (default), **PostgreSQL**, and **MySQL**.

## Database Mode Detection

The chart uses automatic mode detection (`database.mode: auto`):

| Priority | Condition | Result |
|----------|-----------|--------|
| 1 | `database.external.host` or `database.external.existingSecret` | External database |
| 2 | `postgresql.enabled: true` | PostgreSQL subchart |
| 3 | `mysql.enabled: true` | MySQL subchart |
| 4 | None of the above | SQLite (default) |

## SQLite (Default)

Zero configuration required. Data is stored in `/home/node/.n8n/database.sqlite`.

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

## MySQL Subchart

```yaml
mysql:
  enabled: true
  auth:
    database: n8n
    username: n8n
    password: "strong-password"
```

## External Database

```yaml
database:
  external:
    vendor: postgres   # or mysql
    host: db.example.com
    name: n8n
    username: n8n
    existingSecret: n8n-db-credentials
```

The secret must contain a key named `database-password` (configurable via `existingSecretPasswordKey`).

<!-- @AI-METADATA
type: chart-docs
title: Database Configuration
description: Guide for configuring SQLite, PostgreSQL, or MySQL with the n8n Helm chart

keywords: database, sqlite, postgresql, mysql, external, subchart, configuration

purpose: Help operators choose and configure the right database backend
scope: Chart

relations:
  - charts/n8n/README.md
  - charts/n8n/values.yaml
path: charts/n8n/docs/database.md
version: 1.0
date: 2026-03-23
-->
