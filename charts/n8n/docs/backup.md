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

## Restore

### SQLite

```bash
mc cp backup/my-backups/n8n/n8n-sqlite-20260323T030000Z.tar.gz /tmp/
kubectl scale deploy <release>-n8n --replicas=0
kubectl cp /tmp/n8n-sqlite-20260323T030000Z.tar.gz <pod>:/home/node/.n8n/
kubectl exec <pod> -- tar -xzf /home/node/.n8n/n8n-sqlite-20260323T030000Z.tar.gz -C /home/node/.n8n/
kubectl scale deploy <release>-n8n --replicas=1
```

### PostgreSQL

```bash
mc cp backup/my-backups/n8n/n8n-postgresql-20260323T030000Z.sql.gz /tmp/
gunzip /tmp/n8n-postgresql-20260323T030000Z.sql.gz
psql -h <host> -U n8n -d n8n < /tmp/n8n-postgresql-20260323T030000Z.sql
```

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
date: 2026-03-23
-->
