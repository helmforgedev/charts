# Database Configuration

Apache Guacamole requires a relational database for authentication and connection storage. The chart supports PostgreSQL (default) and MySQL via HelmForge subcharts or external databases.

## PostgreSQL Subchart (Default)

```yaml
postgresql:
  enabled: true
  auth:
    database: guacamole_db
    username: guacamole_user
    password: "strong-password"
```

## MySQL Subchart

```yaml
database:
  type: mysql

postgresql:
  enabled: false

mysql:
  enabled: true
  auth:
    database: guacamole_db
    username: guacamole_user
    password: "strong-password"
```

## External Database

```yaml
postgresql:
  enabled: false

database:
  type: postgresql
  external:
    host: db.example.com
    port: "5432"
    name: guacamole_db
    username: guacamole_user
    password: "strong-password"
```

Or using an existing secret:

```yaml
database:
  type: postgresql
  external:
    host: db.example.com
    name: guacamole_db
    username: guacamole_user
    existingSecret: guacamole-db-credentials
    existingSecretPasswordKey: password
```

## Database Initialization

The chart includes a post-install Job (`initdb-job`) that:

1. Waits for the database to be reachable
2. Generates the schema SQL using Guacamole's built-in `initdb.sh` script
3. Checks if the schema already exists (idempotent)
4. Applies the schema if needed

Set `initDb.enabled: false` to skip automatic initialization (useful with external databases that already have the schema).

<!-- @AI-METADATA
type: chart-docs
title: Guacamole Database Configuration
description: Database setup guide for Apache Guacamole chart
keywords: guacamole, postgresql, mysql, database, external
purpose: Document database configuration options and initialization
scope: Chart
relations:
  - charts/guacamole/README.md
  - charts/guacamole/values.yaml
path: charts/guacamole/docs/database.md
version: 1.0
date: 2026-03-23
-->
