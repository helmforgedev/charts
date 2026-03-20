# Backup Automation

## What the built-in backup does

This chart can render a dedicated backup `CronJob`.

The backup behavior depends on the selected Vaultwarden storage mode:

- `sqlite`: archive `/data` and upload it to the configured bucket
- `external`, `postgresql`, `mysql`: dump the database, compress it, and upload it to the configured bucket

This feature is intentionally focused on backup creation, not restore orchestration.

## Why this design

The chart now provides a product-specific backup flow instead of expecting operators to build a separate generic job.

That keeps the backup contract close to the actual Vaultwarden mode in use:

- SQLite backup follows the `/data` boundary
- DB-backed backup follows the database boundary

## S3 contract

Configure:

- `backup.s3.endpoint`
- `backup.s3.bucket`
- either `backup.s3.existingSecret`
- or inline `backup.s3.accessKey` and `backup.s3.secretKey`

The uploader uses an S3-compatible endpoint, so MinIO and similar platforms are valid targets as long as they expose S3-compatible APIs.

## Database dump behavior

### SQLite

The CronJob archives the mounted `/data` directory and uploads the resulting tarball.

### PostgreSQL modes

The CronJob runs `pg_dump`, compresses the dump, and uploads it.

### MySQL modes

The CronJob runs `mysqldump`, compresses the dump, and uploads it.

For MySQL external databases configured only through an opaque `DATABASE_URL` secret, you may need `backup.database.*` overrides so the chart can build a deterministic dump command.

## Example

```yaml
backup:
  enabled: true
  schedule: "0 30 2 * * *"
  s3:
    endpoint: https://minio.example.com
    bucket: vaultwarden-backups
    prefix: prod
    existingSecret: vaultwarden-backup-s3
```

## References

- [Backup and Restore](backup-and-restore.md)
- [External Database Backup](external-database-backup.md)
