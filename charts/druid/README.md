# Apache Druid

Apache Druid is a high-performance, real-time analytics database designed for fast slice-and-dice analytics on large datasets. It is commonly used for powering user-facing analytic applications, BI dashboards, and real-time data exploration.

## Features

- **6-component architecture** — coordinator, overlord, broker, router, historical, and middlemanager
- **Web console** — router component serves the Druid web console
- **PostgreSQL subchart** — bundled metadata store with option for external database
- **ZooKeeper subchart** — bundled Bitnami ZooKeeper with option for external cluster
- **Deep storage** — local or S3-compatible (MinIO, AWS S3)
- **Persistent volumes** — segment cache (historical) and task storage (middlemanager)
- **Health probes** — liveness on `/status/health`, readiness on `/status/selfDiscovered`
- **Ingress support** — configurable with `ingressClassName` (traefik, nginx, etc.)
- **Per-component scaling** — independent replica counts and JVM tuning

## Install

### Helm repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install druid helmforge/druid -f values.yaml
```

### OCI registry

```bash
helm install druid oci://ghcr.io/helmforgedev/helm/druid --version <version> -f values.yaml
```

## Architecture

```
StatefulSet: coordinator (port 8081)
StatefulSet: overlord (port 8090)
Deployment:  broker (port 8082)
Deployment:  router (port 8888) ← web console
StatefulSet: historical (port 8083, PVC: segment-cache)
StatefulSet: middlemanager (port 8091, PVC: task-storage)
  ├─ PostgreSQL (subchart, metadata storage)
  └─ ZooKeeper (subchart, coordination)
```

## Default Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `apache/druid` | Druid container image |
| `image.tag` | `""` (appVersion) | Image tag |
| `coordinator.enabled` | `true` | Enable coordinator |
| `coordinator.replicaCount` | `1` | Coordinator replicas |
| `coordinator.port` | `8081` | Coordinator port |
| `coordinator.javaOpts` | `-Xms256m -Xmx512m` | Coordinator JVM options |
| `overlord.enabled` | `true` | Enable overlord |
| `overlord.port` | `8090` | Overlord port |
| `broker.enabled` | `true` | Enable broker |
| `broker.port` | `8082` | Broker port |
| `broker.javaOpts` | `-Xms512m -Xmx1g` | Broker JVM options |
| `router.enabled` | `true` | Enable router (web console) |
| `router.port` | `8888` | Router port |
| `historical.enabled` | `true` | Enable historical |
| `historical.port` | `8083` | Historical port |
| `historical.persistence.size` | `10Gi` | Segment cache volume size |
| `middleManager.enabled` | `true` | Enable middle manager |
| `middleManager.port` | `8091` | MiddleManager port |
| `middleManager.workerCapacity` | `2` | Tasks per middle manager |
| `middleManager.persistence.size` | `10Gi` | Task storage volume size |
| `metadata.mode` | `subchart` | Metadata mode: subchart or external |
| `zookeeperConfig.mode` | `subchart` | ZooKeeper mode: subchart or external |
| `deepStorage.type` | `local` | Deep storage: local or s3 |
| `service.type` | `ClusterIP` | Router service type |
| `service.port` | `80` | Router service port |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `traefik` | Ingress class |
| `postgresql.enabled` | `true` | Enable PostgreSQL subchart |
| `zookeeper.enabled` | `true` | Enable ZooKeeper subchart |

## External Metadata Storage

```yaml
postgresql:
  enabled: false

metadata:
  mode: external
  external:
    type: postgresql
    host: postgres.example.com
    port: 5432
    name: druid
    username: druid
    password: my-password
```

## External ZooKeeper

```yaml
zookeeper:
  enabled: false

zookeeperConfig:
  mode: external
  external:
    hosts: "zk1.example.com:2181,zk2.example.com:2181,zk3.example.com:2181"
```

## S3 Deep Storage

```yaml
deepStorage:
  type: s3
  s3:
    bucket: my-druid-bucket
    baseKey: druid/segments
    region: us-east-1
    accessKey: AKIAIOSFODNN7EXAMPLE
    secretKey: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

For MinIO or S3-compatible storage:

```yaml
deepStorage:
  type: s3
  s3:
    bucket: druid
    baseKey: segments
    region: us-east-1
    endpointUrl: http://minio.minio.svc:9000
    accessKey: minioadmin
    secretKey: minioadmin
```

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik  # or nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: druid.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: druid-tls
      hosts:
        - druid.example.com
```

## Extra Runtime Properties

Each component supports `extraProperties` for additional Druid runtime configuration:

```yaml
broker:
  extraProperties: |
    druid.broker.http.numConnections=20
    druid.server.http.numThreads=40

historical:
  extraProperties: |
    druid.segmentCache.locations=[{"path":"/opt/druid/var/druid/segment-cache","maxSize":10737418240}]
```

<!-- @AI-METADATA
type: chart-readme
title: Apache Druid Helm Chart
description: Apache Druid distributed analytics database with coordinator, broker, historical, middlemanager, overlord, and router

keywords: druid, analytics, olap, database, realtime, query

purpose: Installation, configuration, and operational guide for the Apache Druid Helm chart
scope: charts/druid

relations:
  - charts/druid/values.yaml
  - charts/druid/Chart.yaml
path: charts/druid/README.md
version: 1.0
date: 2026-04-01
-->
