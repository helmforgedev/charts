# Temporal Helm Chart

Production-oriented [Temporal](https://temporal.io/) for Kubernetes with
separate server roles, managed PostgreSQL schemas, External Secrets support,
observability, and native Gateway API routes for both HTTP and gRPC.

## Highlights

- Temporal Server 1.32.1 and UI 2.56.0 official images.
- Frontend, history, matching, and worker scale independently.
- Bundled HelmForge PostgreSQL or an external PostgreSQL service.
- Official schema tooling gates server startup on initialized schemas.
- HTTPRoute targets only the Web UI; GRPCRoute targets only the gRPC frontend.
- Ingress, dual-stack Services, PDBs, NetworkPolicy, ServiceMonitor, and ESO.
- Native `temporal operator cluster health` runtime validation.

## Install

```bash
helm upgrade --install temporal oci://ghcr.io/helmforgedev/helm/temporal \
  --namespace temporal \
  --create-namespace
```

Wait for the schema Job and all server roles:

```bash
kubectl -n temporal get pods,jobs
helm test temporal -n temporal --logs
```

## Architecture

| Component | Purpose | Public port |
| --- | --- | ---: |
| frontend | SDK/API gateway and routing | gRPC 7233 |
| history | Workflow state and timers | internal |
| matching | Task queues | internal |
| worker | System workflows | internal |
| Web UI | Browser interface | HTTP 8080 |
| PostgreSQL | Default and visibility stores | internal |

See [docs/architecture.md](docs/architecture.md) for membership, persistence,
schema, and scaling details.

## Configuration

Listener ports and Kubernetes Service ports are intentionally independent:

| Purpose | Process listener | Service port |
| --- | --- | --- |
| Web UI HTTP | `containerPorts.web` (default `8080`) | `webService.port` (default `8080`) |
| Server metrics | `containerPorts.metrics` (default `9090`) | `monitoring.servicePort` (default `9090`) |
| Frontend gRPC | `server.components.frontend.rpcPort` | `frontendService.port` |
| Frontend HTTP | `server.components.frontend.httpPort` | `frontendService.httpPort` |

Changing `containerPorts.web` sets the official UI image's
`TEMPORAL_UI_PORT`. Changing `containerPorts.metrics` updates Temporal Server's
Prometheus `listenAddress`. Services continue to target named container ports,
so their externally visible ports may be changed independently.

```yaml
containerPorts:
  web: 18080
  metrics: 19090
webService:
  port: 8080
monitoring:
  servicePort: 9090
```

See [values.yaml](values.yaml) for the complete contract and
[docs/operations.md](docs/operations.md) for operational procedures.

## Gateway API

The chart does not create a Gateway. Reference listeners already owned by the
platform team:

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - name: ui
      parentRefs:
        - name: platform-gateway
          namespace: gateway-system
          sectionName: https
      hostnames:
        - temporal.example.com
  grpcRoutes:
    - name: frontend
      parentRefs:
        - name: platform-gateway
          namespace: gateway-system
          sectionName: temporal-grpc
      hostnames:
        - api.temporal.example.com
```

The frontend Service advertises `kubernetes.io/h2c`. Terminate TLS on the
Gateway or add controller-compatible backend TLS policy. GRPCRoute termination
does not preserve individual SDK client certificate identity; use TLSRoute
passthrough through separately managed manifests when strict end-to-end mTLS is
required. See [docs/gateway-api.md](docs/gateway-api.md).

## PostgreSQL

The default mode installs the HelmForge PostgreSQL dependency and creates both
Temporal databases. For an external service:

```yaml
database:
  mode: external
  host: temporal-postgresql.database.svc
credentials:
  existingSecret: temporal-external-database
postgresql:
  enabled: false
```

The Secret must contain `user-password`. Both databases must exist and the
configured user must own, or have sufficient privileges to manage, Temporal's
schemas. `schema.useHelmHooks=true` is supported only for external databases.

PostgreSQL 18.6 in the bundled dependency is beyond Temporal's published active
test matrix, which currently documents PostgreSQL through 16.6. HelmForge
validates schema bootstrap and native runtime behavior; use an upstream-tested
external version when formal vendor compatibility is required.

## Immutable History Shards

`server.numHistoryShards` is 512 and cannot be changed after initialization.
Changing it against an existing database can corrupt cluster routing. The chart
schema and template validation therefore hold the value constant.

## External Secrets

Set `credentials.existingSecret` to the target Secret and use the canonical
`externalSecrets.items[]` contract. The ESO controller, SecretStore, and remote
values remain platform responsibilities. See `examples/external-secrets.yaml`.

## High Availability

Set replicas per server role from measured traffic. History and matching often
need different scaling from frontend. Use topology spread constraints or
anti-affinity, enable PDBs only after replicas exceed one, and operate the
database with independent backup and restore procedures.

The included production example is a starting point, not a capacity promise:

```bash
helm upgrade --install temporal ./charts/temporal \
  --namespace temporal \
  --create-namespace \
  -f charts/temporal/examples/production-ha.yaml
```

## Observability

Every server role exposes Prometheus metrics on `containerPorts.metrics`
through the `monitoring.servicePort` port of its headless Service. Enable
`monitoring.serviceMonitor.enabled` when Prometheus Operator CRDs are installed.
Alert on service and persistence errors, request latency, queue backlogs, and
database saturation.

## Network Policy

The optional policy allows same-namespace control-plane traffic. With egress
enabled it also allows DNS and accepts complete `extraTo` and `extraEgress`
rules. Add explicit controller, scraper, and external database peers for your
cluster topology before enforcing restrictive policies.

## Security

- Keep Gateway API and Ingress disabled until TLS and authorization are ready.
- Prefer existing Secrets or ESO in production.
- Restrict frontend gRPC to trusted networks and authenticated clients.
- Disable admin tools if interactive cluster administration is not required.
- Back up PostgreSQL and test restoration with the credential Secret.
- Review route status and controller conformance before production traffic.

## Upgrades

Upgrade schemas before server binaries and cross Temporal minor releases one at
a time. Keep server and admin-tools versions aligned. After every rollout,
confirm the actual images, schema Job, restarts, events, server logs, native
cluster health, and Web UI health.

## Security Scan

Security scan results use the same Kubescape policy set as HelmForge CI.

Security Scan: temporal

| Framework | Score |
| --- | ---: |
| MITRE | **100.00%** |
| NSA | **86.25%** |
| SOC 2 | **85.45%** |
| Aggregate resource score | **89.46%** |

Kubescape reported no critical failures. Remaining findings are primarily CPU
limits, opt-in NetworkPolicy defaults, and writable filesystems required by the
official PostgreSQL and operational images. The application server and Web UI
run non-root with dropped capabilities and read-only root filesystems.

## Validation

`make validate-chart CHART=temporal` covers dependencies, strict lint, every CI
values file, unit tests, real CRD schemas, Artifact Hub lint, and behavioral
k3d validation. The chart-owned smoke test verifies Temporal gRPC cluster health
and Web UI `/healthz`, complementing Kubernetes readiness probes.

## Documentation

- [Architecture](docs/architecture.md)
- [Gateway API](docs/gateway-api.md)
- [Operations](docs/operations.md)
- [Temporal self-hosted deployment](https://docs.temporal.io/self-hosted-guide/deployment)

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md).

<!-- @AI-METADATA
type: chart-readme
title: Temporal Chart
description: Production-ready Temporal chart with native Gateway API routes
keywords: temporal, workflows, gateway-api, grpcroute, postgresql
purpose: Chart usage documentation
scope: Chart
relations:
  - charts/temporal/Chart.yaml
  - charts/temporal/values.yaml
path: charts/temporal/README.md
version: 1.0
date: 2026-10-13
-->
