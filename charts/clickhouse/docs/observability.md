# Observability

ClickHouse includes a built-in Prometheus endpoint. Set `metrics.enabled=true`
to render config under `config.d/helmforge.xml` and expose the metrics port on
the Service.

## ServiceMonitor

Set `metrics.serviceMonitor.enabled=true` when the Prometheus Operator CRDs are
installed in the cluster. The chart keeps labels and namespace selectors
customizable for common Prometheus deployments.

## Useful Signals

Track query latency, background merges, part counts, memory usage, disk usage,
replication queue health when using external replicated topologies, and HTTP or
native TCP availability.

<!-- @AI-METADATA
type: chart-docs
title: ClickHouse Observability Guide
description: Prometheus monitoring for ClickHouse
keywords: clickhouse, prometheus, servicemonitor, metrics
purpose: Explain metrics configuration
scope: Chart
relations:
  - charts/clickhouse/templates/servicemonitor.yaml
path: charts/clickhouse/docs/observability.md
version: 1.0
date: 2026-07-06
-->
