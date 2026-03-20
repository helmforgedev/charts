---
title: MongoDB - ReplicaSet
description: ReplicaSet architecture
keywords: [mongodb, replicaset, ha]
scope: chart-docs
audience: users
---

# MongoDB Replica Set

## When to use

Use `replicaset` when you need MongoDB high availability with automatic elections and a standard topology for production workloads.

Common cases:

- production applications with a single writable primary
- environments that need automatic primary election
- workloads that want redundancy without full sharding complexity
- teams standardizing on replica set semantics for backup, maintenance, and upgrades

## What this architecture delivers

- multiple data-bearing members
- automatic `rs.initiate()` bootstrap via Helm hook job
- internal member authentication with key file
- a standard MongoDB replica set topology
- optional metrics and `ServiceMonitor`

## What it does not deliver

- shard-based horizontal data distribution
- write scaling beyond a single primary
- topology abstraction for clients that are not replica-set aware

## Environment requirements

- at least 3 members for a production-grade quorum
- persistent volumes for each member
- network stability between members
- applications and clients configured to use replica set connection strings

## Operational guidance

`replicaset` is usually the right default for production MongoDB when you need HA but do not need sharding. This chart bootstraps the replica set automatically, but the operational contract remains MongoDB's standard behavior: one primary, secondaries replicating from it, and elections on failure.

## Common risks

- running only 2 members and expecting safe elections
- forgetting the replica set connection string in clients
- scheduling all members in the same node or zone
- ignoring backup and restore testing because failover exists

## Production practices

- use 3 members as the minimum baseline
- distribute members across failure domains with affinity and topology spread
- keep `auth.enabled=true`
- use `auth.existingSecret` and `auth.existingKeySecret` when credentials are externally managed
- enable metrics and monitor replication lag, elections, and disk usage
- validate maintenance procedures such as rolling restart and version upgrade in a non-production environment

## Most relevant values

| Parameter | Description |
|-----------|-------------|
| `architecture` | Must be `replicaset` |
| `replicaSet.name` | Replica set name used by members and clients |
| `replicaSet.members` | Number of data-bearing members |
| `auth.replicaSetKey` | Internal auth key when not using existing secret |
| `auth.existingKeySecret` | Existing secret for key file |
| `persistence.*` | Storage settings for the members |
| `affinity` | Placement rules for member distribution |
| `topologySpreadConstraints` | Spread across nodes or zones |
| `metrics.enabled` | Exporter sidecar |

## Example

```yaml
architecture: replicaset

auth:
  enabled: true
  existingSecret: mongodb-credentials
  existingKeySecret: mongodb-keyfile

replicaSet:
  name: rs0
  members: 3

persistence:
  enabled: true
  size: 100Gi

metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

## When to move to another architecture

- move back to `standalone` only for non-critical simplified environments
- move to `sharded` when data size, throughput, or tenant isolation demands shard-based distribution

<!-- @AI-METADATA
type: chart-docs
title: MongoDB - ReplicaSet
description: ReplicaSet architecture

keywords: mongodb, replicaset, ha

purpose: MongoDB ReplicaSet architecture configuration guide
scope: Chart Architecture

relations:
  - charts/mongodb/README.md
path: charts/mongodb/docs/replicaset.md
version: 1.0
date: 2026-03-20
-->
