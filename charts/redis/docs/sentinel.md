---
title: Redis - Sentinel
description: Sentinel HA with failover
keywords: [redis, sentinel, ha, failover]
scope: chart-docs
audience: users
---

# Redis Sentinel

## When to use

Use `sentinel` when the application or client can query Sentinel to discover the current primary.

Common cases:

- HA with primary discovery
- Sentinel-compatible clients
- need for failover without adopting Redis Cluster

## What this architecture delivers

- primary and replica data topology
- dedicated Sentinel pods
- configurable quorum
- primary discovery through the Sentinel service

## What it requires from the client

- the client must support Redis Sentinel
- the application must tolerate primary changes discovered through Sentinel

## Environment requirements

- at least 3 Sentinel instances for consistent quorum
- enough replicas to fail over without losing service
- distribution across nodes or zones to reduce correlated failure
- validated client and library behavior before production rollout

## How to think about this topology

`sentinel` is the right option when you want automatic failover without moving to the Redis Cluster contract. It keeps one active primary at a time and uses Sentinels for election, health observation, and replica promotion.

## Common risks

- choosing a quorum incompatible with the number of Sentinels
- concentrating Sentinels and replicas on the same node
- using clients that do not rediscover the primary correctly
- treating Sentinel as a substitute for sharding

## Production best practices

- keep 3 Sentinels as the minimum baseline
- use majority quorum
- distribute Sentinels, primary, and replicas across failure domains
- enable `pdb.enabled=true`
- validate real failover and application reconnect timing
- monitor primary changes, replication lag, and Sentinel health

## Best practices

- use at least 3 Sentinels
- keep `quorum` aligned with the number of Sentinels
- distribute Sentinels and replicas across distinct nodes
- enable `pdb.enabled=true`
- validate failover behavior in the real environment

## Most relevant values

| Parameter | Description |
|-----------|-------------|
| `architecture` | Must be `sentinel` |
| `replication.replicaCount` | Number of Redis replicas |
| `sentinel.replicaCount` | Number of Sentinel pods |
| `sentinel.quorum` | Quorum for failover decisions |
| `pdb.enabled` | Protection against planned disruption |
| `metrics.enabled` | Exporter for monitoring |

## Example

```yaml
architecture: sentinel

auth:
  enabled: true
  existingSecret: redis-auth
  existingSecretPasswordKey: redis-password

replication:
  replicaCount: 2

sentinel:
  replicaCount: 3
  quorum: 2
```

## When to move to another mode

- move back to `replication` if the application cannot operate with Sentinel
- move to `cluster` when the primary need becomes shard-based scale rather than failover
