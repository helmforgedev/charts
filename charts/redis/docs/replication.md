# Redis Replication

## When to use

Use `replication` when you need one fixed primary for writes and replicas for reads.

Common cases:

- read-heavy applications
- workloads that already handle primary unavailability outside the chart
- environments that want read/write separation without Redis Cluster

## What this architecture delivers

- one primary
- multiple replicas
- separate services for primary and replicas
- persistence by role

## What it does not deliver

- automatic failover through Sentinel
- automatic client reconfiguration

## Environment requirements

- separate PVCs for primary and replicas
- stable networking between pods for replication
- client strategy that understands where to send writes and where to send reads

## How to think about this topology

`replication` is useful when the application wants read scale but still accepts a stable, known primary. It is simpler than `sentinel`, but it pushes more failover responsibility to the application and the operating team.

## Common risks

- assuming replicas alone provide HA
- sending writes to replicas by mistake
- not separating CPU, memory, and IOPS sizing between primary and replicas
- scheduling every pod onto the same node or zone

## Production best practices

- keep at least 2 replicas in critical environments
- use anti-affinity and `topologySpreadConstraints`
- enable `pdb.enabled=true`
- treat the primary service as the write-only endpoint
- monitor replication lag and pod restarts

## Best practices

- use `auth.existingSecret`
- keep anti-affinity enabled at the cluster level
- enable `pdb.enabled=true` in production
- size storage and resources separately for primary and replicas

## Most relevant values

| Parameter | Description |
|-----------|-------------|
| `architecture` | Must be `replication` |
| `replication.replicaCount` | Number of replicas |
| `replication.primary.persistence.*` | Persistence for the primary |
| `replication.replica.persistence.*` | Persistence for replicas |
| `pdb.enabled` | Protection against planned disruption |
| `metrics.enabled` | Exporter for monitoring |

## Example

```yaml
architecture: replication

auth:
  enabled: true
  existingSecret: redis-auth
  existingSecretPasswordKey: redis-password

replication:
  replicaCount: 2
  primary:
    persistence:
      enabled: true
      size: 50Gi
  replica:
    persistence:
      enabled: true
      size: 50Gi
```

## When to move to another mode

- move to `sentinel` when automatic primary promotion becomes a requirement
- move to `cluster` when the need shifts from read scaling to true shard-based scale

<!-- @AI-METADATA
type: chart-docs
title: Redis - Replication
description: Primary-replica replication

keywords: redis, replication

purpose: Redis primary-replica replication setup guide
scope: Chart Architecture

relations:
  - charts/redis/README.md
path: charts/redis/docs/replication.md
version: 1.0
date: 2026-03-20
-->
