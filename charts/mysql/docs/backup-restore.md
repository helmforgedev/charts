# Backup and Restore

## Built-in backup strategy

This chart now includes an optional backup CronJob that runs `mysqldump --all-databases`, compresses the output, and uploads the archive to S3-compatible storage.

The backup job always connects to the writable endpoint:

- `standalone`: the single MySQL pod through the chart client Service
- `replication`: the fixed source through the source/client Service

The built-in backup path is intentionally logical backup only. It does not implement physical snapshotting, point-in-time recovery orchestration, or binary log shipping.

## Operational recommendation

Treat replication as read scaling and recovery assistance, not as a substitute for backup.

Use the built-in S3 backup for regular logical dumps, and add external tooling when you need:

- point-in-time recovery
- binlog archival
- physical backup workflows
- centralized retention enforcement across many database instances

## Minimum production practices

- keep regular full backups
- keep bucket retention and object lifecycle aligned with recovery goals
- keep a binary log retention policy aligned with recovery goals
- test restores periodically
- document restore procedures for both standalone and replication topologies

## Restore workflow

Prefer restoring into a fresh release, validating it, and only then switching application traffic.

### 1. Download the archive

```bash
mc cp backup/my-mysql-backups/mysql/mysql-mysql-20260331T162812Z.sql.gz /tmp/
gzip -dc /tmp/mysql-mysql-20260331T162812Z.sql.gz > /tmp/mysql-restore.sql
```

### 2. Restore into the writable endpoint

Standalone or replication source:

```bash
mysql \
  --host <mysql-host> \
  --port 3306 \
  --user root \
  --password < /tmp/mysql-restore.sql
```

### 3. Rebuild replicas if replication is enabled

Do not assume existing replicas will safely converge after a full logical restore. Recreate or re-seed replicas from the restored source according to your replication runbook.

### 4. Validate before reopening traffic

After a restore:

- verify application users and expected databases
- verify tables, routines, events, and triggers expected by applications
- confirm writes succeed on the restored writable endpoint
- validate replication state before reintroducing read traffic
- rebuild replicas from the restored source instead of assuming they can self-heal safely
- re-enable scheduled backups only after the restored environment is validated

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
date: 2026-03-31
-->
