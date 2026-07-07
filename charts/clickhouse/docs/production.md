# Production Guide

This chart intentionally deploys a standalone ClickHouse StatefulSet. It is a
good fit for single-node analytics stores, development, or applications that
need ClickHouse without a Kubernetes operator.

## Replication Boundary

Do not increase `replicaCount`. The chart blocks values greater than `1`
because ClickHouse replication requires Keeper or ZooKeeper, shard definitions,
and cluster-aware DDL. For those topologies, use the ClickHouse Operator or
Altinity operator charts.

## Storage

ClickHouse stores data under `/var/lib/clickhouse`. Use fast block storage and
confirm that the StorageClass supports expansion before production.

## Upgrades

Pin a full image version. Back up data before changing `image.tag`, run the new
version in staging, and watch logs during merges and mutations after startup.

<!-- @AI-METADATA
type: chart-docs
title: ClickHouse Production Guide
description: Production operating notes for the ClickHouse chart
keywords: clickhouse, production, storage, replication
purpose: Explain production boundaries
scope: Chart
relations:
  - charts/clickhouse/values.yaml
path: charts/clickhouse/docs/production.md
version: 1.0
date: 2026-07-06
-->
