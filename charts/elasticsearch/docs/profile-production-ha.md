# Production HA Profile

## When to use

Use `clusterProfile: production-ha` when you need a resilient, replicated Elasticsearch cluster that can tolerate node failures without losing availability or data.

Common cases:

- production search and analytics workloads
- log aggregation that must survive zone or node failures
- Elasticsearch backing Kibana dashboards read by many users
- environments where data loss is not acceptable

## What this profile delivers

- **3 dedicated master nodes** — manage cluster state, run elections; must be an odd number
- **3 dedicated data nodes** — store and query shards; scale independently
- **2 coordinating nodes** — route client requests, aggregate search results; offload work from data nodes
- anti-affinity rules (`preferredDuringScheduling`) to spread pods across nodes
- PodDisruptionBudgets (`maxUnavailable: 1`) for all three roles
- minimum quorum auto-calculated (`discovery.zen.minimum_master_nodes = ceil(masters/2+1)`)
- security auto-enabled when `security.enabled=true`

## What it does not deliver

by default (can be enabled):

- TLS — requires `security.tls.certManager.enabled=true` or `existingTlsSecret`
- S3 backups — requires `backup.enabled=true`
- ILM policies — requires `ilm.logs.enabled=true` etc.
- Data tiers — requires `dataTiers.hot.enabled=true`
- Monitoring — requires `monitoring.enabled=true`

## Environment requirements

- at least 3 Kubernetes nodes for anti-affinity to be effective
- sufficient memory: master (2 GiB × 3), data (8 GiB × 3), coordinating (4 GiB × 2) = ~34 GiB minimum
- persistent volumes for master and data nodes (200 GiB+ per data node in production)
- cert-manager or pre-existing TLS secrets for encrypted transport

## Operational guidance

The production-ha profile is designed around Elasticsearch operational best practices:

- **Dedicated master nodes** prevent data work from interfering with cluster state management
- **Dedicated coordinating nodes** prevent search aggregation from consuming data node CPU/heap
- **Quorum enforcement** prevents split-brain by requiring majority for election — with 3 masters, 2 are needed
- **PDBs** prevent budget violations during node drains (e.g., rolling cluster upgrades)

Scale data nodes horizontally before increasing heap. Elasticsearch recommends heap between 4–31 GiB per node; prefer more nodes over more heap per node.

## Common risks

- using even numbers of master nodes (2 or 4) — the validator will reject this
- under-sizing data node memory (heap must fit hot shard segments in memory)
- misconfiguring storage class (data nodes should use SSD-backed storage)
- omitting PodAntiAffinity when running fewer Kubernetes nodes than Elasticsearch replicas
- skipping TLS in production environments that handle sensitive data

## Most relevant values

| Parameter | Description |
|---|---|
| `master.replicaCount` | Override (must remain odd: 3, 5, 7) |
| `master.persistence.size` | PVC per master pod (cluster state, translog) |
| `data.replicaCount` | Override data node count |
| `data.persistence.size` | PVC per data node (200 GiB+ recommended) |
| `data.persistence.storageClass` | SSD-backed storage class |
| `coordinating.replicaCount` | Override coordinating count |
| `security.enabled` | Must be `true` in production |
| `security.tls.certManager.enabled` | Recommended for automated certificate rotation |
| `dataTiers.hot.enabled` | Enable when you have ILM tiering requirements |

## Example

```yaml
clusterProfile: production-ha

clusterName: production-search

master:
  replicaCount: 3      # always odd
  persistence:
    size: 20Gi
    storageClass: gp3

data:
  replicaCount: 3
  persistence:
    size: 500Gi
    storageClass: gp3

coordinating:
  replicaCount: 2

security:
  enabled: true
  tls:
    certManager:
      enabled: true
      clusterIssuer: true
      issuerName: letsencrypt-prod

monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
  prometheusRule:
    enabled: true
```

## When to add data tiers

Add `dataTiers.hot` and `dataTiers.warm` when:

- your ILM policies are moving data between phases and you need separate storage classes per phase
- hot data (recent, frequently queried) needs NVMe or SSD
- warm data (older, rarely written) can use cheaper HDD-backed storage
- you want to reduce cost without sacrificing query speed for recent data

See [`docs/profile-dev.md`](profile-dev.md) for the minimum viable starting point.

<!-- @AI-METADATA
type: chart-docs
title: Elasticsearch - Production HA Profile
description: Production high-availability multi-role cluster deployment

keywords: elasticsearch, production, ha, multi-role, pdb, anti-affinity

purpose: Production HA profile guidance for the Elasticsearch Helm chart
scope: Chart Profile

relations:
  - charts/elasticsearch/README.md
  - charts/elasticsearch/docs/security.md
path: charts/elasticsearch/docs/profile-production-ha.md
version: 1.0
date: 2026-04-09
-->
