# Temporal Chart Design

## Scope

The chart deploys one Temporal cluster with four server roles, one optional Web
UI, one optional admin-tools pod, SQL schema automation, and either bundled or
external PostgreSQL. It does not deploy application Workers, Elasticsearch,
cross-cluster replication, or a shared Gateway controller.

## Component Boundaries

Frontend is the only SDK-facing server role. History owns mutable workflow
state and timers. Matching owns task queues. Worker runs Temporal system
workflows. These are separate workloads and selectors because their scaling,
failure, and resource profiles differ. History is an ordered StatefulSet to
serialize cluster metadata bootstrap; the other roles are Deployments.

Every server role shares one generated config template but receives a distinct
`SERVICES` value. Headless Services provide stable membership and metrics
endpoints. The frontend also receives a ClusterIP Service for SDK traffic; the
Web UI receives a separate HTTP Service.

## Persistence Lifecycle

The bundled mode installs the HelmForge PostgreSQL subchart and creates the
`temporal` and `temporal_visibility` databases. A revision-scoped schema Job
uses the official admin-tools image to run `temporal-sql-tool`. Each server pod
uses the same tool in an init container and proceeds only after the default
schema version is readable.

External mode disables the dependency. Operators supply host, port, database
names, username, and a Secret. Both databases must already exist and the user
must be able to create and update Temporal tables. Helm hooks are permitted only
in this mode because pre-install hooks cannot reach a bundled database that has
not yet been created.

## Gateway API

HTTPRoute and GRPCRoute are deliberately separate values arrays and templates.
Their generated default backends cannot be redirected accidentally:

- HTTPRoute targets Web UI port 8080.
- GRPCRoute targets frontend gRPC port 7233.

Custom backendRefs remain available for advanced routing, but the chart never
exposes history, matching, worker, membership, metrics, or admin tools by
default. Parent references are mandatory and route names must be unique.

## Security

Workloads are non-root, drop Linux capabilities, disable service account token
mounts, and use read-only root filesystems where official images permit it.
Passwords come from a persisted generated Secret, an existing Secret, or ESO.
NetworkPolicy is opt-in because clusters differ in Gateway, monitoring, DNS,
and external database topology; it provides complete peer extension points.

Gateway TLS is owned by the referenced Gateway. This first release uses an h2c
backend. Backend TLS policies and TLSRoute passthrough can be supplied through
`extraManifests` when required by the controller and security model.

## Upgrade Invariants

- Never change history shards after the first schema initialization.
- Apply schema updates before starting a newer server image.
- Keep admin-tools and server versions aligned.
- Upgrade Temporal minor releases sequentially.
- Preserve the database credential Secret and PostgreSQL data.
- Confirm effective images and native cluster health after every rollout.
