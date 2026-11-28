# MariaDB Replica Bootstrap

MariaDB read replicas use a logical dump by default. The logical path works with
every Kubernetes storage provisioner and remains the recovery fallback:

```yaml
architecture: replication
replication:
  readReplicas:
    bootstrap:
      method: logical
```

Large databases can instead restore new replica PVCs from one pre-created CSI
`VolumeSnapshot`. The chart does not pause MariaDB or create the snapshot. The
operator or backup controller must produce an application-consistent snapshot
of the writable source PVC and record the MariaDB GTID from the same point in
time.

## Prerequisites

Before selecting `volumeSnapshot`, verify all of the following:

- the cluster has the `snapshot.storage.k8s.io/v1` API, snapshot controller and
  a CSI driver that supports snapshot restore;
- the `VolumeSnapshot` is ready, is in the release namespace and was created
  from the writable source PVC, not from a replica;
- the snapshot and replica StorageClass use a compatible CSI driver;
- the restored PVC size is at least the source volume size;
- `persistence.subPath` matches the source volume layout;
- the chart credentials match the credentials stored in the snapshot;
- the supplied GTID was captured at the exact application-consistent snapshot
  point;
- source binlogs from that GTID remain available until every restored replica
  catches up. Size retention for delayed scale-out and rollback to long-idle
  logical PVCs. If those binlogs were purged, create a new snapshot and
  rebootstrap instead of reusing the old position.

Kubernetes VolumeSnapshot objects do not provide application-consistency
guarantees. Quiesce writes and follow the database and CSI provider procedures.
Do not infer consistency only because `status.readyToUse` is true.

## Values

```yaml
architecture: replication

replication:
  readReplicas:
    replicaCount: 2
    persistence:
      enabled: true
      storageClass: csi-storage-class
      size: 100Gi
    bootstrap:
      method: volumeSnapshot
      volumeSnapshot:
        name: mariadb-source-snapshot
        gtid: 0-1-42
```

Every new replica PVC uses the configured snapshot as its `dataSource`. The
bootstrap init container starts crash recovery, applies a unique `server_id`,
sets `gtid_slave_pos`, configures the source connection and writes its completion
marker before the replica becomes ready.

The GTID accepts a comma-separated MariaDB position, for example
`0-1-42,1-9-7`. It is not discovered from the source after the snapshot because
that could associate newer coordinates with older data.

## Upgrade and rollback

First, while the method is still `logical`, set
`replication.readReplicas.persistence.retentionPolicy.whenDeleted: Retain` in a
separate upgrade. Confirm the logical StatefulSet has reconciled that policy
before switching methods.

The VolumeSnapshot path uses a distinct replica StatefulSet and distinct PVC
names. Enabling it on an existing logical-replication release therefore:

1. removes the old logical replica StatefulSet;
2. retains its existing PVCs when the prerequisite retention policy is active;
3. creates snapshot-backed replica PVCs;
4. starts replication from the supplied snapshot GTID.

The writable source StatefulSet and source PVC are not replaced. Verify the
snapshot and GTID before the upgrade. Do not delete the retained logical replica
PVCs until the new replicas are healthy and caught up.

To roll back, set `bootstrap.method: logical`. The logical replica StatefulSet
reuses its retained PVCs and detects their existing replication metadata. Scale
or delete retained PVCs only as a separate, reviewed operation.

## Fail-closed datadir protection

Logical bootstrap no longer writes into a non-empty replica datadir when both
the HelmForge bootstrap marker and MariaDB replication metadata are missing.
This prevents an ambiguous PVC from being overwritten.

An installation interrupted by a chart version older than 3.0.0 can have a
trusted partial bootstrap without the new state marker. Resume it once with:

```yaml
replication:
  readReplicas:
    bootstrap:
      method: logical
      resumeUnmarkedDatadir: true
```

Return the value to `false` after every replica is healthy. Never enable it for
an unknown or reused PVC.

## Validation

After the upgrade, verify the PVC source and replication state:

```bash
kubectl get pvc -n <namespace> \
  -l app.kubernetes.io/instance=<release> \
  -o custom-columns=NAME:.metadata.name,SOURCE:.spec.dataSource.name,STATUS:.status.phase

kubectl exec -it -n <namespace> <release>-mariadb-snapshot-replicas-0 \
  -c mariadb -- mariadb -uroot -p -e "SHOW SLAVE STATUS\\G"
```

Both replication threads must be running and `Seconds_Behind_Master` should
converge after the replica applies transactions newer than the snapshot.
