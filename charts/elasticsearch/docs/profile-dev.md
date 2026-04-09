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
- no persistent storage by default (emptyDir — data is lost on pod restart)
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
- no persistent volume required (but optional via `master.persistence`)
- `vm.max_map_count=262144` on the host (handled automatically by `sysctlInit.enabled=true`)

## Operational guidance

The dev profile is the simplest configuration. It is appropriate when data loss is acceptable and speed of startup is more important than durability. If the workload becomes operationally important, migrate to `staging` or `production-ha` and take an Elasticsearch snapshot before switching.

## Common risks

- using dev profile for data that must survive pod restarts (no persistence by default)
- treating `dev` as a staging baseline without testing multi-node behavior
- forgetting that there is no replica for any shard — a yellow/red cluster from a shard replica issue is the primary mode of failure

## Most relevant values

| Parameter | Description |
|---|---|
| `clusterProfile` | Must be `dev` |
| `master.persistence.size` | PVC size (set to enable persistence) |
| `master.heapSize` | Override heap (auto-calculated by default) |
| `master.resources` | CPU/memory requests and limits |
| `extraConfig` | Additional elasticsearch.yml settings |

## Example

```yaml
clusterProfile: dev

clusterName: my-dev-cluster

master:
  persistence:
    size: 10Gi  # optional: add persistence

extraConfig:
  xpack.license.self_generated.type: basic
```

## When to move to another profile

- move to `staging` when you need more than one node or representative data volumes
- move to `production-ha` when failover, anti-affinity, and PDBs become mandatory

<!-- @AI-METADATA
type: chart-docs
title: Elasticsearch - Dev Profile
description: Single-node dev deployment

keywords: elasticsearch, dev, single-node

purpose: Dev profile guidance for the Elasticsearch Helm chart
scope: Chart Profile

relations:
  - charts/elasticsearch/README.md
path: charts/elasticsearch/docs/profile-dev.md
version: 1.0
date: 2026-04-09
-->
