---
title: Redis - Cluster
description: Cluster mode
keywords: [redis, cluster, sharding]
scope: chart-docs
audience: users
---

# Redis Cluster

## When to use

Use `cluster` when you need native sharding and the client supports Redis Cluster.

Common cases:

- horizontally growing datasets
- need for multiple masters
- cluster-aware applications

## What this architecture delivers

- multiple Redis nodes
- cluster bootstrap through a `Job`
- replicas per master
- client service for access to the set of nodes

## What it requires from the client

- support for `MOVED` and `ASK` redirects
- explicit Redis Cluster compatibility

## Environment requirements

- node count aligned with `replicasPerMaster`
- persistence on all nodes
- stable DNS between pods
- validated client and library support for Redis Cluster

## How to think about this topology

`cluster` is a scale and availability choice, not just a redundancy choice. Data is partitioned across masters, and the client must understand redirects and slot mapping.

## Common risks

- using clients that are not Redis Cluster compatible
- choosing a node count incompatible with the replica strategy
- ignoring future rebalance and expansion operations
- treating cluster as a simple replacement for `sentinel`

## Production best practices

- start with 6 nodes for 3 masters and 3 replicas when the workload justifies it
- use anti-affinity and zone distribution
- keep PVCs on every node
- enable `pdb.enabled=true`
- monitor bootstrap, slots, failover, and memory usage per node
- plan operational windows for cluster expansion or maintenance

## Best practices

- use node counts compatible with `replicasPerMaster`
- validate application clients before adopting this mode
- use persistent volumes on all nodes
- enable anti-affinity and `pdb.enabled=true`
- monitor bootstrap, rebalance, and overall cluster health

## Most relevant values

| Parameter | Description |
|-----------|-------------|
| `architecture` | Must be `cluster` |
| `cluster.nodes` | Total number of nodes |
| `cluster.replicasPerMaster` | Replicas per master |
| `cluster.persistence.enabled` | PVC on each node |
| `cluster.persistence.size` | Volume size per node |
| `metrics.enabled` | Exporter for monitoring |

## Example

```yaml
architecture: cluster

auth:
  enabled: true
  existingSecret: redis-auth
  existingSecretPasswordKey: redis-password

cluster:
  nodes: 6
  replicasPerMaster: 1
  persistence:
    enabled: true
    size: 20Gi
```

## When not to use

- when the application only needs one primary and read replicas
- when the client does not understand Redis Cluster
- when the data volume still fits comfortably in a single instance
