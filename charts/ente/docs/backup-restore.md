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

Bind the restored credentials and endpoints explicitly. This prevents the
restore release from creating a new PostgreSQL instance or generating new
Museum keys.

```yaml
museum:
  existingSecret: ente-restored-museum

storage:
  s3:
    endpoint: https://s3-restore.company.tld
    region: us-east-1
    bucket: ente-restore-test
    existingSecret: ente-restored-s3

database:
  mode: external
  external:
    host: ente-restore-rw.database.svc.cluster.local
    port: 5432
    name: ente
    username: ente
    existingSecret: ente-restored-postgresql
    existingSecretPasswordKey: database-password
    sslMode: require

postgresql:
  enabled: false
```

Render the release before starting Museum and inspect the exact Secret
references, database host, S3 endpoint, and bucket:

```bash
helm template ente-restore oci://ghcr.io/helmforgedev/helm/ente \
  -f restore-values.yaml > ente-restore-rendered.yaml
yq 'select(.kind == "Deployment" and .metadata.name == "ente-restore-ente-museum-api") |
  .spec.template.spec.containers[0].env[] |
  select(.valueFrom.secretKeyRef) |
  .valueFrom.secretKeyRef.name' ente-restore-rendered.yaml
yq 'select(.kind == "ConfigMap" and .metadata.name == "ente-restore-ente-config") |
  .data."museum-api.yaml"' ente-restore-rendered.yaml
```

## Restore drills

Run a complete restore drill at least quarterly. A successful scheduled Job is
not proof that the three-part recovery set is usable.
