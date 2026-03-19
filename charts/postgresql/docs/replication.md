# Replication

## When to use it

Use `replication` when you need one writable PostgreSQL primary and separate asynchronous replicas for read traffic.

Typical use cases:

- applications with distinct write and read paths
- teams that want read scaling without introducing a full PostgreSQL operator
- environments where failover remains an operational procedure outside the chart

## What it delivers

- one primary StatefulSet
- one replica StatefulSet with `pg_basebackup` bootstrap
- dedicated Services for client traffic, primary traffic, and replicas
- bootstrap of app and replication users on first initialization
- optional `postgres_exporter`
- optional `ServiceMonitor`

## What it does not deliver

- automatic failover
- primary re-election
- synchronous replication guarantees
- connection pooling

## Operational requirements

- a storage class suitable for stateful workloads
- anti-affinity or topology spread when possible
- monitoring for replica health and lag
- a documented failover or restore runbook

## Best practices

- keep `readReplicas.replicaCount >= 2` if read scale matters
- use `pdb.enabled=true` before routine maintenance in multi-node environments
- route write traffic only to the primary Service
- route read traffic only to the replicas Service
- treat this mode as read scaling plus recovery help, not full HA

## Example

```yaml
architecture: replication

auth:
  existingSecret: postgresql-auth

replication:
  primary:
    persistence:
      enabled: true
      size: 50Gi
  readReplicas:
    replicaCount: 2
    persistence:
      enabled: true
      size: 50Gi
```
