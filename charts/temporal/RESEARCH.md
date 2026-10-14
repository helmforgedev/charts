# Temporal Chart Research

Chart request: [#1478](https://github.com/helmforgedev/charts/issues/1478)

Requester: `@RozmarinUS`

Upstream: <https://github.com/temporalio/temporal>

Research date: 2026-10-13

## Recommendation

Ship a beta HelmForge chart for Temporal Server 1.32.1 and Temporal UI 2.56.0.
The product is a durable workflow control plane, not a conventional web app.
Its four server roles must remain independently scalable, its SQL schemas must
be managed before server startup, and the history shard count must be treated
as immutable after initialization.

The request is valid: the official chart 1.7.0 exposes the Web UI and gRPC
frontend only through Ingress resources. Its templates contain no HTTPRoute or
GRPCRoute. A portable Gateway API contract is a material improvement because
it removes controller-specific gRPC annotations.

## Primary Sources

- <https://github.com/temporalio/temporal/releases/tag/v1.32.1>
- <https://github.com/temporalio/ui/releases/tag/v2.56.0>
- <https://github.com/temporalio/helm-charts/releases/tag/temporal-1.7.0>
- <https://docs.temporal.io/self-hosted-guide/deployment>
- <https://docs.temporal.io/self-hosted-guide/production-checklist>
- <https://docs.temporal.io/encyclopedia/temporal-service/persistence>
- <https://gateway-api.sigs.k8s.io/api-types/grpcroute/>
- <https://gateway-api.sigs.k8s.io/guides/http-routing/>

## Image Evidence

The official registry manifests were verified with `make image-verify`:

| Image | Platforms |
| --- | --- |
| `temporalio/server:1.32.1` | `linux/amd64`, `linux/arm64` |
| `temporalio/admin-tools:1.32.1` | `linux/amd64`, `linux/arm64` |
| `temporalio/ui:2.56.0` | `linux/amd64`, `linux/arm64` |

The official chart still pins Server/Admin Tools 1.32.0 and UI 2.54.1. This
chart uses newer stable patch releases and therefore requires native runtime
validation rather than assuming the upstream chart combination is sufficient.

## Runtime Architecture

| Component | Responsibility | Client port | Membership | Metrics |
| --- | --- | ---: | ---: | ---: |
| frontend | Client API, routing, rate limiting | gRPC 7233, HTTP 7243 | 6933 | 9090 |
| history | Workflow history, timers, mutable state | 7234 | 6934 | 9090 |
| matching | Task queues and dispatch | 7235 | 6935 | 9090 |
| worker | Internal system workflows and replication | internal | 6939 | 9090 |
| Web UI | Browser UI | HTTP 8080 | none | none |

Only the Web UI and frontend are public exposure candidates. History, matching,
worker, membership, metrics, schema tooling, and admin tools remain internal.

## Persistence

Temporal supports PostgreSQL, MySQL, and Cassandra for its default store and
SQL or Elasticsearch-compatible visibility stores. This initial chart selects
PostgreSQL for both stores so that one HelmForge dependency covers a functional
installation while an external database mode remains available.

The bundled PostgreSQL chart currently uses PostgreSQL 18.6. Temporal's
published active test matrix mentions PostgreSQL through 16.6. That gap is not
treated as proof of incompatibility: it is an explicit risk requiring schema
bootstrap, real server startup, cluster health, Web UI health, and upgrade-path
validation. Production operators should use an upstream-tested managed version
when organizational support policy requires it.

The default and visibility databases use separate schemas. The chart runs the
official `temporal-sql-tool` from the matching admin-tools image. Server pods
wait until the schema version is readable instead of accepting a mere TCP
connection as readiness evidence.

## Existing Chart Analysis

### Official Temporal chart

Strengths:

- Separate Deployments, resources, placement, probes, PDBs, and metrics for
  each server role.
- Mature schema management and TLS configuration.
- Official images and first-party maintenance.

Limitations relevant to this request:

- No Gateway API resources or values contract.
- gRPC exposure depends on Ingress controller annotations.
- Database provisioning is external-only.
- The values surface is very large and exposes many low-level implementation
  details before operators reach a usable secure baseline.

## HelmForge Differentiation

| Capability | Official chart | HelmForge |
| --- | --- | --- |
| Gateway API | None | Native HTTPRoute and GRPCRoute |
| gRPC backend protocol | Controller annotations | `kubernetes.io/h2c` Service contract |
| PostgreSQL | External only | HelmForge subchart or external mode |
| Secrets | Kubernetes Secret references | Persisted generated Secret, existing Secret, ESO |
| Schema readiness | Hook-oriented | Job plus schema-aware server init gate |
| Runtime acceptance | Upstream CI | k3d cluster health and UI health smoke |
| Exposure safety | Ingress values | Routes hard-wired to safe product backends |

The three highest-impact differentiators are:

1. Native split HTTPRoute/GRPCRoute exposure without controller annotations.
2. Complete bundled-to-external PostgreSQL lifecycle with official schema tools.
3. Product-level acceptance that checks gRPC cluster health, not only TCP ports.

## Gateway API Design

`gatewayAPI.httpRoutes[]` generates v1 HTTPRoute resources whose default backend
is always the Web UI Service on port 8080. `gatewayAPI.grpcRoutes[]` generates
v1 GRPCRoute resources whose default backend is always the frontend Service on
port 7233. The chart never creates a shared Gateway and never defaults routes
to internal Temporal roles.

The frontend Service advertises `kubernetes.io/h2c`. For backend TLS, operators
must add controller-compatible BackendTLSPolicy resources. GRPCRoute terminates
the client connection at the Gateway; strict end-to-end client-certificate
identity requires TLSRoute passthrough and remains outside this first release.

## Production Requirements

- Scale frontend, history, matching, and worker from observed load separately.
- Set `numHistoryShards` once, before the first schema initialization.
- Place replicas across nodes or zones and use intentional PDBs.
- Restrict frontend access and terminate TLS before exposing it publicly.
- Protect PostgreSQL with backups, high availability, and restore drills.
- Monitor request errors/latency and persistence errors/latency for every role.
- Upgrade schemas before server binaries and upgrade one Temporal minor at a
  time when crossing minor releases.

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| PostgreSQL 18 is beyond the published test matrix | Behavioral k3d validation and explicit external DB guidance |
| TCP probes can hide unhealthy services | Native CLI cluster health and UI `/healthz` smoke |
| Route/controller feature variance | v1 resources, h2c appProtocol, status verification docs |
| gRPC termination changes mTLS identity | Document GRPCRoute versus TLSRoute security boundary |
| Schema races with bundled database startup | Retrying schema Job and schema-version init gate |
| Accidental shard-count changes | Schema const plus template validation and upgrade docs |
