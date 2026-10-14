# Temporal Operations

## Initial Bootstrap

Watch PostgreSQL readiness and the schema Job before investigating server pods:

```bash
kubectl -n temporal get pods,jobs -w
kubectl -n temporal logs job/temporal-temporal-schema-1
```

The four server workloads wait on schema version discovery. History runs as an
ordered StatefulSet to serialize cluster metadata bootstrap; the other roles
run as Deployments. A wait failure
usually means database DNS, credentials, database ownership, or schema setup is
wrong. Validate both `temporal` and `temporal_visibility` databases.

## Native Health

Run the same application check used by the chart smoke test:

```bash
kubectl -n temporal exec deployment/temporal-temporal-admin-tools -- \
  temporal operator cluster health --address temporal-temporal-frontend:7233
```

Check the UI independently:

```bash
kubectl -n temporal port-forward service/temporal-temporal-web 8080:8080
curl --fail http://127.0.0.1:8080/healthz
```

## Namespace Administration

Temporal namespaces are application-level tenancy boundaries and differ from
Kubernetes namespaces. Create them deliberately with retention and ownership
policies appropriate to the workload. The admin-tools pod contains the official
Temporal CLI but should be disabled when interactive administration is not
permitted.

## Capacity and Scaling

Scale roles from observed service and persistence metrics. Frontend capacity
tracks client requests, matching tracks task queue operations, history tracks
workflow state and timers, and worker tracks system workflows. Increasing every
role together wastes resources and can overload persistence.

Before scaling history, confirm database headroom and membership stability.
Never change history shard count against an initialized database.

## Metrics

Enable ServiceMonitor resources only when Prometheus Operator CRDs exist. At a
minimum, alert on server request failures, persistence failures, high request
latency, unavailable hosts, task queue latency, and database saturation. Scrape
each component separately so labels retain the server role.

## Backup and Restore

A Temporal backup is primarily the persistence layer plus configuration and
credentials. Back up both databases consistently, preserve the credential
Secret, and record the server version and history shard count. Test restoration
into an isolated cluster and require native cluster health before declaring the
backup usable.

For mission-critical global availability, evaluate Temporal multi-cluster
replication. PostgreSQL read replicas alone do not provide Temporal failover.

## Upgrade Runbook

1. Review each Temporal minor release in sequence.
2. Confirm database version compatibility.
3. Capture and verify a restorable backup.
4. Update schema with the official admin-tools version.
5. Roll server roles and Web UI.
6. Confirm effective image tags and digests.
7. Run cluster health and a representative workflow.
8. Review logs, restarts, events, latency, and persistence errors.

With Helm 3.14 or later, use `helm upgrade --reset-then-reuse-values`; with an
older client, pass image tags explicitly. Either approach prevents a previous
image value from silently surviving the upgrade.

## Common Failures

### Schema Job retries forever

Confirm database DNS, password key, database names, and ownership. External
databases must exist before the hook or normal Job runs.

### Server pods remain in init

Inspect the schema Job, then query the `schema_version` table in both databases
with a PostgreSQL client. Do not remove the init gate to make pods appear Ready.

### Frontend Ready but SDK request fails

Run cluster health inside the namespace, inspect EndpointSlices, then debug the
Gateway listener and GRPCRoute. A TCP readiness probe is not gRPC acceptance.

### Web UI Ready but displays connection errors

Inspect `TEMPORAL_ADDRESS`, frontend DNS, frontend logs, and authorization/TLS
settings. UI health only proves its HTTP process is alive.

### Pods restart under load

Review per-role memory limits, database pool sizes, persistence latency, and
task queue metrics. Tune one role at a time and preserve capacity for upgrades.

### Voluntary disruption is blocked

Check PDBs against replica counts. A one-replica component with minAvailable one
correctly blocks eviction; add replicas before enabling its PDB.
