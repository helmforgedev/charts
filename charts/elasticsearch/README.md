# Elasticsearch Helm Chart

Production-ready Elasticsearch cluster chart using the **official Elastic image**. Deploys multi-role clusters (master, data, coordinating) from a single `clusterProfile` setting, with automated S3 backups, ILM lifecycle policies, cert-manager TLS, data tiers, and Grafana dashboards included out of the box.

## Install

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install es helmforge/elasticsearch
```

### OCI registry

```bash
helm install es oci://ghcr.io/helmforgedev/helm/elasticsearch
```

## Quick Start

```bash
# Dev profile — single node, no TLS, fast startup
helm install es helmforge/elasticsearch

# Production HA — 3 master + 3 data + 2 coordinating, TLS, PDBs
helm install es helmforge/elasticsearch \
  --set clusterProfile=production-ha \
  --set security.enabled=true \
  --set security.tls.certManager.enabled=true
```

## Cluster Profiles

| Profile | Masters | Data | Coordinating | TLS | PDB |
|---|---|---|---|---|---|
| `dev` | 1 (all roles) | — | — | No | No |
| `staging` | 1 | 2 | — | No | Data only |
| `production-ha` | 3 | 3 | 2 | Auto | All roles |

Read before choosing a profile:

- [Dev profile](docs/profile-dev.md) — single node, local development
- [Staging profile](docs/profile-staging.md) — small cluster, representative environments
- [Production HA profile](docs/profile-production-ha.md) — full HA cluster, data tiers, monitoring
- [Backup and restore](docs/backup-restore.md) — S3 snapshots and point-in-time recovery
- [Security and TLS](docs/security.md) — cert-manager, password management, mTLS

## Key Features

- **Profile-driven** — `dev`, `staging`, `production-ha` presets with tuned defaults
- **Multi-role StatefulSets** — dedicated pods per role: master, data, coordinating
- **Auto heap sizing** — 50% rule applied from container memory limit (max 31 GB), no manual JVM tuning
- **Split-brain prevention** — validates odd master count, auto-calculates `minimum_master_nodes` quorum
- **Data tiers** — optional hot/warm nodes with separate storage classes and ILM attribute routing
- **S3 snapshots** — scheduled CronJob with configurable retention, repository auto-registration
- **ILM policies** — pre-built templates for logs, metrics, and traces (hot→warm→cold→delete)
- **cert-manager TLS** — issues multi-SAN certificates for internode and client traffic
- **Monitoring** — Prometheus exporter sidecar, ServiceMonitor, 6 alert rules, 3 Grafana dashboards
- **Optional Kibana** — auto-connected with shared TLS and Ingress support
- **PodDisruptionBudgets** — for master, data, coordinating, hot, and warm roles

## Configuration

### Dev (single node)

```yaml
# All defaults — clusterProfile: dev is the default
clusterName: dev-cluster
```

### Staging (small cluster)

```yaml
clusterProfile: staging

master:
  persistence:
    size: 20Gi

data:
  persistence:
    size: 100Gi
```

### Production HA

```yaml
clusterProfile: production-ha

clusterName: production-es

master:
  persistence:
    size: 20Gi

data:
  persistence:
    size: 500Gi

security:
  enabled: true
  tls:
    certManager:
      enabled: true
      clusterIssuer: true
      issuerName: letsencrypt-prod

backup:
  enabled: true
  schedule: "0 2 * * *"
  s3:
    bucket: my-es-backups
    region: us-east-1
    existingSecret: es-s3-creds

ilm:
  logs:
    enabled: true
  metrics:
    enabled: true

monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
  prometheusRule:
    enabled: true
  grafana:
    dashboards: true
```

### With Data Tiers

```yaml
clusterProfile: production-ha

dataTiers:
  hot:
    enabled: true
    replicas: 3
    storage: 200Gi
    storageClass: fast-ssd
  warm:
    enabled: true
    replicas: 2
    storage: 1Ti
    storageClass: standard
```

## Parameters

### Global

| Parameter | Description | Default |
|---|---|---|
| `clusterProfile` | Cluster preset: `dev`, `staging`, `production-ha` | `dev` |
| `clusterName` | Elasticsearch cluster name | `helmforge-cluster` |
| `image.repository` | Elasticsearch image | `docker.io/library/elasticsearch` |
| `image.tag` | Image tag | `8.17.4` |
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full release name | `""` |

### Master Nodes

| Parameter | Description | Default |
|---|---|---|
| `master.replicaCount` | Override profile-driven replica count | profile-driven |
| `master.heapSize` | JVM heap (auto-calculated if empty) | `""` |
| `master.resources` | CPU/memory requests and limits | profile-driven |
| `master.persistence.size` | PVC size per master pod | profile-driven |
| `master.persistence.storageClass` | Storage class | `""` |
| `master.podAnnotations` | Pod annotations | `{}` |
| `master.nodeSelector` | Node selector | `{}` |
| `master.tolerations` | Tolerations | `[]` |

### Data Nodes

| Parameter | Description | Default |
|---|---|---|
| `data.replicaCount` | Override profile-driven replica count | profile-driven |
| `data.heapSize` | JVM heap (auto-calculated if empty) | `""` |
| `data.resources` | CPU/memory requests and limits | profile-driven |
| `data.persistence.size` | PVC size per data pod | profile-driven |
| `data.persistence.storageClass` | Storage class | `""` |

### Coordinating Nodes

| Parameter | Description | Default |
|---|---|---|
| `coordinating.replicaCount` | Override profile-driven replica count | profile-driven |
| `coordinating.heapSize` | JVM heap | `""` |
| `coordinating.resources` | CPU/memory requests and limits | profile-driven |

### Security

| Parameter | Description | Default |
|---|---|---|
| `security.enabled` | Enable X-Pack security (TLS + auth) | `false` (true in prod-ha) |
| `security.tls.certManager.enabled` | Issue TLS via cert-manager | `false` |
| `security.tls.certManager.clusterIssuer` | Use ClusterIssuer instead of Issuer | `false` |
| `security.tls.certManager.issuerName` | Issuer/ClusterIssuer name | `selfsigned-issuer` |
| `security.existingTlsSecret` | Pre-existing TLS secret (keys: ca.crt, tls.crt, tls.key) | `""` |
| `security.existingCredentialsSecret` | Pre-existing credentials secret | `""` |
| `security.generatePasswords` | Auto-generate passwords | `true` |

### Backup

| Parameter | Description | Default |
|---|---|---|
| `backup.enabled` | Enable scheduled S3 snapshots | `false` |
| `backup.schedule` | Cron schedule | `"0 2 * * *"` |
| `backup.retention.days` | Delete snapshots older than N days | `30` |
| `backup.s3.bucket` | S3 bucket name | `""` |
| `backup.s3.region` | AWS region | `us-east-1` |
| `backup.s3.endpoint` | Custom endpoint (MinIO, GCS, etc.) | `""` |
| `backup.s3.existingSecret` | Secret with access-key / secret-key | `""` |

### ILM Policies

| Parameter | Description | Default |
|---|---|---|
| `ilm.logs.enabled` | Create helmforge-logs ILM policy | `false` |
| `ilm.logs.hotDays` | Days in hot phase | `7` |
| `ilm.logs.warmDays` | Days in warm phase | `30` |
| `ilm.logs.coldDays` | Days in cold phase | `90` |
| `ilm.logs.deleteDays` | Days until deletion | `180` |
| `ilm.metrics.enabled` | Create helmforge-metrics ILM policy | `false` |
| `ilm.traces.enabled` | Create helmforge-traces ILM policy | `false` |

### Data Tiers

| Parameter | Description | Default |
|---|---|---|
| `dataTiers.hot.enabled` | Enable dedicated hot tier nodes | `false` |
| `dataTiers.hot.replicas` | Hot tier replica count | `2` |
| `dataTiers.hot.storage` | Hot tier PVC size | `200Gi` |
| `dataTiers.hot.storageClass` | Hot tier storage class (e.g. fast-ssd) | `""` |
| `dataTiers.warm.enabled` | Enable dedicated warm tier nodes | `false` |
| `dataTiers.warm.replicas` | Warm tier replica count | `2` |
| `dataTiers.warm.storage` | Warm tier PVC size | `1Ti` |
| `dataTiers.warm.storageClass` | Warm tier storage class (e.g. standard) | `""` |

### Monitoring

| Parameter | Description | Default |
|---|---|---|
| `monitoring.enabled` | Deploy Prometheus exporter sidecar | `false` |
| `monitoring.image.repository` | Exporter image | `prometheuscommunity/elasticsearch-exporter` |
| `monitoring.image.tag` | Exporter tag | `v1.8.0` |
| `monitoring.serviceMonitor.enabled` | Create ServiceMonitor | `false` |
| `monitoring.serviceMonitor.interval` | Scrape interval | `30s` |
| `monitoring.prometheusRule.enabled` | Create PrometheusRule (6 alerts) | `false` |
| `monitoring.grafana.dashboards` | Create Grafana dashboard ConfigMaps | `false` |

### Kibana

| Parameter | Description | Default |
|---|---|---|
| `kibana.enabled` | Deploy Kibana alongside Elasticsearch | `false` |
| `kibana.image.tag` | Kibana version (must match ES version) | `8.17.4` |
| `kibana.replicaCount` | Kibana replica count | `1` |
| `kibana.ingress.enabled` | Expose Kibana via Ingress | `false` |
| `kibana.ingress.hosts` | Ingress hostnames | `[kibana.example.com]` |

### Service

| Parameter | Description | Default |
|---|---|---|
| `service.type` | Service type for HTTP access | `ClusterIP` |
| `service.httpPort` | Elasticsearch HTTP port | `9200` |
| `service.transportPort` | Inter-node transport port | `9300` |

### Other

| Parameter | Description | Default |
|---|---|---|
| `sysctlInit.enabled` | Set `vm.max_map_count=262144` via init container | `true` |
| `terminationGracePeriodSeconds` | Grace period for pod shutdown | `120` |
| `extraEnv` | Extra environment variables | `[]` |
| `extraVolumes` | Extra volumes | `[]` |
| `extraVolumeMounts` | Extra volume mounts | `[]` |
| `extraConfig` | Extra elasticsearch.yml settings | `{}` |
| `nodeSelector` | Global node selector | `{}` |
| `tolerations` | Global tolerations | `[]` |
| `priorityClassName` | Priority class | `""` |

## Resources Generated

| Profile | Resources |
|---|---|
| `dev` | Secret (credentials), ConfigMap (config + ILM), Service, Service (headless), StatefulSet (master), NOTES.txt |
| `staging` | + StatefulSet (data), PDB (data) |
| `production-ha` | + StatefulSet (coordinating), 3x PDB, optionally: Issuer + Certificate, CronJob (backup), ServiceMonitor, PrometheusRule, ConfigMap (grafana dashboards) |

## Examples

See the [`examples/`](examples/) directory:

- [`dev.yaml`](examples/dev.yaml) — single node for local development
- [`staging.yaml`](examples/staging.yaml) — small cluster for integration environments
- [`production-ha.yaml`](examples/production-ha.yaml) — full HA cluster with all features
- [`data-tiers.yaml`](examples/data-tiers.yaml) — hot/warm tier configuration for cost optimization

## Architecture Guides

- [`docs/profile-dev.md`](docs/profile-dev.md) — when to use single-node dev profile
- [`docs/profile-staging.md`](docs/profile-staging.md) — when to use staging profile
- [`docs/profile-production-ha.md`](docs/profile-production-ha.md) — production HA cluster guidance
- [`docs/backup-restore.md`](docs/backup-restore.md) — S3 snapshot strategy and restore flow
- [`docs/security.md`](docs/security.md) — TLS, cert-manager, password management

## Migrating from Bitnami

Key differences from the Bitnami Elasticsearch chart:

| Aspect | This chart | Bitnami |
|---|---|---|
| Image | Official `elasticsearch` | `bitnami/elasticsearch` |
| Configuration | 10-20 values (profile-driven) | 100+ values |
| Multi-role | Automatic from profile | Manual StatefulSet config |
| Backup | Automated CronJob + S3 | Not included |
| ILM policies | Pre-built templates | Not included |
| Data tiers | Hot/warm StatefulSets | Not included |
| cert-manager | Integrated | Manual |
| Heap sizing | Auto (50% rule) | Manual |
| Grafana dashboards | 3 included | Not included |

When migrating, snapshot your data first and plan for a reindex if you are changing major Elasticsearch versions.

<!-- @AI-METADATA
type: chart-readme
title: Elasticsearch Helm Chart
description: Production-ready Elasticsearch chart with cluster profiles, multi-role architecture, automated backups, ILM, data tiers, cert-manager TLS, and monitoring

keywords: elasticsearch, search, observability, elk, multi-role, ilm, backup, tls, prometheus

purpose: Usage guide for the Elasticsearch Helm chart covering cluster profiles, multi-role setup, backup, ILM, data tiers, security, and monitoring
scope: Chart

relations:
  - charts/elasticsearch/docs/profile-dev.md
  - charts/elasticsearch/docs/profile-production-ha.md
  - charts/elasticsearch/docs/backup-restore.md
  - charts/elasticsearch/docs/security.md
path: charts/elasticsearch/README.md
version: 1.0
date: 2026-04-09
-->
