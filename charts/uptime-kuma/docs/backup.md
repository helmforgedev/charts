<!-- SPDX-License-Identifier: Apache-2.0 -->

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

## External Secrets

External Secrets Operator can create the backup credential Secret:

```yaml
backup:
  enabled: true
  s3:
    existingSecret: uptime-kuma-s3

externalSecrets:
  enabled: true
  items:
    - name: backup-s3
      spec:
        secretStoreRef:
          name: platform-secrets
          kind: ClusterSecretStore
        target:
          name: uptime-kuma-s3
          creationPolicy: Owner
        data:
          - secretKey: access-key
            remoteRef:
              key: uptime-kuma/s3
              property: access-key
          - secretKey: secret-key
            remoteRef:
              key: uptime-kuma/s3
              property: secret-key
```

## Runtime and Restore Validation

Backup pods use the same restrictive runtime posture as the application: no
Kubernetes API token, runtime-default seccomp, no privilege escalation, dropped
capabilities, and a read-only image filesystem. Scratch output and client state
use bounded writable `emptyDir` volumes.

SQLite backup requires persistent `/app/data`; the chart rejects backup with
ephemeral SQLite storage. Any enabled backup also requires an S3 endpoint,
bucket, and either an existing Secret or both inline credential values.

A successful upload is not sufficient recovery evidence. Regularly restore the
newest object into a disposable namespace, start Uptime Kuma against the
restored data, and confirm monitor history, status pages, and notification
configuration before relying on the backup for production recovery.

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
