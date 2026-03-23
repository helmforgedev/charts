# Backup

The chart includes an optional CronJob that creates database backups and uploads them to S3-compatible storage.

## How It Works

- **SQLite mode**: creates a tar.gz archive of the `/app/data` directory
- **MariaDB mode**: runs `mysqldump` and compresses the output

The backup runs as a two-step process:
1. **Init container**: creates the database dump/archive
2. **Main container**: uploads to S3 using MinIO client (`mc`)

## Configuration

```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"
  s3:
    endpoint: https://s3.example.com
    bucket: my-backups
    prefix: uptime-kuma
    accessKey: "access-key"
    secretKey: "secret-key"
```

## Using an Existing Secret

```yaml
backup:
  enabled: true
  s3:
    endpoint: https://s3.example.com
    bucket: my-backups
    existingSecret: backup-s3-credentials
    existingSecretAccessKeyKey: access-key
    existingSecretSecretKeyKey: secret-key
```

<!-- @AI-METADATA
@description: Backup configuration guide for the Uptime Kuma Helm chart
@type: chart-docs
@chart: uptime-kuma
@path: charts/uptime-kuma/docs/backup.md
@date: 2026-03-23
@relations:
  - charts/uptime-kuma/README.md
  - charts/uptime-kuma/values.yaml
-->
