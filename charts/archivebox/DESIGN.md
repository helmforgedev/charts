# ArchiveBox Chart Design

## Purpose

The `archivebox` chart deploys a single-node ArchiveBox installation for
self-hosted web archiving. It is optimized for reliable persistent storage,
Chromium-based captures, simple administrative bootstrap, and optional
scheduled S3-compatible backups.

ArchiveBox stores both its SQLite database and archived snapshots under
`/data`. The chart therefore treats persistence as the primary production
boundary and intentionally runs one application replica with a `Recreate`
strategy.

## Workload Model

The chart renders one `Deployment` with a single `archivebox` container. The
container runs:

```text
archivebox server --quick-init 0.0.0.0:<archivebox.port>
```

Key workload decisions:

- `replicas` is fixed at `1` because SQLite is a single-writer datastore.
- The deployment uses `Recreate` to avoid concurrent writers against the same
  data directory during rollout.
- `/data` is backed by a PVC when persistence is enabled.
- `/dev/shm` is mounted as a memory-backed `emptyDir` so Chromium has shared
  memory available for page rendering.
- Startup, liveness, and readiness probes use the ArchiveBox health endpoint.

## Storage Model

ArchiveBox is storage-heavy. The PVC contains:

- SQLite application database.
- Snapshot metadata.
- Captured HTML, PDFs, screenshots, WARC files, media, and derived indexes.

The default `persistence.size` is `50Gi`, which is suitable for evaluation and
small archives. Production installations should size the PVC from expected URL
volume, capture formats, and retention policy.

## Access Model

The chart exposes the workload through a ClusterIP `Service` by default.
Ingress is optional and defaults to the `traefik` ingress class when enabled.

Administrative access is controlled by Kubernetes Secret data. Operators can
either provide `archivebox.adminPassword` for chart-managed Secret creation or
reference an existing Secret with `archivebox.existingSecret`.

ArchiveBox public visibility is controlled by:

- `archivebox.publicIndex`
- `archivebox.publicSnapshots`
- `archivebox.publicAddLinks`
- `archivebox.allowedHosts`

## Backup Model

When `backup.enabled=true`, the chart creates:

- A ConfigMap with backup and upload scripts.
- A Secret for S3 credentials, unless an existing Secret is used.
- A CronJob that tars `/data` and uploads the archive with MinIO Client.

The backup CronJob is deliberately volume-level. It captures the SQLite
database and snapshot files together from the same PVC. For production use,
schedule backups during low write activity and test restore procedures before
depending on the backup pipeline.

## Security Posture

The chart uses the official `archivebox/archivebox` image pinned by tag. The
default pod security model runs as the upstream non-root UID/GID `911` and sets
`fsGroup` to match the data volume.

Security tradeoffs:

- The root filesystem is writable because ArchiveBox and its browser tooling
  write runtime state.
- Resource limits are intentionally operator-configured because Chromium
  resource needs vary significantly by capture workload.
- NetworkPolicy is not rendered by this chart; enforce ingress and egress
  policy at the namespace or platform layer when required.

## Operational Expectations

Production operators should configure:

- A durable storage class and an appropriately sized PVC.
- Explicit CPU and memory requests and limits for Chromium captures.
- An existing Secret for the admin password.
- Ingress TLS and an `allowedHosts` value matching the public host.
- S3-compatible backups and a tested restore workflow.

## Validation

The chart is validated with the HelmForge chart gate:

```bash
make validate-chart CHART=archivebox
```

Security posture is tracked with Kubescape:

```bash
kubescape scan framework "MITRE,NSA,SOC2" charts/archivebox
```

Latest local scan during this standards backfill:

- MITRE: 100.00%
- NSA: 65.00%
- SOC2: 80.00%
- Aggregate resource score: 75.76%
