# MongoDB Sharded Cluster

## When to use

Use `sharded` when a single replica set is no longer enough for data volume, throughput, or horizontal distribution requirements.

Common cases:

- large datasets that should be distributed across shards
- workloads with sustained throughput beyond one replica set's practical limits
- multi-tenant or partitionable domains with a clear shard key strategy
- teams already comfortable operating mongos, config servers, and shard replica sets

## What this architecture delivers

- `mongos` routers for client access
- config server replica set
- multiple shard replica sets
- automatic cluster bootstrap and shard registration via Helm hook job
- optional metrics on the deployed components

## What it does not deliver

- automatic shard key design
- application-level query optimization
- simplified operations comparable to standalone or replica set modes

## Environment requirements

- persistent volumes for config servers and shard members
- a clear shard key strategy before production rollout
- applications connecting through `mongos`
- enough cluster capacity to run config servers, multiple shard members, and routers reliably

## Operational guidance

`sharded` is the most capable and the most operationally demanding architecture in this chart. It should be chosen because the workload needs sharding, not because sharding sounds more robust. The right question is whether the workload truly needs data distribution, not only failover.

## Common risks

- choosing sharding before validating that a replica set is sufficient
- defining a poor shard key and creating hotspots
- under-sizing config servers or shard storage
- bypassing `mongos` and connecting directly to shard members from applications

## Production practices

- keep config servers at 3 members
- run at least 2 `mongos` replicas for router availability
- size shard replica sets according to write volume and storage growth
- distribute config servers, routers, and shard members across failure domains
- use persistent storage everywhere
- monitor chunk distribution, balancer behavior, replication lag, router health, and disk growth
- test expansion and shard-add operations before doing them in production

## Most relevant values

| Parameter | Description |
|-----------|-------------|
| `architecture` | Must be `sharded` |
| `sharded.mongos.replicaCount` | Number of mongos routers |
| `sharded.configServer.replicaCount` | Config server members |
| `sharded.configServer.persistence.*` | Config server storage |
| `sharded.shards.count` | Number of shards |
| `sharded.shards.membersPerShard` | Members per shard replica set |
| `sharded.shards.persistence.*` | Storage per shard member |
| `auth.existingKeySecret` | Existing key file secret for internal auth |
| `metrics.enabled` | Exporter sidecar |

## Example

```yaml
architecture: sharded

auth:
  enabled: true
  existingSecret: mongodb-credentials
  existingKeySecret: mongodb-keyfile

sharded:
  mongos:
    replicaCount: 2
  configServer:
    replicaCount: 3
    persistence:
      size: 20Gi
  shards:
    count: 2
    membersPerShard: 3
    persistence:
      size: 200Gi

metrics:
  enabled: true
```

## When not to use

- when the real need is only failover and redundancy
- when the application does not need shard-based scale
- when the team is not ready to operate shard keys, balancer behavior, and multi-component MongoDB topology

<!-- @AI-METADATA
type: chart-docs
title: MongoDB - Sharded
description: Sharded cluster deployment

keywords: mongodb, sharded, mongos

purpose: MongoDB sharded cluster deployment guide with mongos routers
scope: Chart Architecture

relations:
  - charts/mongodb/README.md
path: charts/mongodb/docs/sharded.md
version: 1.0
date: 2026-03-20
-->
