# Backup and Restore

## Built-in backup strategy

This chart now includes an optional backup CronJob that runs `mysqldump --all-databases`, compresses the output, and uploads the archive to S3-compatible storage.

The backup job always connects to the writable endpoint:

- `standalone`: the single MySQL pod through the chart client Service
- `replication`: the fixed source through the source/client Service

The built-in backup path is intentionally logical backup only. It does not implement physical snapshotting, point-in-time recovery orchestration, or binary log shipping.

## Operational recommendation

Treat replication as read scaling and recovery assistance, not as a substitute for backup.

Use the built-in S3 backup for regular logical dumps, and add external tooling when you need:

- point-in-time recovery
- binlog archival
- physical backup workflows
- centralized retention enforcement across many database instances

Backup object-storage credentials can come from `backup.s3.existingSecret`, inline values for non-production testing,
`externalSecrets.backup.enabled=true` when External Secrets Operator manages the Kubernetes Secret, or
`backup.s3.credentialsFromPodIdentity=true` on EKS with Pod Identity / IRSA.

## Pod Identity / IRSA (EKS)

When running on EKS with Pod Identity or IRSA, static S3 credentials are unnecessary. Set
`backup.s3.credentialsFromPodIdentity=true`.

- **IRSA:** annotate the dedicated backup ServiceAccount with the IAM role ARN.
- **EKS Pod Identity:** create a Pod Identity association for the dedicated backup ServiceAccount instead. The annotation is ignored.

```yaml
backup:
  enabled: true
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::<account-id>:role/<role-name>
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: my-mysql-backups
    region: us-east-1
    credentialsFromPodIdentity: true
```

When this flag is set:

- The backup CronJob uses its own ServiceAccount and does not grant S3 access to the MySQL pods.
- No backup S3 Secret is created.
- No `S3_ACCESS_KEY` / `S3_SECRET_KEY` env vars are injected into the backup pod.
- `upload-backup.sh` sets `MC_HOST_backup` to the endpoint with no embedded keys, and sets
  `MC_STS_ENDPOINT_backup` to `https://sts.${AWS_REGION}.${sts_domain}`. `sts_domain` is
  `amazonaws.com` for commercial and GovCloud regions, and `amazonaws.com.cn` when `AWS_REGION`
  starts with `cn-`. `helmforge/mc:1.0.0` only uses the AWS credential chain when
  `MC_STS_ENDPOINT_<alias>` is set. A bare `MC_HOST` is signed with an empty access key and S3
  returns AccessDenied. For Pod Identity, minio-go then reads
  `AWS_CONTAINER_CREDENTIALS_FULL_URI` and `AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE` and does not
  call the STS URL. Set `backup.s3.region`. The chart injects it as `AWS_REGION` on the upload
  container. EKS Pod Identity does not document `AWS_REGION` as an injected variable.

The IAM role attached to the ServiceAccount must have at minimum:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:CreateBucket"],
      "Resource": [
        "arn:aws:s3:::my-mysql-backups",
        "arn:aws:s3:::my-mysql-backups/*"
      ]
    }
  ]
}
```

Omit `s3:CreateBucket` and set `backup.s3.createBucketIfNotExists=false` if the bucket is pre-created.

## Minimum production practices

- keep regular full backups
- keep backup credentials in a Kubernetes Secret or External Secrets Operator source, not inline values
- keep bucket retention and object lifecycle aligned with recovery goals
- keep a binary log retention policy aligned with recovery goals
- test restores periodically
- document restore procedures for both standalone and replication topologies

## Restore workflow

Prefer restoring into a fresh release, validating it, and only then switching application traffic.

### 1. Download the archive

```bash
mc cp backup/my-mysql-backups/mysql/mysql-mysql-20260331T162812Z.sql.gz /tmp/
gzip -dc /tmp/mysql-mysql-20260331T162812Z.sql.gz > /tmp/mysql-restore.sql
```

### 2. Restore into the writable endpoint

Standalone or replication source:

```bash
mysql \
  --host <mysql-host> \
  --port 3306 \
  --user root \
  --password < /tmp/mysql-restore.sql
```

### 3. Rebuild replicas if replication is enabled

Do not assume existing replicas will safely converge after a full logical restore. Recreate or re-seed replicas from the restored source according to your replication runbook.

### 4. Validate before reopening traffic

After a restore:

- verify application users and expected databases
- verify tables, routines, events, and triggers expected by applications
- confirm writes succeed on the restored writable endpoint
- validate replication state before reintroducing read traffic
- rebuild replicas from the restored source instead of assuming they can self-heal safely
- re-enable scheduled backups only after the restored environment is validated
