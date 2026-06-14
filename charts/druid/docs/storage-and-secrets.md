# Apache Druid Storage and Secrets Guide

## Storage Domains

Druid uses three storage domains:

- metadata storage for cluster state and segment records,
- deep storage for durable published segments and indexing logs,
- local working storage for segment cache and ingestion tasks.

The chart exposes each domain separately so operators can choose a simple
development setup or a production setup with managed backing services.

## Metadata Storage

The default metadata store is the HelmForge PostgreSQL subchart:

```yaml
postgresql:
  enabled: true

metadata:
  mode: subchart
```

Use external metadata storage for production environments that already provide
database lifecycle, backups, monitoring, and credential rotation:

```yaml
postgresql:
  enabled: false

metadata:
  mode: external
  external:
    type: postgresql
    host: postgresql.druid-data.svc.cluster.local
    port: 5432
    name: druid
    username: druid
    existingSecret: druid-metadata
    existingSecretPasswordKey: password
```

The same contract can target MySQL by setting `metadata.external.type=mysql`
and using the MySQL port.

## S3 Deep Storage

S3-compatible deep storage is the recommended production configuration because
Historical and ingestion processes can recover segment state from a durable
object store.

```yaml
deepStorage:
  type: s3
  s3:
    bucket: druid-segments
    baseKey: production/segments
    region: us-east-1
    existingSecret: druid-s3
```

For MinIO:

```yaml
deepStorage:
  type: s3
  s3:
    bucket: druid-segments
    baseKey: minio/segments
    region: us-east-1
    endpointUrl: http://minio.minio.svc.cluster.local:9000
    existingSecret: druid-s3
```

The Secret referenced by `deepStorage.s3.existingSecret` must contain the keys
configured by `existingSecretAccessKeyKey` and `existingSecretSecretKeyKey`.
The defaults are `access-key` and `secret-key`.

## External Secrets Operator

External Secrets Operator integration is opt-in and renders ExternalSecret
resources for metadata and S3 credential Secrets.

Enable metadata credentials:

```yaml
metadata:
  mode: external
  external:
    existingSecret: druid-metadata

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  metadata:
    enabled: true
    data:
      - secretKey: password
        remoteRef:
          key: druid/metadata
          property: password
```

Enable S3 credentials:

```yaml
deepStorage:
  type: s3
  s3:
    bucket: druid-segments
    existingSecret: druid-s3

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  deepStorage:
    enabled: true
    data:
      - secretKey: access-key
        remoteRef:
          key: druid/s3
          property: access-key
      - secretKey: secret-key
        remoteRef:
          key: druid/s3
          property: secret-key
```

The chart validates that External Secrets paths point at existing Secret names
from the Druid values contract. This prevents the application from referencing
one Secret while ESO creates another.

## Local Persistent Volumes

Historical segment cache is controlled by `historical.persistence`.
MiddleManager task storage is controlled by `middleManager.persistence`.
Bundled ZooKeeper storage is controlled by `zookeeper.persistence`.

For production, size those PVCs according to segment cache targets, ingestion
task concurrency, and ZooKeeper retention requirements. Use a storage class
with predictable latency for ZooKeeper and with enough throughput for segment
cache warm-up on Historical nodes.

## Backup Stance

This chart does not create database dumps or object storage backup jobs. The
metadata database and object store are separate durability systems and should
be backed up by the owning platform service.

For production recovery, verify:

- metadata database backups are restorable,
- object storage bucket versioning or backup policy protects segments,
- External Secrets remote keys can be restored,
- ZooKeeper state can be recreated or restored for the selected topology.
