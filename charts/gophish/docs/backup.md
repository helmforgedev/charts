# Gophish Backup and Restore

Research date: 2026-04-28

## Scope

The chart-managed backup covers SQLite mode only. It archives the chart-managed data directory that contains the default SQLite database at `/opt/gophish/data/gophish.db`.

Persistent filesystem coverage: in SQLite mode, the backup archive includes the chart-managed PVC path mounted at `/opt/gophish/data`.

Database coverage: in SQLite mode, the SQLite database file is inside the archived persistent filesystem path. Embedded MySQL and external MySQL database coverage are intentionally delegated to their database-specific backup tooling.

MySQL modes are intentionally outside this backup boundary:

- Embedded MySQL should use the HelmForge MySQL dependency backup flow.
- External MySQL-compatible databases are the operator's responsibility.

## Enabling SQLite Backup

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: gophish-backups
    prefix: gophish
    existingSecret: gophish-backup
```

The S3 Secret must contain:

- `access-key`
- `secret-key`

For local k3d validation only, inline `backup.s3.accessKey` and `backup.s3.secretKey` can be used.

## Runtime Model

The backup CronJob:

1. mounts the Gophish PVC read-only
2. creates a compressed archive of the SQLite data directory
3. writes a SHA256 checksum
4. uploads both files with `docker.io/helmforge/mc:1.0.0`

## Restore Outline

1. Stop the Gophish Deployment.
2. Download the selected archive and checksum from S3-compatible storage.
3. Verify the checksum.
4. Restore the archive contents into the data PVC.
5. Start the Gophish Deployment.
6. Verify admin login, campaign pages, landing pages, and SMTP profiles.

Do not switch database modes during a restore. Restore into the same database mode that produced the backup.
