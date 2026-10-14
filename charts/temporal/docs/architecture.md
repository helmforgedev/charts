# Temporal Architecture

## Control Plane Roles

Temporal Server is four cooperating services. The chart deliberately avoids a
single all-in-one workload because production load does not scale uniformly.

- Frontend accepts SDK gRPC requests, performs validation and routing, and is
  the only server Service exposed to users.
- History owns mutable workflow state, event histories, timers, and transfer
  tasks. Its persistence and latency profile usually dominates capacity.
- Matching owns task queues and dispatches work to application Workers.
- Worker runs Temporal's internal workflows and replication activities. It is
  not an application Worker and is never exposed publicly.

Each role has an immutable selector, independent replica count and resources,
and a headless Service for membership and metrics. Shared placement values can
spread all roles across nodes or zones.

## Persistence and Schemas

The `default` store contains workflow state. The `visibility` store supports
listing and searching workflows. They use separate PostgreSQL databases and
the official Temporal schema trees embedded in `temporalio/admin-tools`.

The schema Job performs `setup-schema` and `update-schema` for both stores.
Server init containers query the schema version tables with the official
PostgreSQL client and do not start the server binary until both stores report
the expected versions. This prevents an open TCP port from being mistaken for
an initialized Temporal database.

History uses an ordered StatefulSet so the first replica establishes cluster
metadata before additional replicas join. Frontend, matching, and worker use
Deployments and wait for their upstream Temporal role before starting.

Bundled mode creates both databases through the HelmForge PostgreSQL initdb
contract. External mode assumes both databases exist and that the configured
role can manage Temporal tables. The password is never rendered into a
ConfigMap; the server's config template reads it from process environment.

## History Shards

History shards divide workflow ownership across history hosts. The count is
stored in persistent cluster metadata and is immutable after initialization.
This chart fixes it at 512. Capacity planning must happen before production
bootstrap; changing a value file later is not a supported scaling mechanism.

## Services and Ports

| Service | Port | Use |
| --- | ---: | --- |
| frontend ClusterIP | 7233 | SDK gRPC and GRPCRoute backend |
| frontend ClusterIP | 7243 | Temporal HTTP API |
| Web UI ClusterIP | 8080 | Browser UI and HTTPRoute backend |
| role headless | role-specific | membership and internal traffic |
| role headless | 9090 | Prometheus metrics |

Membership ports are 6933 through 6939. They are internal and must not be routed
through Ingress or Gateway API.

## Health Model

TCP probes remain compatible with both plaintext and future TLS-enabled server
listeners, but TCP success alone is insufficient. The runtime smoke therefore
executes `temporal operator cluster health` from the matching admin-tools image.
The UI uses its native `/healthz` endpoint. Validation also checks Services,
EndpointSlices, restarts, logs, and Kubernetes events.

## Failure Domains

Replicas should be distributed with topology spread constraints or pod
anti-affinity. PDBs are opt-in because `minAvailable: 1` on a single replica
would block voluntary disruption without adding availability. PostgreSQL has
its own architecture, placement, PDB, backup, and replication controls.

## Upgrade Sequence

1. Back up both databases and the credential Secret.
2. Review every skipped Temporal release and schema change.
3. Apply schema updates with the old server still available where supported.
4. Roll server roles and confirm effective images.
5. Run native cluster health and UI health checks.
6. Inspect role logs, restarts, metrics, and persistence error rates.

Temporal recommends sequential minor upgrades. Patch releases may be applied
directly after reviewing their notes.
