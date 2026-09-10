# Dev Profile

## When to use

Use `clusterProfile: dev` when you need a single Elasticsearch node with the lowest possible resource footprint.

Common cases:

- local development on your workstation
- unit and integration testing in CI
- exploring Elasticsearch APIs without cluster complexity
- disposable sandbox environments

## What this profile delivers

- one Elasticsearch pod running all roles (master + data + ingest)
- 2 GiB container memory, 1 GiB heap (auto-calculated)
- a 10 GiB master PVC by default; set `master.persistence.enabled=false` for disposable emptyDir storage
- security and TLS disabled for easy `curl` access
- no PodDisruptionBudget
- no coordinating or dedicated data nodes

## What it does not deliver

- high availability or failover
- shard replication (single node = no replicas)
- TLS encryption
- PodDisruptionBudgets
- independent role scaling

## Environment requirements

- single node with 2–4 GiB available memory
- a default StorageClass for the master PVC, unless persistence is explicitly disabled
- `vm.max_map_count=262144` on the host (handled automatically by `sysctlInit.enabled=true`)

## Operational guidance

The dev profile is the simplest configuration. Its PVC survives pod replacement,
but a single node provides no replica or failover. If the
workload becomes operationally important, migrate to `staging` or
`production-ha` and take an Elasticsearch snapshot before switching.

## Common risks

- treating a single persistent node as highly available or disabling persistence for important data
- treating `dev` as a staging baseline without testing multi-node behavior
- forgetting that there is no replica for any shard — a yellow/red cluster from a shard replica issue is the primary mode of failure

## Most relevant values

| Parameter | Description |
|---|---|
| `clusterProfile` | Must be `dev` |
| `master.persistence.enabled` | Enabled by default; set false for disposable storage |
| `master.persistence.size` | PVC size, default 10Gi |
| `master.heapSize` | Override heap (auto-calculated by default) |
| `master.resources` | CPU/memory requests and limits |
| `extraConfig` | Additional elasticsearch.yml settings |

## Example

```yaml
clusterProfile: dev

clusterName: my-dev-cluster

master:
  persistence:
    size: 10Gi  # default persistent storage size

extraConfig:
  xpack.license.self_generated.type: basic
```

## When to move to another profile

- move to `staging` when you need more than one node or representative data volumes
- move to `production-ha` when failover, anti-affinity, and PDBs become mandatory
