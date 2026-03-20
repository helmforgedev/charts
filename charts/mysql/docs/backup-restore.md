---
title: MySQL - Backup
description: Backup and restore
keywords: [mysql, backup, restore, mysqldump]
scope: chart-docs
audience: users
---

# Backup and Restore

## Backup direction

This chart does not implement native backup jobs or a bundled backup controller.

Use external tooling for:

- logical backups
- physical backups
- binary log archival
- restore testing

## Operational recommendation

Treat backup and restore as a platform responsibility, not as an implicit feature of replication mode.

Replication helps with read scaling and some recovery workflows, but it is not a backup strategy.

## Minimum production practices

- keep regular full backups
- keep a binary log retention policy aligned with recovery goals
- test restores periodically
- document restore procedures for both standalone and replication topologies

## Restore notes

After a restore:

- verify application users and expected databases
- validate replication state before reintroducing read traffic
- rebuild replicas from the restored source instead of assuming they can self-heal safely

<!-- @AI-METADATA
type: chart-docs
title: MySQL - Backup
description: Backup and restore

keywords: mysql, backup, restore, mysqldump

purpose: MySQL backup and restore procedures using mysqldump
scope: Chart Architecture

relations:
  - charts/mysql/README.md
path: charts/mysql/docs/backup-restore.md
version: 1.0
date: 2026-03-20
-->
