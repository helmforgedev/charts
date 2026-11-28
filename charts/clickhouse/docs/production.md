# Production Guide

This chart supports `architecture=standalone` (default) and
`architecture=replicated` with ClickHouse Keeper or external ZooKeeper.

## Standalone

Do not increase `replicaCount` above `1` in standalone mode. The chart blocks
that because simply scaling a StatefulSet does not create a valid ClickHouse
cluster.

## Replicated

For multi-node clusters set:

```yaml
architecture: replicated
replicated:
  clusterName: default
  shards: 1
  replicasPerShard: 3
  keeper:
    enabled: true
    replicaCount: 3
```

Use Replicated* table engines and `ON CLUSTER <clusterName>` DDL so replicas
stay consistent. Confirm `system.clusters` and Keeper quorum before cutting
over production traffic.

## Storage

ClickHouse stores data under `/var/lib/clickhouse`. Keeper stores coordination
data under the same path inside Keeper pods. Use fast block storage and confirm
that the StorageClass supports expansion before production.

## Upgrades

Pin a full image version. Back up data before changing `image.tag`, run the new
version in staging, and watch logs during merges and mutations after startup.

<!-- @AI-METADATA
type: chart-docs
title: ClickHouse Production Guide
description: Production operating notes for the ClickHouse chart
keywords: clickhouse, production, storage, replication, keeper
purpose: Explain production boundaries
scope: Chart
relations:
  - charts/clickhouse/values.yaml
path: charts/clickhouse/docs/production.md
version: 1.1
date: 2026-11-26
-->
