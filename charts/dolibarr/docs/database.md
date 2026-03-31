# Dolibarr Database Modes

Dolibarr requires a relational database. This chart intentionally supports two Kubernetes-friendly paths:

- **MySQL subchart** — the default path, using the bundled HelmForge MySQL chart
- **External MySQL/MariaDB** — for operators that already manage the database lifecycle elsewhere

## Default: Bundled MySQL

The default configuration deploys Dolibarr with the HelmForge `mysql` dependency:

```yaml
mysql:
  enabled: true
  auth:
    password: "change-me"
```

This is the recommended starting point for evaluation environments and simple self-hosted deployments.

## External MySQL or MariaDB

To connect Dolibarr to an existing database:

```yaml
mysql:
  enabled: false

database:
  mode: external
  external:
    host: mariadb.example.com
    port: 3306
    name: dolibarr
    username: dolibarr
    existingSecret: dolibarr-db
    existingSecretPasswordKey: password
```

The referenced secret must contain the database password key.

## Why This Chart Does Not Support PostgreSQL

Dolibarr itself can work with PostgreSQL, but the official Docker workflow treats that path differently and may require interactive installation or upgrade handling through `/install`. For this chart, the supported automation contract is MySQL/MariaDB only, because it aligns with the official container's unattended setup flow and with the repository's existing database dependency patterns.

## Operational Notes

- keep either `mysql.enabled=true` or `database.mode=external`, never both
- use `database.external.ssl=true` when your external database requires TLS
- the app waits for TCP connectivity to the database before starting
- the generated database secret is preserved across upgrades through `lookup`

<!-- @AI-METADATA
type: chart-docs
title: Dolibarr - Database Modes
description: Database configuration guide for the Dolibarr Helm chart

keywords: dolibarr, mysql, mariadb, database, external, subchart

purpose: Explain the supported database modes and their operational tradeoffs
scope: Chart

relations:
  - charts/dolibarr/README.md
path: charts/dolibarr/docs/database.md
version: 1.0
date: 2026-03-31
-->
