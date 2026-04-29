# Backup and Restore

## Scope

This chart includes an optional backup CronJob for database-backed Keycloak deployments.

Supported backup targets:

- external PostgreSQL
- external MySQL or MariaDB
- PostgreSQL subchart
- MySQL subchart

Embedded H2 is intentionally excluded from built-in backup support.

## Built-in backup behavior

When `backup.enabled=true`, the chart:

- detects the active Keycloak database vendor
- runs `pg_dump` for PostgreSQL or `mysqldump` for MySQL-compatible databases
- compresses the dump
- uploads the archive to S3-compatible storage

The built-in workflow is intentionally focused on backup creation, not restore orchestration.

## Backup scope

Keycloak stores its operational state in the configured database. The built-in backup job is therefore database-only by design.

The chart does not package or back up external inputs such as:

- custom provider JARs mounted from a ConfigMap or Secret
- custom themes mounted from a ConfigMap or Secret
- realm import files managed by GitOps or another source-of-truth
- TLS, truststore, database, S3, or External Secrets backend material

Keep those inputs in their own source-of-truth and backup workflow. A database dump is not enough to reconstruct an environment that depends on external provider, theme, truststore, or secret material.

## On-demand backup

The chart creates a CronJob. To execute the same backup flow immediately, create a Job from the CronJob:

```bash
kubectl create job keycloak-backup-manual \
  --from=cronjob/<release-name>-keycloak-backup \
  -n <namespace>

kubectl wait --for=condition=Complete job/keycloak-backup-manual \
  -n <namespace> \
  --timeout=15m

kubectl logs job/keycloak-backup-manual \
  -n <namespace> \
  --all-containers
```

Inspect the S3-compatible target after the Job completes and verify that the compressed SQL archive exists under the configured `backup.s3.prefix`.

## Operational recommendation

- use PostgreSQL for production whenever possible
- keep Keycloak database backup frequency aligned with realm and user-change volume
- validate restore procedures in a non-production environment before declaring the deployment production-ready
- if extensions, themes, or realm-import inputs are managed outside the database, back them up through their own source-of-truth workflow as well

## Restore workflow

Prefer restoring into a fresh release or a maintenance window with Keycloak traffic stopped.

### 1. Download the archive

PostgreSQL example:

```bash
mc cp backup/keycloak-backups/keycloak/keycloak-postgresql-20260331T163305Z.sql.gz /tmp/
gzip -dc /tmp/keycloak-postgresql-20260331T163305Z.sql.gz > /tmp/keycloak-restore.sql
```

MySQL example:

```bash
mc cp backup/keycloak-backups/keycloak/keycloak-mysql-20260331T163305Z.sql.gz /tmp/
gzip -dc /tmp/keycloak-mysql-20260331T163305Z.sql.gz > /tmp/keycloak-restore.sql
```

### 2. Restore into the Keycloak database

PostgreSQL:

```bash
psql \
  --host <postgres-host> \
  --port 5432 \
  --username <keycloak-db-user> \
  --dbname <keycloak-db-name> \
  --file /tmp/keycloak-restore.sql
```

MySQL:

```bash
mysql \
  --host <mysql-host> \
  --port 3306 \
  --user <keycloak-db-user> \
  --password \
  <keycloak-db-name> < /tmp/keycloak-restore.sql
```

### 3. Validate before reopening traffic

- restore into a controlled maintenance workflow
- verify Keycloak startup, admin login, and expected realms/clients before reopening traffic
- validate users, identity providers, and critical client secrets expected by the environment
- if themes, providers, or realm-import files are managed outside the database, restore those inputs independently before validation
- re-enable scheduled backups only after the restored environment is validated

<!-- @AI-METADATA
type: chart-docs
title: Keycloak - Backup
description: Database backup and restore

keywords: keycloak, backup, restore, postgres, mysql

purpose: Keycloak database backup and restore guidance for PostgreSQL and MySQL-backed modes
scope: Chart Architecture

relations:
  - charts/keycloak/README.md
  - charts/keycloak/docs/production.md
path: charts/keycloak/docs/backup.md
version: 1.0
date: 2026-03-31
-->
