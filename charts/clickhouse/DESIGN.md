# ClickHouse Chart Design

## Scope

This chart deploys the official ClickHouse server image as a single StatefulSet
with persistent data, headless and client Services, optional Prometheus metrics,
External Secrets support, NetworkPolicy, and Helm test coverage.

## Differentiation

- Uses official `clickhouse/clickhouse-server` full-version tags.
- Blocks unsafe `replicaCount > 1` and directs users to the ClickHouse Operator
  for replicated topologies.
- Enables built-in Prometheus metrics without sidecar images.
- Keeps data and logs persistence separate.
- Includes ESO, dual-stack Service fields, NetworkPolicy, and k3d validation.

## Non-goals

- The chart does not implement shards, replicas, Keeper, or ZooKeeper.
- It does not render ClickHouse Operator CRDs.
- It does not automate cluster backup/restore because full backups require
  filesystem-local access and topology-specific restore procedures.

<!-- @AI-METADATA
type: chart-design
title: ClickHouse Chart Design
description: Design decisions for the ClickHouse HelmForge chart
keywords: clickhouse, design, statefulset
purpose: Capture chart scope and trade-offs
scope: Chart
relations:
  - charts/clickhouse/values.yaml
path: charts/clickhouse/DESIGN.md
version: 1.0
date: 2026-07-06
-->
