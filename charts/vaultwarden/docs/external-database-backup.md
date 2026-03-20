---
title: Vaultwarden - External DB Backup
description: External database backup
keywords: [vaultwarden, backup, external-database]
scope: chart-docs
audience: users
---

# External Database Backup

## Why this guide exists

When Vaultwarden runs with:

- `database.mode=external`
- `database.mode=postgresql`
- or `database.mode=mysql`

the built-in backup solution in this chart focuses on the database dump.

## Production recommendation

For production, the intended model is:

- enable the chart backup CronJob
- generate compressed PostgreSQL or MySQL dumps
- upload them to an S3-compatible bucket
- document restore separately

## What belongs to the database backup

Back up:

- Vaultwarden relational data stored in PostgreSQL or MySQL

Do not rely on `/data` backup to cover this once SQLite is no longer the active backend.

## What happens to `/data`

For the current chart scope, DB-backed backup automation does not try to archive `/data` in the same job.

That is a deliberate simplification in favor of a predictable backup artifact centered on the authoritative database state.

## Restore sequence

Recommended order:

1. stop Vaultwarden traffic
2. restore the database
3. restore `/data`
4. redeploy or restart Vaultwarden
5. validate runtime behavior

## What to validate after restore

- user login
- organization access
- attachment download
- send access
- admin page access
- email and invitation behavior
- generated links using the configured `domain`

## Subchart note

If you use local subcharts:

- `postgresql.enabled=true`
- or `mysql.enabled=true`

the same logic still applies.

The main difference is only where the database lifecycle is hosted. The built-in backup still creates a database dump artifact and uploads it to the configured bucket.

## References

- Vaultwarden configuration template: https://raw.githubusercontent.com/dani-garcia/vaultwarden/main/.env.template

<!-- @AI-METADATA
type: chart-docs
title: Vaultwarden - External DB Backup
description: External database backup

keywords: vaultwarden, backup, external-database

purpose: External database backup procedures for Vaultwarden with PostgreSQL or MySQL
scope: Chart Architecture

relations:
  - charts/vaultwarden/docs/backup-and-restore.md
  - charts/vaultwarden/docs/database-modes-and-migrations.md
path: charts/vaultwarden/docs/external-database-backup.md
version: 1.0
date: 2026-03-20
-->
