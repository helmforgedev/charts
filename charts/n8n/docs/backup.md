# Backup and Restore

The chart includes a CronJob-based backup system that uploads archives to S3-compatible storage.

## How It Works

| Database | Tool | Archive Content |
|----------|------|-----------------|
| SQLite | `tar` | Full `/home/node/.n8n` directory |
| PostgreSQL | `pg_dump` | SQL dump (gzipped) |
| MySQL | `mysqldump` | SQL dump (gzipped) |

## Enable Backups

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: my-backups
    prefix: n8n
    accessKey: AKIAIOSFODNN7EXAMPLE
    secretKey: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

For production, use `backup.s3.existingSecret` instead of inline credentials.

## Restore principles

Prefer restoring into a fresh release, validating it, and only then switching traffic or webhook producers.

When n8n uses SQLite, the restore boundary is the full `/home/node/.n8n` directory, not only `database.sqlite`.

When n8n uses PostgreSQL or MySQL, restore the database dump and then validate encryption-key continuity before resuming executions.

## Restore

### SQLite

```bash
mc cp backup/my-backups/n8n/n8n-sqlite-20260323T030000Z.tar.gz /tmp/
kubectl scale deploy <release>-n8n --replicas=0 -n <namespace>
# attach the restored PVC or copy the archive into the mounted volume path
tar -xzf /tmp/n8n-sqlite-20260323T030000Z.tar.gz -C <restored-volume-mount>
kubectl scale deploy <release>-n8n --replicas=1 -n <namespace>
```

### PostgreSQL

```bash
mc cp backup/my-backups/n8n/n8n-postgresql-20260323T030000Z.sql.gz /tmp/
gunzip /tmp/n8n-postgresql-20260323T030000Z.sql.gz
psql -h <host> -U n8n -d n8n < /tmp/n8n-postgresql-20260323T030000Z.sql
```

### MySQL

```bash
mc cp backup/my-backups/n8n/n8n-mysql-20260323T030000Z.sql.gz /tmp/
gunzip /tmp/n8n-mysql-20260323T030000Z.sql.gz
mysql -h <host> -u n8n -p n8n < /tmp/n8n-mysql-20260323T030000Z.sql
```

## Post-restore validation

- confirm the release still uses the expected encryption key secret
- verify n8n startup and editor login
- verify credentials can still be decrypted
- verify webhook URLs and execution mode settings match the intended environment
- only re-enable scheduled backups after the restored environment is validated

<!-- @AI-METADATA
type: chart-docs
title: Backup and Restore
description: S3 backup strategy and restore procedures for the n8n Helm chart

keywords: backup, restore, s3, cronjob, sqlite, postgresql, mysql, minio

purpose: Help operators configure and use the backup system
scope: Chart

relations:
  - charts/n8n/README.md
  - charts/n8n/docs/database.md
path: charts/n8n/docs/backup.md
version: 1.0
date: 2026-03-31
-->
