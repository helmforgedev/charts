# S3-Compatible Storage

This chart is intentionally optimized for S3-compatible object storage in v1.

Typical providers:

- MinIO
- Ceph RGW
- Cloudian
- other providers that expose the AWS S3 API contract

## Recommended baseline

Use:

- the default AWS plugin
- an explicit `s3Url`
- `s3ForcePathStyle=true` when the provider requires path-style addressing

## Example

```yaml
credentials:
  secretContents: |
    [default]
    aws_access_key_id=minioadmin
    aws_secret_access_key=minioadmin123

configuration:
  backupStorageLocations:
    - name: default
      provider: aws
      bucket: velero
      default: true
      config:
        region: minio
        s3Url: http://minio.minio.svc.cluster.local:9000
        s3ForcePathStyle: true
        insecureSkipTLSVerify: true
```

## Validation checklist

- confirm credentials are mounted at `/credentials/cloud`
- confirm the `BackupStorageLocation` reaches `Available`
- validate a test backup before enabling recurring schedules
