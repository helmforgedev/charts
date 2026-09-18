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

### Private certificate authorities

For an HTTPS endpoint signed by a private or self-signed certificate authority, store the CA certificate in a Kubernetes Secret and configure:

```yaml
backup:
  s3:
    endpoint: https://s3.internal.example.com
    caSecret: vaultwarden-s3-ca
    caKey: ca.crt
```

The chart mounts that key as `/root/.mc/certs/CAs/ca.crt`, the trust directory used by the MinIO Client (`mc`).
The Secret must contain the CA certificate that signed the S3 endpoint certificate, not merely the endpoint leaf certificate.

As an emergency compatibility option, `backup.s3.insecureSkipVerify=true` passes `--insecure` to every `mc` operation.
This disables TLS certificate verification and should not be used when a trusted CA can be supplied.
`caSecret` and `insecureSkipVerify` are mutually exclusive.

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
    caSecret: vaultwarden-s3-ca
    caKey: ca.crt
```

## References

- [Backup and Restore](backup-and-restore.md)
- [External Database Backup](external-database-backup.md)

<!-- @AI-METADATA
type: chart-docs
title: Vaultwarden - Backup Automation
description: Automated S3 backup CronJob

keywords: vaultwarden, backup, automation, s3

purpose: Automated S3 backup CronJob setup for Vaultwarden
scope: Chart Architecture

relations:
  - charts/vaultwarden/docs/backup-and-restore.md
path: charts/vaultwarden/docs/backup-automation.md
version: 1.0
date: 2026-03-20
-->
