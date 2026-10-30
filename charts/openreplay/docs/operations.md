<!-- SPDX-License-Identifier: Apache-2.0 -->

# Operations

## Prerequisites

Use Kubernetes 1.31 or newer on amd64 nodes. Upstream states a minimum of 2 vCPU, 8 GiB memory, and 50 GiB storage for
low/moderate traffic. Production sizing depends on sessions, event rate, retention, and replay concurrency. HTTPS is
required for tracker recording and replay outside isolated testing. Backend 1.28 must be paired with tracker 19.x and
Assist 11.x.

## Health verification

Confirm the migration Job before evaluating application readiness:

```bash
kubectl -n openreplay get jobs,pods,svc
kubectl -n openreplay logs job/openreplay-migration --all-containers
kubectl -n openreplay wait deployment/openreplay-router --for=condition=Available --timeout=10m
kubectl -n openreplay get endpointslices -l kubernetes.io/service-name=openreplay
```

Then record and replay a synthetic session through the public HTTPS endpoint. Pod readiness proves only local component
health; it does not prove tracker ingestion, object storage, analytics persistence, WebSockets, or replay delivery.

## Upgrade

Back up every durable store before upgrade. The revision-scoped migration Job changes PostgreSQL, ClickHouse, and S3 data
and cannot be rolled back by Helm `--atomic`. The version ConfigMap blocks chart downgrades unless
`migration.allowDowngrade=true`; bypass it only after restoring data compatible with the older version.

Use `helm diff` or rendered manifests to review image, listener, dependency, storage, and policy changes. Keep the old
release running until backups are verified. After upgrade, inspect the migration Job first, then component rollouts,
router health, ingestion, replay, and Assist. Do not rely on `helm rollback` to reverse database or object-store changes.

## Backup and restore

A complete backup includes PostgreSQL, ClickHouse, object storage, the credential Secret, and relevant RWX/Redis in-flight
state. Quiesce ingestion or coordinate snapshots across all stores.

### Backup checklist

1. Quiesce or sharply reduce ingestion so stores converge on a known point.
2. Back up PostgreSQL with a transactionally consistent database-native method.
3. Back up ClickHouse tables using a version-compatible snapshot or backup workflow.
4. Replicate every configured S3 bucket, including recordings, assets, sourcemaps, and spots.
5. Export the credential Secret through an approved encrypted secret-management workflow.
6. Protect relevant scratch and Redis state when the selected recovery objective requires in-flight work.
7. Record the chart AppVersion, image digests, dependency versions, and migration version ConfigMap with the backup.
8. Restore into an isolated namespace and prove login, recording, ingestion, replay, and Assist before accepting it.

### Restore order

Restore credentials and external endpoints first, followed by PostgreSQL, ClickHouse, object storage, and any required
Redis or scratch state. Validate each service directly. Install the exact compatible chart version with migrations held
until all stores are ready, then enable migrations and watch their logs. Start application workloads only after the schema
is consistent. A partial restore can produce valid health probes while replay data is missing or incompatible.

## Capacity management

Watch PVC consumption, RustFS capacity, ClickHouse partitions, PostgreSQL growth, queue delay, component memory, restarts,
and ingestion latency. The default requests are scheduling baselines, not production sizing. Increase capacity before a
store reaches its eviction or read-only threshold. For multi-node workers, validate RWX throughput and failure behavior;
changing only `replicaCount` does not remove storage bottlenecks.

## Listener changes

When overriding ports, verify every layer:

```bash
helm template openreplay oci://ghcr.io/helmforgedev/helm/openreplay \
  --set router.containerPorts.http=18080 \
  --set rustfs.containerPorts.s3=19000 \
  --set rustfs.service.ports.s3=20000
```

Caddy's address and RustFS environment variables must match their container ports. Kubernetes Service ports may differ,
but must keep their named `targetPort`. The chart's `ci/ports-values.yaml` scenario exercises this contract against real
processes in k3d.

## Troubleshooting

Inspect all component pods with the release instance label. Check the migration Job before debugging application crash
loops. A router 502 normally means the target component is disabled or not Ready. Persistent pending pods usually mean the
cluster lacks an RWX provisioner. On ARM nodes, application pods remain unschedulable by design because upstream publishes
only amd64 images.

## Incident response

For ingestion loss, first preserve evidence: component logs, migration logs, events, endpoint slices, store health, and the
rendered release values. Determine whether the failure is at the edge, Caddy route, component Service, queue, scratch
volume, database, or object store. Avoid rerunning migrations or rotating credentials until backups and the active schema
version are confirmed. For suspected credential exposure, restrict network access, snapshot relevant audit evidence,
rotate the complete shared contract in a maintenance window, restart all consumers, and validate both old-session replay
and new ingestion.
