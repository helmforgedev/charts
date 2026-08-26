# High Availability

## Museum jobs

Every Museum process starts scheduled jobs and background cleanup unless
`jobs.cron.skip=true`. Some jobs use database locks, but not all of them do.
Scaling a default Museum Deployment therefore risks duplicate work.

## Supported topology

Set API replicas to two or more, enable `skipBackgroundJobs`, and enable the
singleton worker. The worker runs the same Museum image without a public
Service. Its Deployment uses `Recreate` so rolling updates do not overlap job
schedulers.

```yaml
museum:
  api:
    replicaCount: 3
    skipBackgroundJobs: true
  worker:
    enabled: true
  migrationGate:
    enabled: true
```

The chart validates the relationship and rejects unsafe combinations.

## Database availability

The bundled PostgreSQL standalone mode does not provide automatic failover.
Use a managed service or PostgreSQL operator with a stable read-write endpoint
for end-to-end HA.

## Web availability

Web pods are stateless after startup. Scale them independently and enable their
PDB. HPA requires resource requests and a working metrics API.

## Migration serialization

All Museum instances run database migrations during startup. Concurrent first
starts can conflict on migrations such as `CREATE INDEX CONCURRENTLY` and leave
the database version dirty.

For HA and Museum HPA topologies, the chart runs a PostgreSQL client sidecar in
each Museum pod. It polls `pg_try_advisory_lock` without retaining an active
transaction, writes a pod-local start marker, and waits for the local Museum
port before releasing the lock. API and worker processes therefore start one at
a time. The sidecar remains idle after release so the pod does not restart it.

The chart rejects concurrent Museum processes when
`museum.migrationGate.enabled=false`. Inspect `-c migration-gate` and
`-c museum` logs together when a rollout waits at startup. Keep the worker on
`Recreate` to avoid overlapping job schedulers.

## Ente replication

Ente object replication starts workers in every Museum process even when cron
jobs are skipped. It also requires multiple hot and derived buckets. It is not
enabled by this chart's default contract and is not a substitute for backup.
