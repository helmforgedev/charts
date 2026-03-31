# MongoDB Standalone

## When to use

Use `standalone` when you need a single MongoDB instance with the lowest operational complexity.

Common cases:

- local development
- integration and test environments
- small internal workloads
- applications that can tolerate short maintenance windows and do not require node-level failover

## What this architecture delivers

- one `mongod` pod
- optional persistent storage
- root authentication
- optional additional application users
- optional init scripts
- optional metrics with `mongodb_exporter`

## What it does not deliver

- replica set elections
- automatic failover
- horizontal write scale
- shard-based distribution

## Environment requirements

- persistent volume if data must survive pod recreation
- storage class aligned with the workload profile
- memory sized for working set and WiredTiger cache behavior

## Operational guidance

`standalone` is the simplest mode in this chart. It is appropriate when simplicity is more important than high availability. If the workload becomes operationally important, the next step is usually `replicaset`, not `sharded`.

## Common risks

- using ephemeral storage for non-disposable data
- treating a single pod as an HA database
- under-sizing memory and IOPS
- exposing MongoDB externally without proper network controls

## Production practices

- keep `auth.enabled=true`
- prefer `auth.existingSecret` in production
- use persistent volumes for anything beyond disposable test data
- enable metrics in monitored environments
- back up the database before changing storage or image strategy

## Most relevant values

| Parameter | Description |
|-----------|-------------|
| `architecture` | Must stay `standalone` |
| `auth.enabled` | Enables MongoDB auth |
| `auth.rootPassword` | Root password when not using an existing secret |
| `auth.existingSecret` | Existing secret for root credentials |
| `auth.users` | Extra application users created at bootstrap |
| `persistence.enabled` | Enables persistent storage |
| `persistence.size` | PVC size |
| `initdbScripts` | Bootstrap scripts for first start |
| `metrics.enabled` | Enables exporter sidecar |

## Example

```yaml
architecture: standalone

auth:
  enabled: true
  existingSecret: mongodb-credentials

persistence:
  enabled: true
  size: 20Gi

metrics:
  enabled: true
```

## When to move to another architecture

- move to `replicaset` when failover and member redundancy become mandatory
- move to `sharded` when scaling requires distribution across multiple shards, not only redundancy

<!-- @AI-METADATA
type: chart-docs
title: MongoDB - Standalone
description: Standalone deployment

keywords: mongodb, standalone

purpose: Standalone MongoDB deployment guide
scope: Chart Architecture

relations:
  - charts/mongodb/README.md
path: charts/mongodb/docs/standalone.md
version: 1.0
date: 2026-03-20
-->
