# Apache Druid

Apache Druid is a high-performance, real-time analytics database designed for fast
slice-and-dice analytics on large datasets. It is commonly used for user-facing
analytic applications, BI dashboards, and real-time data exploration.

## Features

- **Modular Druid architecture** - coordinator, broker, and router by default, with optional overlord, historical, and middlemanager
- **Web console** - router component serves the Druid web console
- **PostgreSQL subchart** - bundled metadata store with option for external database
- **Bundled ZooKeeper** - native ZooKeeper StatefulSet with option for external cluster
- **Deep storage** - local or S3-compatible (MinIO, AWS S3)
- **Persistent volumes** - segment cache (historical) and task storage (middlemanager)
- **Health probes** - liveness on `/status/health`, readiness on `/status/selfDiscovered`
- **Ingress support** - configurable with `ingressClassName` (traefik, nginx, etc.)
- **Gateway API support** - optional HTTPRoute for the router/web console
- **Dual-stack Services** - optional `ipFamilyPolicy` / `ipFamilies` on every Druid Service
- **External Secrets Operator** - optional ExternalSecret projection for metadata and S3 credentials
- **NetworkPolicy** - optional ingress and egress controls for compatible CNIs
- **Per-component scaling** - independent replica counts and JVM tuning

## Security Scan

🟢 Security Scan: druid

| Framework | Score |
|-----------|-------|
| MITRE + NSA + SOC2 | 83.000000% |

✅ Security posture acceptable.

The default scan keeps Druid writable paths and resource limits configurable
instead of forcing a one-size-fits-all production profile. For hardened
deployments, enable NetworkPolicy and set explicit CPU and memory requests and
limits for every Druid component.

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

```text
StatefulSet: coordinator (port 8081)
StatefulSet: overlord (port 8090)
Deployment:  broker (port 8082)
Deployment:  router (port 8888) <- web console
StatefulSet: historical (port 8083, PVC: segment-cache)
StatefulSet: middlemanager (port 8091, PVC: task-storage)
  +-- PostgreSQL (subchart, metadata storage)
  +-- ZooKeeper (bundled StatefulSet, coordination)
```

## Default Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `apache/druid` | Druid container image |
| `image.tag` | `"37.0.0"` | Image tag |
| `coordinator.enabled` | `true` | Enable coordinator |
| `coordinator.replicaCount` | `1` | Coordinator replicas |
| `coordinator.port` | `8081` | Coordinator port |
| `coordinator.javaOpts` | `-Xms128m -Xmx256m` | Coordinator JVM options |
| `overlord.enabled` | `false` | Enable overlord for ingestion management |
| `overlord.port` | `8090` | Overlord port |
| `broker.enabled` | `true` | Enable broker |
| `broker.port` | `8082` | Broker port |
| `broker.javaOpts` | `-Xms256m -Xmx512m` | Broker JVM options |
| `router.enabled` | `true` | Enable router (web console) |
| `router.port` | `8888` | Router port |
| `historical.enabled` | `false` | Enable historical segment serving |
| `historical.port` | `8083` | Historical port |
| `historical.persistence.size` | `10Gi` | Segment cache volume size |
| `middleManager.enabled` | `false` | Enable middle manager ingestion workers |
| `middleManager.port` | `8091` | MiddleManager port |
| `middleManager.workerCapacity` | `2` | Tasks per middle manager |
| `middleManager.persistence.size` | `10Gi` | Task storage volume size |
| `metadata.mode` | `subchart` | Metadata mode: subchart or external |
| `zookeeperConfig.mode` | `subchart` | ZooKeeper mode: subchart or external |
| `deepStorage.type` | `local` | Deep storage: local or s3 |
| `service.type` | `ClusterIP` | Router service type |
| `service.port` | `80` | Router service port |
| `service.ipFamilyPolicy` | omitted | Optional Kubernetes Service IP family policy |
| `service.ipFamilies` | omitted | Optional ordered Service IP families |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `traefik` | Ingress class |
| `gatewayAPI.enabled` | `false` | Enable Gateway API HTTPRoute for the router |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resources for secret material |
| `networkPolicy.enabled` | `false` | Render NetworkPolicy resources |
| `podSecurityContext.fsGroup` | `1000` | Shared filesystem group for Druid volumes |
| `securityContext.runAsNonRoot` | `true` | Run Druid containers as a non-root user |
| `postgresql.enabled` | `true` | Enable PostgreSQL subchart |
| `zookeeper.enabled` | `true` | Enable bundled ZooKeeper |

## Druid 37.0.0 upgrade notes

This chart tracks Apache Druid `37.0.0`. Before upgrading persistent clusters,
review the upstream [release notes](https://druid.apache.org/docs/latest/release-info/release-notes/)
and [upgrade notes](https://druid.apache.org/docs/latest/release-info/upgrade-notes/).

Important upstream changes include:

- Hadoop-based ingestion has been removed.
- Druid moved S3 integrations to AWS SDK v2.
- Broker segment metadata cache is enabled by default, improving
  `sys.segments` queries while increasing Broker memory usage.

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

## Gateway API

Gateway API support is opt-in and renders an `HTTPRoute` to the router Service.
The chart does not create a `Gateway`; reference a shared Gateway managed by
your platform team.

```yaml
gatewayAPI:
  enabled: true
  parentRefs:
    - name: shared-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - druid.example.com
  paths:
    - type: PathPrefix
      value: /
```

## Dual-stack Services

Dual-stack fields are omitted by default so Kubernetes inherits the cluster
defaults. Set `service.ipFamilyPolicy` when running in IPv6 or dual-stack
clusters:

```yaml
service:
  ipFamilyPolicy: PreferDualStack
```

## External Secrets Operator

ExternalSecret rendering is opt-in. Set the chart's `existingSecret` field to
the same Secret that External Secrets Operator will create, preventing drift
between chart-managed and externally managed credentials.

```yaml
metadata:
  mode: external
  external:
    existingSecret: druid-metadata

deepStorage:
  type: s3
  s3:
    bucket: druid-segments
    existingSecret: druid-s3

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  metadata:
    enabled: true
    data:
      - secretKey: password
        remoteRef:
          key: druid/metadata
          property: password
  deepStorage:
    enabled: true
    data:
      - secretKey: access-key
        remoteRef:
          key: druid/s3
          property: access-key
      - secretKey: secret-key
        remoteRef:
          key: druid/s3
          property: secret-key
```

## Security context

Druid workload containers run as UID/GID `1000` by default with privilege
escalation disabled, all Linux capabilities dropped, and the runtime default
seccomp profile. The `prepare-dirs` init container runs as root only to create
and chown writable Druid directories.

## NetworkPolicy

NetworkPolicy is opt-in because enforcement depends on the cluster CNI. When
enabled, ingress defaults to same-namespace traffic on Druid component ports.
Egress rules are optional and can allow DNS, same-namespace dependencies, HTTP,
HTTPS, and extra peers:

```yaml
networkPolicy:
  enabled: true
  ingress:
    allowSameNamespace: true
  egress:
    enabled: true
    allowDNS: true
    allowSameNamespace: true
    allowHTTPS: true
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

## Examples

- [Simple development deployment](examples/simple.yaml)
- [S3-backed production deployment](examples/s3-production.yaml)
- [External metadata and ZooKeeper services](examples/external-services.yaml)
- [Gateway API with NetworkPolicy](examples/gateway-networkpolicy.yaml)
- [External Secrets with S3 deep storage](examples/external-secrets-s3.yaml)

## Architecture Guides

- [Architecture](docs/architecture.md)
- [Storage and secrets](docs/storage-and-secrets.md)
- [Networking and security](docs/networking-and-security.md)

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
