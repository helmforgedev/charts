# Generic Chart Storage

## Storage contracts

The chart separates pod mounts from resource ownership:

- `persistence.volumes[]` adds volumes to the pod spec.
- `persistence.mounts[]` mounts volumes into all containers.
- `persistence.persistentVolumeClaims[]` creates namespaced PVCs owned by the release.
- `persistence.persistentVolumes[]` creates cluster-scoped PVs only when each item sets `create: true`.
- `persistence.storage[]` remains available as the legacy combined PV/PVC contract.

For StatefulSets, prefer `workload.volumeClaimTemplates` when each replica needs its own claim.

```yaml
persistence:
  persistentVolumeClaims:
    - name: data
      storage: 10Gi
      accessModes: ["ReadWriteOnce"]
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: my-release-data
  mounts:
    - name: data
      mountPath: /data
```

<!-- @AI-METADATA
type: chart-docs
title: Generic Chart - Storage
description: PVC, PV, mounts, and StatefulSet storage patterns for the generic chart
keywords: generic, storage, pvc, pv, statefulset
purpose: Storage guide for the generic chart
scope: Chart Architecture
relations:
  - charts/generic/README.md
path: charts/generic/docs/storage.md
version: 1.0
date: 2026-04-27
-->
