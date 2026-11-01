# Qdrant Helm Chart

Qdrant is a vector database and similarity search engine for embeddings, payload filters, semantic search, retrieval-augmented generation,
recommendation, and matching workloads.
This HelmForge chart deploys the official `docker.io/qdrant/qdrant:v1.19.2` image with persistent storage, HTTP and gRPC services,
optional API key authentication, snapshot storage, Prometheus scraping, and guarded distributed-mode settings.

## Features

- Persistent StatefulSet identity with one generated PVC per Qdrant replica.
- Named HTTP, gRPC and internal p2p ports with configurable Service ports.
- API-key and read-only-key authentication from inline values or an existing Secret.
- Verified non-root UID/GID 1000 fallback, read-only root filesystem, dropped capabilities and RuntimeDefault seccomp.
- Startup, readiness and liveness probes plus optional Prometheus Operator ServiceMonitor.
- Kubernetes Ingress, Gateway API HTTPRoute, dual-stack Service and opt-in NetworkPolicy.
- Guarded distributed bootstrap with stable peer DNS and per-pod storage.
- Optional local Qdrant configuration, scheduling controls and raw extra manifests.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install qdrant helmforge/qdrant
```

The default deployment is a single persistent StatefulSet with:

- HTTP API on port `6333`
- gRPC API on port `6334`
- peer discovery service with Qdrant p2p port `6335`
- storage mounted at `/qdrant/storage`
- snapshots stored under `/qdrant/storage/snapshots`

Inspect every supported value before installation:

```bash
helm show values helmforge/qdrant
```

## Production Configuration

Use an existing Secret for API keys in production:

```yaml
auth:
  existingSecret: qdrant-api-keys
  apiKeyKey: api-key
  readOnlyApiKeyKey: read-only-api-key
```

For environment-specific Qdrant options, prefer `config.localYaml` for structured configuration and `app.env` for targeted `QDRANT__...` overrides:

```yaml
config:
  localYaml: |
    log_level: INFO
    storage:
      performance:
        max_search_threads: 4
```

Key defaults are summarized below. `values.yaml` and `values.schema.json` remain the complete contract.

| Parameter | Default | Purpose |
| --- | --- | --- |
| `image.repository` | `docker.io/qdrant/qdrant` | Official image repository |
| `image.tag` | `v1.19.2` | Pinned Qdrant version |
| `replicaCount` | `1` | StatefulSet replicas |
| `app.port` | `6333` | Real Qdrant HTTP listener |
| `app.grpcPort` | `6334` | Real Qdrant gRPC listener |
| `cluster.enabled` | `false` | Enable distributed peer bootstrap |
| `cluster.p2pPort` | `6335` | Internal peer listener |
| `persistence.enabled` | `true` | Persist collection and WAL data |
| `persistence.size` | `10Gi` | Capacity of each generated claim |
| `persistence.existingClaim` | `""` | Single-node existing claim |
| `snapshots.path` | `/qdrant/storage/snapshots` | Native snapshot directory |
| `service.port` | `6333` | HTTP Service port |
| `service.grpcPort` | `6334` | gRPC Service port |
| `networkPolicy.enabled` | `false` | Render client and peer isolation |
| `metrics.serviceMonitor.enabled` | `false` | Render a Prometheus ServiceMonitor |
| `pdb.enabled` | `false` | Protect replicas from voluntary disruption |

Empty `podSecurityContext` and `securityContext` values activate the verified built-in hardening profile when effective
storage, snapshot, temporary and initialization paths are under the persistent data path. A non-empty context replaces
that profile as a whole, preserving existing custom UID, GID and filesystem policies during upgrades. An explicit
container `runAsUser: 0` or an external effective path suppresses the pod identity fallback to preserve compatible
root-owned paths. The default profile repairs nested PVC permissions recursively and stores Qdrant's initialization
marker on the data volume.

## Examples

Start with [simple values](examples/simple.yaml), [production values](examples/production.yaml) or the guarded
[distributed example](examples/distributed.yaml). Production deployments should also read
[operations](docs/operations.md), [security](docs/security.md), [snapshots](docs/snapshots.md) and
[distributed mode](docs/distributed.md).

## Architecture

The chart uses a StatefulSet because Qdrant stores collection segments, WAL data and snapshots on persistent local
storage. A client Service exposes HTTP and gRPC, while a headless Service gives distributed replicas stable peer DNS.
Generated claims are per-pod; a shared existing claim is rejected in distributed mode. See [DESIGN.md](DESIGN.md) for
the Mermaid topology, security boundary, production responsibilities and non-goals.

## Distributed Mode

Distributed mode is intentionally guarded. Enable it only when you understand Qdrant cluster operations and have persistent per-pod volumes:

```yaml
replicaCount: 3
cluster:
  enabled: true
pdb:
  enabled: true
```

The chart fails rendering when `cluster.enabled=true` is combined with one replica, disabled persistence, or a shared `persistence.existingClaim`.
When enabled, the StatefulSet starts ordinal 0 with a stable `--uri`; later pods join through `--bootstrap` and publish their own stable peer URI.

## Network Policy

`networkPolicy.enabled=true` restricts inbound HTTP and gRPC traffic to the configured `networkPolicy.ingressFrom` peers, or to all
namespaces when `ingressFrom` is empty. Cluster p2p ingress is allowed from Qdrant pods when `cluster.enabled=true`.

Set `networkPolicy.extraEgress` to enable egress isolation and append custom egress rules. The chart preserves DNS and broad HTTPS
egress to any IPv4/IPv6 destination, and also preserves Qdrant p2p egress between pods when distributed mode is enabled. Additional
rules cannot narrow the broad HTTPS rule; replace the generated NetworkPolicy when HTTPS destinations must be restricted:

```yaml
networkPolicy:
  enabled: true
  extraEgress:
    - to:
        - ipBlock:
            cidr: 10.0.0.0/8
      ports:
        - protocol: TCP
          port: 6333
```

## Monitoring

Qdrant exposes Prometheus metrics on `/metrics`. Enable a ServiceMonitor when Prometheus Operator CRDs are installed:

```yaml
metrics:
  serviceMonitor:
    enabled: true
    labels:
      release: prometheus
```

The generated ServiceMonitor sends no API-key credentials. When authentication protects `/metrics`, keep it disabled and create a
separately managed ServiceMonitor with the required authenticated scrape configuration.

## Security

The official image declares root, but this chart's empty security-context defaults render a verified UID/GID 1000
profile with fsGroup ownership, RuntimeDefault seccomp, no privilege escalation, all capabilities dropped and a
read-only image filesystem when all effective storage paths are inside `persistence.mountPath`. Effective paths include
chart values, `app.env` and `app.extraEnv` overrides, and a configured `storage.temp_path`. If any path is outside the
data volume or cannot be determined from a `valueFrom`, the fallback preserves the image's root identity and writable
filesystem so existing root-owned paths and storage workflows continue to operate.
The persistent storage mount remains writable. This profile was validated by upgrading a published root-running
installation with existing vector data on its PVC.

Authentication is disabled until an API key is configured. Never expose that default to an untrusted network. Use
`auth.existingSecret`, TLS at the ingress or Gateway, narrow client peers and a CNI-enforced NetworkPolicy. The
ServiceAccount token remains disabled because Qdrant does not need Kubernetes API access.

## Upgrade compatibility

Back up native snapshots outside the source PVC before application upgrades. A normal upgrade adopts the verified
non-root profile when security contexts were empty; existing non-empty custom contexts are rendered unchanged. The
published chart's root-owned PVC was tested in place under fsGroup/UID 1000, preserving and querying pre-upgrade vector
data. `--reuse-values` is tested separately because it preserves stored overrides and may retain an older image value.

StatefulSet name, pod identity, Service names and generated claim templates remain stable. Helm rollback changes
manifests but does not reverse Qdrant data-format changes, so restore testing remains mandatory.

## Troubleshooting

Inspect rollout, storage and logs before changing probes or deleting data:

```bash
kubectl get statefulset,pods,pvc -l app.kubernetes.io/instance=qdrant
kubectl logs statefulset/qdrant-qdrant
kubectl describe pod -l app.kubernetes.io/instance=qdrant
```

Permission failures after a custom security-context change usually indicate that the explicit UID/GID no longer matches
the PVC. Cluster join failures should be checked against stable headless DNS, unique per-pod claims and p2p connectivity.
If ServiceMonitor resources do not render or reconcile, confirm the Prometheus Operator CRDs exist before enabling the
feature. Never delete a claim to resolve a rollout problem until a tested snapshot exists elsewhere.

## Security Scan: `qdrant`

| Framework | Score |
|---|---|
| Overall | **75.76%** |
| MITRE | **100.00%** |
| NSA | **65.00%** |
| SOC2 | **80.00%** |

> Security posture acceptable.

## Documentation

- [Operations](docs/operations.md)
- [Security](docs/security.md)
- [Snapshots](docs/snapshots.md)
- [Distributed mode](docs/distributed.md)
- [Qdrant configuration](https://qdrant.tech/documentation/ops-configuration/configuration/)
- [Qdrant monitoring](https://qdrant.tech/documentation/ops-monitoring/monitoring/)
- [Qdrant snapshots](https://qdrant.tech/documentation/snapshots/)
