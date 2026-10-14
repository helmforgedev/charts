# Temporal Chart Implementation Plan

Issue: [#1478](https://github.com/helmforgedev/charts/issues/1478)

Target chart release: 1.0.0

Application baseline: Temporal Server 1.32.1, UI 2.56.0

Complexity: high

## Objective

Deliver a production-oriented self-hosted Temporal chart whose primary
differentiator is first-class Gateway API exposure. The chart must remain
operable without Gateway API, provide a complete PostgreSQL bootstrap path, and
prove application health with Temporal's own CLI.

## Priority 1: Functional Control Plane

- Four independently configurable server workloads, with ordered history
  bootstrap and independently scalable Deployments for the other roles.
- Official server, admin-tools, and UI images pinned to stable tags.
- Default and visibility stores on bundled HelmForge PostgreSQL.
- Official SQL schema creation and update Job.
- Schema-version init gate before every server role.
- Frontend, headless membership/metrics, and Web UI Services.
- Native cluster-health and Web UI smoke verification.

Acceptance: default installation reaches Ready, the Temporal CLI reports the
cluster as serving, UI `/healthz` returns HTTP 200, logs/events are reviewed,
and the namespace is cleaned after validation.

## Priority 2: Requested Exposure and Production Controls

- Canonical multi-route HTTPRoute contract for the Web UI.
- Equivalent multi-route GRPCRoute contract for the frontend gRPC API.
- h2c backend protocol declaration.
- Conventional Web UI Ingress for compatibility.
- Per-role PDBs, placement, resources, NetworkPolicy, and ServiceMonitor.
- External Secrets Operator items contract.
- Dual-stack Service fields.

Acceptance: every CI values file lints, renders, conforms to schemas, and has
unit coverage. Gateway resources validate against the real installed CRDs.

## Priority 3: Operational Delivery

- Product-specific README, design, architecture, Gateway, and operations docs.
- Copy-ready simple, HA, external DB, Gateway, and ESO examples.
- Complete site documentation, catalog metadata, playground, and official icon.
- Linked chart and site PRs with green CI and no unresolved review threads.
- Published chart release and installation path verified after merge.

## Validation Matrix

| Scenario | Static | k3d behavior |
| --- | --- | --- |
| default bundled PostgreSQL | full | schemas, server workloads, gRPC health, UI health |
| Gateway API | full | routes rendered against real CRDs |
| production HA | full | replica/PDB/placement contracts |
| external database | full | secret and host contract |
| External Secrets | full | ESO schema and fake-store reconciliation |
| monitoring | full | one ServiceMonitor per server role |
| NetworkPolicy | full | same-namespace control plane and extension points |
| dual stack | full | Service family contract |

## Release Plan

1. Commit as `feat(temporal)!: add chart` so the new chart declares version-one
   release intent while retaining the `0.1.0` scaffold baseline.
2. Open one normal chart PR resolving #1478 and one neutral companion site PR.
3. Wait for all CI and review threads in both repositories.
4. Merge the site companion, then the chart PR.
5. Verify the generated chart tag, repository index, OCI artifact, and site.
6. Only after publication, respond to the requester with the delivered
   features, validation evidence, PRs, documentation, and installation links.
