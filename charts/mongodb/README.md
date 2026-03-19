# MongoDB Helm Chart

MongoDB Helm chart using the **official [`mongo`](https://hub.docker.com/_/mongo) Docker image**. Supports standalone, replica set, and sharded cluster architectures — no Bitnami dependency.

## Quick Start

```bash
# Standalone with auth
helm install mongodb oci://ghcr.io/mberlofa/helm/mongodb \
  --set auth.rootPassword=changeme

# Replica set (3 members)
helm install mongodb oci://ghcr.io/mberlofa/helm/mongodb \
  --set architecture=replicaset \
  --set auth.rootPassword=changeme

# From a values file
helm install mongodb oci://ghcr.io/mberlofa/helm/mongodb -f values.yaml
```

## Architectures

| Mode | `architecture` | Description |
|------|---------------|-------------|
| **Standalone** | `standalone` | Single mongod instance (StatefulSet, 1 replica) |
| **Replica Set** | `replicaset` | N-member RS with automatic `rs.initiate()` via Helm hook Job |
| **Sharded** | `sharded` | Mongos routers + config servers + N shards, auto-initialized |

## Key Features

- **Official `mongo` image** — no vendor lock-in, standard paths (`/data/db`)
- **Auto keyFile generation** — replica set internal auth handled automatically
- **Helm hook Jobs** — idempotent `rs.initiate()` and shard registration
- **Prometheus exporter** — optional `percona/mongodb_exporter` sidecar + ServiceMonitor
- **Init scripts** — `.sh` and `.js` files via ConfigMap (`/docker-entrypoint-initdb.d/`)
- **Custom mongod.conf** — mount via ConfigMap
- **Security defaults** — `fsGroup: 999`, startup/liveness/readiness probes
- **Extra manifests** — inject arbitrary K8s resources with Helm templating

## Configuration

### Minimal (Standalone)

```yaml
architecture: standalone
auth:
  enabled: true
  rootPassword: "my-secret-password"
persistence:
  size: 10Gi
```

### Replica Set (Production)

```yaml
architecture: replicaset
auth:
  enabled: true
  existingSecret: mongodb-credentials  # keys: mongodb-root-username, mongodb-root-password
replicaSet:
  name: rs0
  members: 3
persistence:
  size: 50Gi
resources:
  requests:
    cpu: 500m
    memory: 2Gi
  limits:
    cpu: "2"
    memory: 4Gi
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

### Sharded Cluster

```yaml
architecture: sharded
auth:
  enabled: true
  rootPassword: "changeme"
sharded:
  mongos:
    replicaCount: 2
  configServer:
    replicaCount: 3
    persistence:
      size: 8Gi
  shards:
    count: 2
    membersPerShard: 3
    persistence:
      size: 50Gi
```

## Parameters

### Global

| Parameter | Description | Default |
|-----------|-------------|---------|
| `architecture` | `standalone`, `replicaset`, or `sharded` | `standalone` |
| `image.repository` | MongoDB image | `mongo` |
| `image.tag` | Image tag | `8.2.6` |
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full release name | `""` |

### Authentication

| Parameter | Description | Default |
|-----------|-------------|---------|
| `auth.enabled` | Enable MongoDB authentication | `true` |
| `auth.rootUser` | Root username | `root` |
| `auth.rootPassword` | Root password (auto-generated if empty) | `""` |
| `auth.existingSecret` | Existing secret with credentials | `""` |
| `auth.replicaSetKey` | KeyFile content (auto-generated if empty) | `""` |
| `auth.existingKeySecret` | Existing secret with keyFile | `""` |

### Replica Set

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaSet.name` | Replica set name | `rs0` |
| `replicaSet.members` | Number of data-bearing members | `3` |

### Sharded Cluster

| Parameter | Description | Default |
|-----------|-------------|---------|
| `sharded.mongos.replicaCount` | Number of mongos routers | `2` |
| `sharded.mongos.port` | Mongos port | `27017` |
| `sharded.configServer.replicaCount` | Config server members | `3` |
| `sharded.configServer.persistence.size` | Config server PVC size | `8Gi` |
| `sharded.shards.count` | Number of shards | `2` |
| `sharded.shards.membersPerShard` | Members per shard RS | `3` |
| `sharded.shards.persistence.size` | Shard PVC size | `16Gi` |

### Persistence

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.enabled` | Enable PVC via volumeClaimTemplate | `true` |
| `persistence.storageClass` | Storage class (empty = default) | `""` |
| `persistence.accessMode` | PVC access mode | `ReadWriteOnce` |
| `persistence.size` | PVC size | `8Gi` |

### Resources & Probes

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources` | CPU/memory requests and limits | `{}` |
| `livenessProbe` | Liveness probe config | `mongosh ping, 30s delay` |
| `readinessProbe` | Readiness probe config | `mongosh ping, 10s delay` |
| `startupProbe` | Startup probe config | `mongosh ping, 5s delay, 30 failures` |

### Metrics

| Parameter | Description | Default |
|-----------|-------------|---------|
| `metrics.enabled` | Deploy mongodb-exporter sidecar | `false` |
| `metrics.image.repository` | Exporter image | `percona/mongodb_exporter` |
| `metrics.image.tag` | Exporter tag | `0.49.0` |
| `metrics.port` | Exporter port | `9216` |
| `metrics.serviceMonitor.enabled` | Create ServiceMonitor | `false` |

### Service

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `27017` |

### Other

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config` | Custom mongod.conf (YAML) | `{}` |
| `initdbScripts` | Init scripts for first startup | `{}` |
| `initdbDatabase` | Database for init scripts | `""` |
| `extraEnv` | Extra environment variables | `[]` |
| `extraVolumes` | Extra volumes | `[]` |
| `extraVolumeMounts` | Extra volume mounts | `[]` |
| `extraManifests` | Arbitrary K8s manifests | `[]` |
| `podSecurityContext.fsGroup` | Pod filesystem group | `999` |
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |

## Resources Generated

| Architecture | Resources |
|-------------|-----------|
| standalone | Secret, 2x Service (headless + client), StatefulSet |
| replicaset | 2x Secret (auth + keyfile), 2x Service, StatefulSet, Job (rs-init) |
| sharded | 2x Secret, 4x Service, 3x StatefulSet (config + shards), Deployment (mongos), Job (init) |

## Examples

See the [`examples/`](examples/) directory:

- [`standalone-simple.yaml`](examples/standalone-simple.yaml) — Minimal standalone instance
- [`replicaset-production.yaml`](examples/replicaset-production.yaml) — Production RS with monitoring, init scripts, and anti-affinity
- [`sharded-cluster.yaml`](examples/sharded-cluster.yaml) — Full sharded cluster

## Connection Strings

```bash
# Standalone
mongodb://root:password@<release>-mongodb.<namespace>.svc.cluster.local:27017/admin

# Replica Set (from within the cluster)
mongodb://root:password@<release>-mongodb-0.<release>-mongodb-headless.<namespace>.svc.cluster.local:27017,<release>-mongodb-1.<release>-mongodb-headless.<namespace>.svc.cluster.local:27017,<release>-mongodb-2.<release>-mongodb-headless.<namespace>.svc.cluster.local:27017/admin?replicaSet=rs0

# Sharded (connect via mongos)
mongodb://root:password@<release>-mongodb-mongos.<namespace>.svc.cluster.local:27017/admin
```

## Migrating from Bitnami

Key differences from the Bitnami MongoDB chart:

| Aspect | This chart | Bitnami |
|--------|-----------|---------|
| Image | Official `mongo` | `bitnami/mongodb` |
| Data path | `/data/db` | `/bitnami/mongodb` |
| License | MIT | Custom (restricted) |
| values.yaml | ~200 lines | ~2000+ lines |
| Templates | ~15 files | ~30+ files |
| Dependencies | None | `bitnami/common` library |
| User ID | 999 (mongodb) | 1001 (bitnami) |

When migrating, you'll need to handle the data directory path change. For existing PVCs, use an init container to move data from `/bitnami/mongodb` to `/data/db`, or create new volumes and restore from backup.
