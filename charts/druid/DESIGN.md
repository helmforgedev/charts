# Apache Druid Chart Design

## Purpose

This chart packages Apache Druid as a production-oriented Kubernetes deployment
with explicit control over the Druid process topology, metadata storage,
ZooKeeper coordination, deep storage, router exposure, and security posture.

Druid is not a single-process database. It is a distributed analytics system
where each component owns a different responsibility:

- Coordinator manages segment availability and retention rules.
- Overlord manages ingestion task scheduling.
- Broker receives queries and fans them out to data servers.
- Router exposes the web console and routes API traffic.
- Historical serves immutable published segments from cache.
- MiddleManager runs ingestion tasks and writes task artifacts.

The chart keeps those roles as separate Kubernetes resources so operators can
scale, tune, and troubleshoot them independently.

## Workload Model

The chart uses StatefulSets for components that benefit from stable network
identity or local working state:

- `coordinator`
- `overlord`
- `historical`
- `middlemanager`
- bundled `zookeeper`

The chart uses Deployments for query-facing stateless components:

- `broker`
- `router`

Historical and MiddleManager receive dedicated PVC templates by default because
they maintain segment cache and task working data. Coordinator, Overlord,
Broker, and Router use ephemeral `druid-var` volumes for local runtime state.

## Metadata Storage

Druid metadata is stored in PostgreSQL by default through the HelmForge
PostgreSQL subchart. This gives a working installation without requiring an
external database.

For production platforms that already run managed PostgreSQL or MySQL, the
chart supports `metadata.mode=external`. In that mode the chart can either:

- create a password Secret from `metadata.external.password`, or
- consume an operator-managed Secret through `metadata.external.existingSecret`.

The existing Secret path is preferred for production because it avoids storing
credential material in Helm values.

## ZooKeeper Coordination

The chart includes a bundled ZooKeeper StatefulSet for self-contained clusters.
It can be disabled with `zookeeper.enabled=false` and
`zookeeperConfig.mode=external` when the platform already provides a ZooKeeper
ensemble.

Bundled ZooKeeper defaults to one replica. Operators can raise
`zookeeper.replicaCount` for a real ensemble, but should also size persistent
storage and scheduling rules accordingly.

## Deep Storage

Druid deep storage is the durable segment authority. The default
`deepStorage.type=local` is intentionally simple and useful for development,
CI, and small lab deployments. It is not a production HA design because segment
publication depends on local filesystem state inside the release.

Production deployments should use `deepStorage.type=s3` with AWS S3 or an
S3-compatible service such as MinIO. The chart supports direct credentials for
development and existing Secrets for production. When S3 credentials are
operator-managed, `externalSecrets.deepStorage.enabled=true` can render the
ExternalSecret that creates the Secret consumed by Druid.

## Network Exposure

The router is the only public-facing component in the default model. The chart
exposes it through:

- a ClusterIP Service by default,
- optional Ingress with `ingress.ingressClassName`, or
- optional Gateway API HTTPRoute for clusters with shared Gateways.

The Gateway API implementation intentionally references a Gateway created by
the platform. This keeps TLS termination, listener policy, and cross-namespace
Gateway ownership outside the application chart.

## Security Model

Druid containers run as UID/GID `1000`, disallow privilege escalation, drop all
Linux capabilities, and use the runtime default seccomp profile. The
`prepare-dirs` init container runs as root only long enough to create and chown
writable Druid directories, using the minimal baseline-compatible capability
set required for that task.

NetworkPolicy is opt-in. Druid often needs access to PostgreSQL, ZooKeeper, S3,
extension endpoints, DNS, and cluster-local services. Enabling a restrictive
egress policy without modeling those dependencies can break ingestion and
segment serving, so the chart exposes explicit egress switches and `extraTo`
rules instead of default-denying traffic silently.

## Operational Trade-offs

This chart favors explicit component controls over a compact single
configuration block. That makes the values surface larger, but gives operators
the Druid-specific knobs they need for JVM sizing, per-role replica counts,
component labels, annotations, and runtime properties.

The chart does not create buckets, databases, TLS issuers, Gateways, or external
SecretStores. Those resources are platform concerns and should be managed by
the owning infrastructure team.

## Validation Strategy

The chart is validated through HelmForge's standard gate:

- dependency build and dependency list,
- strict Helm lint,
- default and CI scenario rendering,
- helm-unittest coverage for each template family,
- kubeconform with real CRD schemas,
- ArtifactHub lint,
- k3d behavioral installation and cleanup.

The CI values cover default mode, minimal topology, S3 deep storage, external
metadata, External Secrets, Gateway API, dual-stack Services, and NetworkPolicy.
