# MongoDB Helm Chart

MongoDB Helm chart using the **official [`mongo`](https://hub.docker.com/_/mongo) Docker image**. Supports standalone, replica set, and sharded cluster architectures — no Bitnami dependency.

## Install

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install mongodb helmforge/mongodb -f values.yaml
```

### OCI registry

```bash
helm install mongodb oci://ghcr.io/helmforgedev/helm/mongodb -f values.yaml
```

## Quick Start

```bash
# Standalone with auth
helm install mongodb helmforge/mongodb --set auth.rootPassword=changeme

# Replica set (3 members)
helm install mongodb helmforge/mongodb \
  --set architecture=replicaset \
  --set auth.rootPassword=changeme
```

## Architectures

| Mode | `architecture` | Description |
|------|---------------|-------------|
| **Standalone** | `standalone` | Single mongod instance (StatefulSet, 1 replica) |
| **Replica Set** | `replicaset` | N-member RS with automatic `rs.initiate()` via Helm hook Job |
| **Sharded** | `sharded` | Mongos routers + config servers + N shards, auto-initialized |

Read before choosing an architecture:

- [Standalone](docs/standalone.md)
- [Replica Set](docs/replicaset.md)
- [Sharded](docs/sharded.md)
- [Backup and Restore](docs/backup-restore.md)

## Key Features

- **Official `mongo` image** — no vendor lock-in, standard paths (`/data/db`)
- **Upgrade-safe credential generation** — generated root credentials and replica set keyFiles are retained with persistent data
- **Optional arbiter** — one lightweight voting member for cost-constrained replica sets
- **Helm hook Jobs** — idempotent `rs.initiate()` and shard registration
- **Prometheus exporter** — optional `percona/mongodb_exporter` sidecar + ServiceMonitor
- **Built-in S3 backups** — scheduled `mongodump` archive upload for standalone, replica set, and sharded topologies
- **Init scripts** — `.sh` and `.js` files via ConfigMap (`/docker-entrypoint-initdb.d/`)
- **Custom mongod.conf** — mount via ConfigMap
- **Security defaults** — `fsGroup: 999`, startup/liveness/readiness probes; optional strict
  non-root `securityContext`, `podSecurityContext`, and keyfile init-container
  `initContainerSecurityContext` for clusters that require it
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
  enabled: false
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

The sharded example is intentionally unauthenticated. The official MongoDB
container initializes `MONGO_INITDB_ROOT_*` as a standalone process, which is not
compatible with `--configsvr` or `--shardsvr`. Production sharded authentication
requires an operator-managed bootstrap flow outside this chart's automatic root
user initialization path.

### Replica Set with Arbiter

```yaml
architecture: replicaset
replicaSet:
  members: 2
arbiter:
  enabled: true
```

This topology creates two persistent data-bearing members and one arbiter with
ephemeral local storage. MongoDB recommends three data-bearing members when
capacity permits. Use an arbiter only when the cost of a third data copy is the
deciding constraint, and review the
[official arbiter considerations](https://www.mongodb.com/docs/manual/core/replica-set-arbiter/).

## Parameters

### Global

| Parameter | Description | Default |
|-----------|-------------|---------|
| `architecture` | `standalone`, `replicaset`, or `sharded` | `standalone` |
| `image.repository` | MongoDB image | `mongo` |
| `image.tag` | Image tag | `9.0.4` |
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
| `auth.replicaSetKeySecretPermissions` | KeyFile secret volume permission bits (`0440` for non-root init) | `0400` |

### Replica Set

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaSet.name` | Replica set name | `rs0` |
| `replicaSet.members` | Number of data-bearing members | `3` |
| `arbiter.enabled` | Add one non-data-bearing voting member | `false` |
| `arbiter.resources` | Arbiter container resources | `{}` |

### Sharded Cluster Parameters

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

### Backup

| Parameter | Description | Default |
|-----------|-------------|---------|
| `backup.enabled` | Enable built-in S3 backup CronJob | `false` |
| `backup.schedule` | Backup schedule | `"0 3 * * *"` |
| `backup.s3.endpoint` | S3-compatible endpoint URL | `""` |
| `backup.s3.bucket` | Target bucket name | `""` |
| `backup.database.mongoDumpArgs` | Extra `mongodump` flags | `""` |

### Service

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `27017` |
| `service.ipFamilyPolicy` | Service IP family policy (`SingleStack`, `PreferDualStack`, `RequireDualStack`) | `""` |
| `service.ipFamilies` | Service IP families override | `[]` |

### External Secrets

| Parameter | Description | Default |
|-----------|-------------|---------|
| `externalSecrets.enabled` | Render an ExternalSecret for MongoDB credentials | `false` |
| `externalSecrets.secretStoreRef.name` | SecretStore or ClusterSecretStore name | `""` |
| `externalSecrets.secretStoreRef.kind` | Secret store kind | `SecretStore` |
| `externalSecrets.data` | ExternalSecret data mappings for root credentials and backup secrets | `[]` |

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
| `automountServiceAccountToken` | Mount a Kubernetes API token in MongoDB pods and hook jobs | `false` |
| `podSecurityContext` | Pod-level security context (`fsGroup: 999` and RuntimeDefault seccomp) | `{"fsGroup":999,"seccompProfile":{"type":"RuntimeDefault"}}` |
| `securityContext` | Container-level security context (empty for compatibility) | `{}` |
| `initContainerSecurityContext` | Init container security context (root, CHOWN only) | `{"runAsNonRoot":false,"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"],"add":["CHOWN"]}}` |
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |

## Resources Generated

| Architecture | Resources |
|-------------|-----------|
| standalone | Secret, 2x Service (headless + client), StatefulSet |
| replicaset | 2x Secret (auth + keyfile), 2x Service, StatefulSet, Job (rs-init) |
| replicaset + arbiter | 2x Secret, 3x Service, 2x StatefulSet, Job (rs-init) |
| sharded | 2x Secret, 4x Service, 3x StatefulSet (config + shards), Deployment (mongos), Job (init) |

## Examples

See the [`examples/`](examples/) directory:

- [`standalone-simple.yaml`](examples/standalone-simple.yaml) — Minimal standalone instance
- [`replicaset-production.yaml`](examples/replicaset-production.yaml) — Production RS with monitoring, init scripts, and anti-affinity
- [`replicaset-arbiter.yaml`](examples/replicaset-arbiter.yaml) — Two data members with one voting arbiter
- [`sharded-cluster.yaml`](examples/sharded-cluster.yaml) — Full sharded cluster

## Architecture Guides

- [`docs/standalone.md`](docs/standalone.md) — when to use a single-node deployment
- [`docs/replicaset.md`](docs/replicaset.md) — when to use replica set topology and what it requires operationally
- [`docs/sharded.md`](docs/sharded.md) — when to use sharding, mongos, config servers, and multiple shards
- [`docs/backup-restore.md`](docs/backup-restore.md) — S3 backup strategy and restore guidance

## Upgrade Notes

### Upgrading to 9.0.4

MongoDB `9.0.4` contains stability improvements and bug fixes.
Review the [official 9.0 release notes](https://www.mongodb.com/docs/manual/release-notes/9.0/).

### Upgrading to 9.0.2

MongoDB `9.0.2` is a patch in the MongoDB `9.0` rapid-release line. Before a
binary upgrade from `8.3`, take a tested backup and confirm every member reports
`featureCompatibilityVersion: "8.3"`. Upgrade using the topology-specific
upstream procedure, then raise FCV to `9.0` only after all members are healthy
and rollback is no longer required. Review the
[MongoDB 9.0 release notes](https://www.mongodb.com/docs/manual/release-notes/9.0/)
before reusing existing PVCs.
The chart keeps generated root credentials and replica set keyFiles stable
across `helm upgrade`, including upgrades with `--reset-values` or
`--reuse-values`, and retains them when persistent releases are removed. These
credentials are bound to the initialized data directory. Rotate them with
MongoDB administrative commands and a coordinated Secret update instead of
changing initialization values. Back up both the PVC data and its credential
Secrets; restoring only one side can make the database inaccessible.

StatefulSet claim-template sizes are immutable. During upgrades the chart keeps
the size already applied to each MongoDB StatefulSet, including when
`--reset-values` would otherwise restore the default and make Kubernetes reject
the upgrade. Resize the bound PVCs through the storage class workflow; updating
`persistence.size` alone does not resize an existing claim.
It also does not change the size used for PVCs created by future scale-up.
Before adding members after expanding existing PVCs, confirm that the retained
claim-template size can hold a new member's initial synchronization.

Enabling or disabling `arbiter.enabled` on an existing replica set reconciles
the arbiter membership through the post-upgrade hook. Increasing
`replicaSet.members` adds missing data-bearing members. Reducing that value does
not remove members from the MongoDB configuration; remove members safely with
MongoDB administrative procedures before scaling down the StatefulSet.

MongoDB requires a global default write concern before a reconfiguration that
would change its implicit value. When arbiter reconciliation encounters an
implicit default, the hook preserves the currently effective value (`w: 1` or
`majority`) by promoting it to a global default. Existing operator-managed
global defaults are not changed. The same preservation runs before adding a
missing data-bearing member because scale-up can also change the implicit
default. MongoDB 5.0 and newer do not allow a global default write concern to be
unset after it is established.

## Security Scan

Security Scan: Kubescape local scan against `MITRE,NSA,SOC2` reports a 72.73% resource summary score.

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
| License | Apache-2.0 | Custom (restricted image terms) |
| values.yaml | ~200 lines | ~2000+ lines |
| Templates | ~15 files | ~30+ files |
| Dependencies | None | `bitnami/common` library |
| User ID | 999 (mongodb) | 1001 (bitnami) |

When migrating, you'll need to handle the data directory path change. For existing PVCs,
use an init container to move data from `/bitnami/mongodb` to `/data/db`,
or create new volumes and restore from backup.
