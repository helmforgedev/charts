---
title: Generic Chart - StatefulSet
description: StatefulSet configuration
keywords: [generic, statefulset, persistence]
scope: chart-docs
audience: users
---

# Generic Chart for StatefulSets

## When to use

Use `StatefulSet` when each replica needs stable identity or dedicated persistent storage.

Common cases:

- queue consumers with stable network identity
- internal stateful applications that are not complex enough to justify a dedicated chart
- clustered software that depends on ordinal pod naming
- simple databases used only as internal tooling, not as fully productized charts

## What this mode delivers

- stable pod names
- ordered or parallel pod management
- `volumeClaimTemplates`
- service discovery via headless-style patterns when required by the workload

## What it does not deliver

- database-specific bootstrap logic
- replication orchestration or quorum management by itself
- product-level operational safety for complex stateful software

## Recommended practices

- use `StatefulSet` only when stable identity is genuinely required
- define `workload.volumeClaimTemplates` for per-pod storage
- choose `OrderedReady` or `Parallel` intentionally
- test rolling upgrades with real persistence attached
- avoid using the generic chart for complex datastores that deserve product-specific topology handling

## Most relevant values

| Parameter | Description |
|-----------|-------------|
| `workload.type` | Must be `StatefulSet` |
| `workload.podManagementPolicy` | `OrderedReady` or `Parallel` |
| `workload.volumeClaimTemplates` | PVC templates per replica |
| `replicaCount` | Number of replicas |
| `service.*` | Service behavior for the stateful workload |
| `persistence.mounts` | Shared mounts across containers |
| `affinity` | Placement strategy |

## Example

```yaml
workload:
  enabled: true
  type: StatefulSet
  podManagementPolicy: Parallel
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: standard
        resources:
          requests:
            storage: 20Gi

replicaCount: 3

image:
  repository: ghcr.io/example/stateful-app
  tag: "2.0.0"

imageTagFormat: simple

containers:
  - name: app
    ports:
      - containerPort: 9090
    volumeMounts:
      - name: data
        mountPath: /var/lib/app
```

<!-- @AI-METADATA
type: chart-docs
title: Generic Chart - StatefulSet
description: StatefulSet configuration

keywords: generic, statefulset, persistence

purpose: StatefulSet workload configuration guide for the generic chart
scope: Chart Architecture

relations:
  - charts/generic/README.md
path: charts/generic/docs/statefulset.md
version: 1.0
date: 2026-03-20
-->
