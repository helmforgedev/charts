<!-- SPDX-License-Identifier: Apache-2.0 -->

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
- either S3-compatible static credentials or a supported Kubernetes workload identity

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

## Workload Identity

Use Pod Identity, IRSA, or an equivalent projected credential provider without
storing S3 keys in Kubernetes Secrets:

```yaml
backup:
  enabled: true
  s3:
    endpoint: https://s3.us-east-1.amazonaws.com
    bucket: drupal-backups
    region: us-east-1
    credentialsFromPodIdentity: true
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/drupal-backup
```

The chart creates a dedicated backup ServiceAccount. Set
`backup.serviceAccount.create=false` and `backup.serviceAccount.name` to reuse
an existing identity-bound account. Static S3 Secrets are not rendered in this
mode.

Grant the identity only the bucket operations the job uses: list the target
bucket and put objects under the configured prefix. Grant bucket creation only
when `backup.s3.createBucketIfNotExists=true`. IRSA also needs permission to
assume the configured role through the cluster's OIDC provider.

The dedicated account disables Kubernetes API token automount by default.
Enable `backup.serviceAccount.automountServiceAccountToken` only when the
selected identity provider explicitly requires that token. With
`networkPolicy.egress.enabled=true`, retain DNS and HTTPS egress and add the
provider's metadata or credential endpoint through `networkPolicy.egress.extraTo`
when it is not covered by those rules. The chart does not hardcode an IPv4 or
IPv6 metadata address; cluster routing and the identity provider determine the
reachable address family.

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
