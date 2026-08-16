# Backup And Restore

## Recovery set

A recoverable Ente installation requires Museum configuration and cryptographic
Secrets, PostgreSQL data, and S3 objects. Back up and restore them together.

PostgreSQL contains the metadata and encryption keys required to interpret S3
objects. An object-only backup is not recoverable.

## PostgreSQL CronJob

The chart's CronJob creates a custom-format `pg_dump` and uploads it through the
MinIO client. Use a backup bucket and credentials independent from the live Ente
object bucket when possible.

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://backup.example.com
    bucket: backups
    prefix: ente/postgresql
    existingSecret: ente-backup-s3
```

## Object backup

Use provider-native replication or backup tooling for the live Ente bucket.
Preserve object names and contents exactly. Ente's application replication is
availability, not point-in-time backup.

## Secret backup

Export Museum key names and encrypted Secret data to a protected secret manager.
Do not store plaintext keys in source control. Verify the backup contains the
encryption key, hash key, and JWT secret.

## Restore order

1. Create an isolated namespace and deny outbound notifications.
2. Restore Museum Secrets.
3. Restore the S3 objects to a test bucket.
4. Restore PostgreSQL with `pg_restore`.
5. Install Ente against the restored dependencies.
6. Validate login, thumbnails, originals, and public albums.
7. Confirm object counts and application logs.
8. Only then perform the production cutover.

## Restore drills

Run a complete restore drill at least quarterly. A successful scheduled Job is
not proof that the three-part recovery set is usable.
