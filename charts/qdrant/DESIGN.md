# Qdrant Chart Design

This chart packages Qdrant as a Kubernetes StatefulSet because Qdrant stores collection segments, WAL data, and snapshots on local disk.
The default topology is a single persistent pod suitable for small production or development vector search workloads where the cluster provides
durable storage and the operator manages backup policy.

## Runtime Model

- Workload: StatefulSet.
- Client APIs: HTTP on `6333`, gRPC on `6334`.
- Peer traffic: p2p on `6335`, exposed only through the headless service.
- Storage: generated per-pod PVC by default, mounted at `/qdrant/storage`.
- Snapshots: persisted under `/qdrant/storage/snapshots`.
- Configuration: chart-managed `QDRANT__...` environment variables plus optional `/qdrant/config/local.yaml`.

## Security Model

Qdrant supports API keys through `service.api_key` and read-only API keys through `service.read_only_api_key`.
The chart maps those settings to Kubernetes Secrets and environment variables.
Inline values exist for test and lab use, but production examples use `auth.existingSecret`.

The pod does not need Kubernetes API access, so the default ServiceAccount is used with `automountServiceAccountToken=false`.

## Distributed Mode

Qdrant distributed mode is available but not treated as a casual replica toggle.
Distributed deployments require Qdrant cluster knowledge, persistent per-pod volumes, and careful snapshot/restore planning.
The chart therefore requires:

- `replicaCount >= 2`
- `persistence.enabled=true`
- no shared `persistence.existingClaim`

The headless service gives pods stable peer DNS names and exposes the p2p port internally.

## Monitoring

Qdrant exposes Prometheus metrics on `/metrics`.
The chart provides an optional ServiceMonitor but keeps it disabled by default so clusters without Prometheus Operator CRDs can render and
install the default chart.

## Non-Goals

- Managing Qdrant collections as Kubernetes custom resources.
- Automating cross-node snapshot restore.
- Replacing the Qdrant Private Cloud operator for zero-downtime enterprise operations.
