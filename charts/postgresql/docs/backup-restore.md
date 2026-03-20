---
title: PostgreSQL - Backup
description: Backup and restore
keywords: [postgresql, backup, restore, pg_dump]
scope: chart-docs
audience: users
---

# Backup and Restore

## Scope

This chart does not implement backups directly. Backup and restore must be handled by platform tooling, scheduled jobs, or external controllers.

## Minimum production expectation

- a tested logical or physical backup workflow
- retention policy aligned with business and compliance needs
- restore verification in a non-production environment
- a documented recovery time expectation

## Recommended direction

- use dedicated PostgreSQL backup tooling or a platform backup solution
- keep WAL, data retention, and storage sizing aligned with the backup design
- if replication is enabled, do not assume replicas replace backups

## Restore guidance

- restore into a fresh release or a controlled maintenance workflow
- verify database integrity and application connectivity before switching traffic
- document whether restore will overwrite an existing PVC or create a new one

## What to document for operations

- where backups are stored
- who owns restore approval
- how often restore tests are executed
- how secrets and credentials are supplied during recovery

<!-- @AI-METADATA
type: chart-docs
title: PostgreSQL - Backup
description: Backup and restore

keywords: postgresql, backup, restore, pg_dump

purpose: PostgreSQL backup and restore procedures using pg_dump
scope: Chart Architecture

relations:
  - charts/postgresql/README.md
path: charts/postgresql/docs/backup-restore.md
version: 1.0
date: 2026-03-20
-->
