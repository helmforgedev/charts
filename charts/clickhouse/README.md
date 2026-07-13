# ClickHouse

Fast column-oriented OLAP database with production-safe standalone defaults.

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install clickhouse helmforge/clickhouse
```

```bash
helm install clickhouse oci://ghcr.io/helmforgedev/helm/clickhouse
```

## Features

- Official ClickHouse image pinned to `26.6.1`.
- StatefulSet with persistent data volume.
- Client Service exposing HTTP `8123` and native TCP `9000`.
- Headless Service for stable pod DNS.
- Built-in Prometheus metrics endpoint.
- ServiceMonitor support.
- External Secrets integration for the initial password.
- NetworkPolicy and dual-stack Service fields.
- Explicit guardrail blocking unsafe Helm-only replication.

## Quick Start

```yaml
persistence:
  size: 20Gi
```

## Production Example

```yaml
clickhouse:
  database: analytics
  user: analytics
  existingSecret: clickhouse-auth
persistence:
  size: 200Gi
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
networkPolicy:
  enabled: true
```

## Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `replicaCount` | ClickHouse pod count. Must remain `1` | `1` |
| `image.repository` | Official image repository | `docker.io/clickhouse/clickhouse-server` |
| `image.tag` | Official full-version tag | `26.6.1` |
| `clickhouse.database` | Initial database | `default` |
| `clickhouse.user` | Initial user | `default` |
| `clickhouse.password` | Initial password | `""` |
| `persistence.enabled` | Persist data volume | `true` |
| `persistence.size` | Data PVC size | `20Gi` |
| `metrics.enabled` | Built-in Prometheus endpoint | `false` |
| `networkPolicy.enabled` | Render NetworkPolicy | `false` |
| `service.ipFamilyPolicy` | Service dual-stack policy | `""` |

## Examples

- [Standalone](examples/standalone.yaml)
- [Production](examples/production.yaml)
- [External Secrets](examples/external-secrets.yaml)
- [Metrics](examples/metrics.yaml)

## Architecture Guides

- [Production](docs/production.md)
- [Observability](docs/observability.md)
- [External Secrets](docs/external-secrets.md)

## Security Scan

### Security Scan: `clickhouse`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **89.39%** |

Security posture acceptable.

Local details:

- Tool: Kubescape v4.0.9
- Command: `kubescape scan framework mitre,nsa,soc2 .tmp/clickhouse-render.yaml`
- Result: 0 critical failed resources, resource summary score 89.39%.

## Operator Boundary

ClickHouse replication needs Keeper or ZooKeeper, cluster definitions, and
cluster-aware operations. This chart intentionally blocks `replicaCount > 1`.
Use the ClickHouse Operator or Altinity operator stack for sharded or replicated
clusters.

## Upgrade Notes

This release moves ClickHouse from the 25.8 LTS line to 26.6 stable. Review the
upstream release notes and test application queries, persisted data, and backup
restore procedures before upgrading production workloads. StatefulSet rolling
updates reuse the existing data volume; take a verified backup first.

<!-- @AI-METADATA
type: chart-readme
title: ClickHouse Chart
description: Production-ready standalone ClickHouse Helm chart
keywords: clickhouse, database, olap, prometheus
purpose: Chart usage documentation
scope: Chart
relations:
  - charts/clickhouse/values.yaml
path: charts/clickhouse/README.md
version: 1.0
date: 2026-07-06
-->
