---
title: Keycloak - Backup
description: Database backup and restore
keywords: [keycloak, backup, restore, postgres, mysql]
scope: chart-docs
audience: users
---

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

## Operational recommendation

- use PostgreSQL for production whenever possible
- keep Keycloak database backup frequency aligned with realm and user-change volume
- validate restore procedures in a non-production environment before declaring the deployment production-ready
- if extensions, themes, or realm-import inputs are managed outside the database, back them up through their own source-of-truth workflow as well

## Restore notes

- restore into a controlled maintenance workflow
- verify Keycloak startup, admin login, and expected realms/clients before reopening traffic
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
