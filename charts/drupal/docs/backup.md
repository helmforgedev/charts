# Backup

The Drupal chart includes a built-in backup CronJob for production environments.

Each run creates:

- a `sites/` archive so uploaded files, generated styles, and installer-managed state are preserved
- a database backup that matches the active mode:
  - `mysqldump` for bundled or external MySQL-compatible databases
  - a consistent SQLite snapshot using Python's SQLite backup API

## Requirements

- `persistence.enabled=true`
- `backup.enabled=true`
- S3-compatible storage credentials

## Minimal MySQL Backup Example

```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"
  s3:
    endpoint: https://minio.example.com
    bucket: drupal-backups
    existingSecret: drupal-backup-s3
```

## External Database Backup Credentials

When `database.mode=external`, the chart does not know the database password from the installer flow.

Provide it explicitly for backup jobs:

```yaml
backup:
  enabled: true
  database:
    existingSecret: drupal-backup-db
```

## SQLite Notes

SQLite backups are supported, but SQLite itself remains a single-node path. Keep SQLite for evaluation, simple sites, or controlled single-replica installs.
