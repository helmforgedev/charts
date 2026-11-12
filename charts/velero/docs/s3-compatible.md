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
- `checksumAlgorithm=""` when the provider does not support AWS checksum headers

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
        checksumAlgorithm: ""
        insecureSkipTLSVerify: true
```

Supported checksum algorithms are `CRC32`, `CRC32C`, `SHA1`, and `SHA256`.
Set `checksumAlgorithm` to an explicit empty string to disable checksum headers
for providers such as NetApp S3 that require requests without them.

## Validation checklist

- confirm credentials are mounted at `/credentials/cloud`
- confirm the `BackupStorageLocation` reaches `Available`
- validate a test backup before enabling recurring schedules
