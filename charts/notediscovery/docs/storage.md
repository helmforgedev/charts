# NoteDiscovery Storage

NoteDiscovery stores durable notes and local application data under `/app/data`
by default. The chart mounts that path from a PersistentVolumeClaim when
`persistence.enabled=true`.

## Default PVC

```yaml
persistence:
  enabled: true
  size: 5Gi
  accessModes:
    - ReadWriteOnce
```

The generated claim uses the cluster default StorageClass unless `persistence.storageClass` is set.

## Existing Claim

Use an existing claim when storage must be pre-provisioned, shared, snapshotted
by a storage controller, or retained independently of Helm release lifecycle:

```yaml
persistence:
  existingClaim: notediscovery-data
```

## Scaling

The chart blocks `replicaCount > 1` unless `persistence.existingClaim` is set.
Scaling requires an operator-managed storage backend with semantics appropriate
for multiple writers.

## Backups

Back up the PersistentVolumeClaim before upgrades and before changing storage
settings. For production, prefer volume snapshots from the storage backend or a
backup controller that can capture the `/app/data` contents consistently.
