# Production

The chart defaults are intentionally small and developer-friendly. Production deployments should use an explicit values file that turns on the controls required by the target platform.

## Baseline production values

Use [examples/production.yaml](../examples/production.yaml) as a starting point, then adjust storage classes, pod CIDRs, object storage endpoints, resources, and topology keys.

At minimum, production deployments should set:

- `auth.existingSecret`
- persistent storage sizes and storage classes
- CPU and memory resources
- `metrics.enabled=true`
- `networkPolicy.enabled=true`
- backup configuration with restore tests
- explicit scheduling rules when multiple nodes or zones exist

## Network access

The compatibility default allows generated `pg_hba.conf` access from `0.0.0.0/0` and `::/0`. This keeps upgrades non-breaking, but production deployments should restrict:

```yaml
config:
  allowedClientCIDRs:
    - 10.42.0.0/16
  allowedReplicationCIDRs:
    - 10.42.0.0/16
```

Pair PostgreSQL-level access rules with Kubernetes NetworkPolicy:

```yaml
networkPolicy:
  enabled: true
  egress:
    enabled: true
```

## TLS

PostgreSQL requires restrictive permissions on the server private key. Kubernetes Secrets may mount key files with permissions PostgreSQL rejects in some environments.

Enable the permission normalization init container when needed:

```yaml
tls:
  enabled: true
  existingSecret: postgresql-tls
  volumePermissions:
    enabled: true
```

The init container copies certificate material from the Secret into an `emptyDir`, sets the private key to `0600`, and runs PostgreSQL against the corrected mount.

## Replication slots

Replication slots can prevent a lagging replica from losing required WAL, but they can also retain WAL until disk pressure becomes dangerous. Use them only with retention limits and monitoring:

```yaml
replication:
  slots:
    enabled: true
  wal:
    maxSlotWalKeepSize: 8GB
    idleReplicationSlotTimeout: 24h
    walSenderTimeout: 60s
```

Monitor `pg_replication_slots`, WAL directory growth, disk usage, and replica lag.

## Service account

PostgreSQL pods do not need Kubernetes API credentials by default:

```yaml
serviceAccount:
  create: true
  automountServiceAccountToken: false
```

Only enable token automounting for a specific integration that needs it.

## Scope boundary

This chart does not implement automatic failover, fencing, promotion orchestration,
PITR, or cluster reconciliation. Use a PostgreSQL operator when production
requirements include automated HA lifecycle management.

<!-- @AI-METADATA
type: chart-docs
title: PostgreSQL Production
description: Production hardening guide for the PostgreSQL Helm chart

keywords: postgresql, production, hardening, tls, networkpolicy, replication

purpose: Describe production values and operational boundaries for PostgreSQL
scope: Chart

relations:
  - charts/postgresql/README.md
  - charts/postgresql/DESIGN.md
  - charts/postgresql/examples/production.yaml
path: charts/postgresql/docs/production.md
version: 1.0
date: 2026-05-06
-->
