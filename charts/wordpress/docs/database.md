---
title: WordPress Database Modes
description: Guide for configuring WordPress database using MySQL subchart or external database
keywords: [wordpress, mysql, mariadb, database, helm]
scope: chart-docs
audience: users, operators
---

# Database Modes

WordPress requires MySQL or MariaDB. This chart supports two database modes with automatic detection.

## Mode Detection

When `database.mode` is `auto` (default), the chart detects the database source:

1. **External** — if `database.external.host` or `database.external.existingSecret` is set
2. **MySQL subchart** — if `mysql.enabled: true`
3. **Fail** — WordPress cannot run without a database

You can also set `database.mode` explicitly to `external` or `mysql` to skip auto-detection.

## MySQL Subchart (Default)

The chart includes a MySQL subchart dependency from HelmForge. This is the simplest setup:

```yaml
mysql:
  enabled: true
  auth:
    database: wordpress
    username: wordpress
    password: "my-password"
  primary:
    persistence:
      enabled: true
      size: 8Gi
```

The subchart creates a MySQL StatefulSet with its own PVC. WordPress connects to `<release>-mysql:3306` automatically.

For production, use existing secrets:

```yaml
mysql:
  enabled: true
  auth:
    database: wordpress
    username: wordpress
    existingSecret: wordpress-mysql
```

## External Database

Connect to an existing MySQL or MariaDB instance:

```yaml
mysql:
  enabled: false

database:
  external:
    host: db.example.com
    port: 3306
    name: wordpress
    username: wordpress
    password: "my-password"
```

With existing secret:

```yaml
mysql:
  enabled: false

database:
  external:
    host: db.example.com
    name: wordpress
    username: wordpress
    existingSecret: wordpress-db
    existingSecretPasswordKey: password
```

## Wait-for-DB Init Container

The deployment includes a `wait-for-db` init container that checks database connectivity before starting WordPress. This prevents CrashLoopBackOff when the database takes time to initialize (common with the MySQL subchart on first install).

The init container uses `busybox nc` to verify TCP connectivity to the database host and port.

<!-- @AI-METADATA
type: chart-docs
title: WordPress Database Modes
description: Guide for configuring WordPress database using MySQL subchart or external database
keywords: wordpress, mysql, mariadb, database, helm
purpose: Database configuration guide for the wordpress Helm chart
scope: Chart
relations:
  - charts/wordpress/README.md
  - charts/wordpress/values.yaml
path: charts/wordpress/docs/database.md
version: 1.0
date: 2026-03-23
-->
