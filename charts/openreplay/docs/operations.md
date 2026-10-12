# Operations

## Prerequisites

Use Kubernetes 1.31 or newer on amd64 nodes. Upstream states a minimum of 2
vCPU, 8 GiB memory, and 50 GiB storage for low/moderate traffic. Production
sizing depends on sessions, event rate, retention, and replay concurrency.

HTTPS is required for tracker recording and replay outside isolated testing.
Backend 1.28 must be paired with tracker 19.x and Assist 11.x.

## Upgrade

Back up every durable store before upgrade. The revision-scoped migration Job changes
PostgreSQL, ClickHouse, and S3 data and cannot be rolled back by Helm `--atomic`.
The version ConfigMap blocks chart downgrades unless
`migration.allowDowngrade=true`; bypass it only after restoring data compatible
with the older version.

## Backup and restore

A complete backup includes PostgreSQL, ClickHouse, object storage, the
credential Secret, and relevant RWX/Valkey in-flight state. Quiesce ingestion or
coordinate snapshots across all stores. Restore data services and credentials,
verify connectivity, and only then run migrations and application workloads.

## Troubleshooting

Inspect all component pods with the release instance label. Check the migration
Job before debugging application crash loops. A router 502 normally means the
target component is disabled or not Ready. Persistent pending pods usually mean
the cluster lacks an RWX provisioner. On ARM nodes, application pods remain
unschedulable by design because upstream publishes only amd64 images.
