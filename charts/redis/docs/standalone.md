---
title: Redis - Standalone
description: Standalone deployment
keywords: [redis, standalone]
scope: chart-docs
audience: users
---

# Redis Standalone

## When to use

Use `standalone` when you need a simple, predictable Redis deployment with the lowest operational cost.

Common cases:

- development
- testing
- local application cache
- small workloads without failover requirements

## What this architecture delivers

- a single Redis node
- optional persistence
- password authentication
- optional metrics

## What it does not deliver

- automatic failover
- high availability
- horizontal sharding

## Environment requirements

- PVC when data must survive pod recreation
- a storage class aligned with write behavior
- memory sized for the dataset and Redis usage pattern

## Recommended operational flow

1. keep `auth.enabled=true`
2. use `auth.existingSecret` in production
3. enable persistence when Redis stores non-disposable data
4. enable metrics when the environment is monitored

## Common risks

- treating `standalone` as an HA solution
- using ephemeral storage for important data
- under-sizing memory and causing eviction or instability
- exposing the service outside the cluster without proper controls

## Best practices

- keep `auth.enabled=true`
- use persistent volumes when data cannot be lost
- do not expose the service externally without a clear reason
- enable metrics in monitored environments

## Most relevant values

| Parameter | Description |
|-----------|-------------|
| `architecture` | Must remain `standalone` |
| `auth.enabled` | Enables password auth |
| `auth.existingSecret` | Uses an existing secret for the password |
| `standalone.persistence.enabled` | Enables PVC |
| `standalone.persistence.size` | Volume size |
| `metrics.enabled` | Enables exporter |

## Example

```yaml
architecture: standalone

auth:
  enabled: true
  existingSecret: redis-auth
  existingSecretPasswordKey: redis-password

standalone:
  persistence:
    enabled: true
    size: 10Gi
```

## When to move to another mode

- move to `replication` when separating reads from writes becomes necessary
- move to `sentinel` when automatic primary failover becomes a requirement
- move to `cluster` when one node no longer fits the capacity or throughput needs

<!-- @AI-METADATA
type: chart-docs
title: Redis - Standalone
description: Standalone deployment

keywords: redis, standalone

purpose: Standalone Redis deployment guide
scope: Chart Architecture

relations:
  - charts/redis/README.md
path: charts/redis/docs/standalone.md
version: 1.0
date: 2026-03-20
-->
