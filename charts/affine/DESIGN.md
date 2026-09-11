# AFFiNE design

## Workload and state

The official AFFiNE image runs as UID/GID 1000 with a read-only root filesystem,
dropped capabilities and no Kubernetes API token. A single Recreate Deployment
owns its configuration and filesystem storage PVC. Separate bounded emptyDir
mounts cover temporary files and the upstream-generated GraphQL schema. The image
unconditionally writes `/app/src/schema.gql` even in production; application code
remains read-only in `/app/dist`.

PostgreSQL contains users, permissions, documents, sessions and blob metadata.
The PVC contains configuration, the original SEC1 private key and filesystem
objects. Redis supports cache, session, Socket.IO and BullMQ clients on separate
logical databases. Increasing replicas without validating storage and worker
coordination would not establish HA, so the chart requires one application replica.

## Private initialization

An init container checks dependency authentication, the vector extension and
migration history before invoking native schema and data migration commands in
sequence. Unresolved migrations fail admission; the chart never silently marks
them rolled back. An existing user database requires its original private key.
An empty-user database containing preexisting application overrides requires
explicit operator review.

Fresh databases use the native first-administrator HTTP API while the server binds
only to IPv4 loopback. The initializer verifies the listening socket and rejects
Pod-IP reachability before sending the password. The native endpoint validates the
password and assigns the administrator feature. Only after the private process
terminates does the chart write the public bind configuration and start the main
container. Existing identities skip private HTTP initialization entirely.

Generated initial passwords contain 32 random alphanumeric characters and survive
Helm upgrades through the retained Secret. Supplied passwords must contain 16 to
32 characters, within the upstream default limit. The bootstrap Secret is mounted
only in the init container. Changing it does not reset an existing user's password.

## PostgreSQL TLS has two driver contracts

The image contains Prisma and native Rust SQLx clients. Their PostgreSQL URL
parameters have different meanings:

| Consumer | Strict private-CA connection |
| --- | --- |
| Prisma schema migration and admission | `sslmode=require`, `sslaccept=strict`, `sslcert=/postgres-tls/ca.crt` |
| Application Prisma client | Same URL through `db.prisma.datasourceUrl` |
| Native BackendRuntime and StorageRuntime | `sslmode=verify-full`, `sslrootcert=/postgres-tls/ca.crt` through `DATABASE_URL` |

One URL cannot safely configure both. The chart constructs both from the same
encoded host/database/user/password fields, preserving database identity. The
native schema CLI receives the Prisma environment; the native data CLI and server
receive the SQLx environment plus the supported Prisma configuration override.
The chart preserves upstream migration order and SEC1 prime256v1 key format without
patching the image or rewriting application bundles.

The generated configuration contains a database credential and is therefore kept
on the private PVC with restrictive permissions. It must be handled as secret
material in backups. TLS disabled for bundled dependencies means namespace-local
plaintext transport; external TLS is enabled by default and validates the server.

## Redis and health

External Redis TLS uses native `redis.ioredis.tls`, with CA PEM contents and strict
hostname validation. Every native client inherits this configuration. Cache DB N,
session DB N+2, Socket.IO DB N+3 and queue DB N+4 must exist and authenticate.
Redis Cluster does not satisfy this logical-database contract.

Readiness performs a fresh PostgreSQL query, an authenticated Redis PING and an
HTTP request. Startup and liveness check the HTTP process. A dependency outage
therefore removes application readiness without turning dependency availability
into a liveness restart policy.

## Exposure and observability

Ingress and canonical Gateway API HTTPRoutes expose the application Service.
WebSocket upgrades must be supported by the selected controller. The chart does
not install an ingress controller, Gateway or certificate issuer.

Optional native Prometheus metrics use a separate private port and Service.
NetworkPolicy restricts scrapers to configured peers; the upstream listener has
no authentication. ServiceMonitor and PrometheusRule are optional real CRDs.
Enabling native metrics also enables upstream trace instrumentation and its Zipkin
exporter; the chart does not open unrestricted egress for that exporter.

## Validation boundaries

The behavioral scenarios exercise private administrator creation, closed signup,
native login, private workspace CRUD, exact multipart blob bytes, anonymous denial,
key retention and fresh login after Pod replacement. TLS, collaboration, metrics
and coordinated restore also have dedicated acceptance scenarios.

Collaboration fixtures use the shipped native `createDocWithMarkdown`,
`updateDocWithMarkdown` and `parseDocToMarkdown` functions. This verifies native
document structure and persisted text across real Socket.IO/Yjs broadcasts,
reconnects and edits after replacement. A generic custom Yjs map is insufficient:
it can round-trip while failing the application's indexing parser. This validation
does not establish browser editor or ingress-controller compatibility.
