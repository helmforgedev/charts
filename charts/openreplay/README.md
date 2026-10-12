# OpenReplay Helm Chart

Production-oriented OpenReplay 1.28 deployment with pinned official images,
portable Ingress and Gateway API exposure, External Secrets support, and no
bundled ingress controller.

## What this chart deploys

OpenReplay is not a single container. The chart models its fifteen OSS
application services, migration workflow, RWX recording scratch space,
PostgreSQL, Redis/Valkey, ClickHouse, S3-compatible storage, and a dedicated
Caddy router. Enterprise-only connector, Kafka, and Vault workloads are not
included.

The OpenReplay application images are linux/amd64 only. Kubernetes 1.31+ and an
amd64 node pool are required. Upstream's minimum for low/moderate traffic is 2
vCPU, 8 GiB memory, and 50 GiB storage; production capacity needs load testing.

## Installation

```bash
helm install openreplay oci://ghcr.io/helmforgedev/helm/openreplay \
  --namespace openreplay --create-namespace \
  --set openreplay.domain=replay.example.com
```

For the HTTPS repository:

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install openreplay helmforge/openreplay \
  --namespace openreplay --create-namespace \
  --set openreplay.domain=replay.example.com
```

HTTPS is required for tracker recording and replay in real environments. The
chart does not install an Ingress controller, Gateway, GatewayClass, certificate
controller, Prometheus stack, CSI driver, or External Secrets Operator.

## Exposure

Enable either `ingress` or `gatewayAPI`, never both. Both point to the internal
router, which owns OpenReplay-specific path rewrites and WebSocket behavior.

```yaml
openreplay:
  domain: replay.example.com
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: replay.example.com
  tls:
    - secretName: openreplay-tls
      hosts:
        - replay.example.com
```

Gateway API attaches to an existing listener:

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - name: web
      parentRefs:
        - name: platform-gateway
          namespace: gateway-system
          sectionName: https
      hostnames:
        - replay.example.com
```

## Credentials

On first install, the chart creates `openreplay-credentials` and preserves its
generated values on Helm upgrades. Production operators should supply an
existing Secret or ExternalSecret target containing these keys:

- `postgres-password`
- `redis-password`
- `clickhouse-password`
- `access-key` and `secret-key`
- `assist-key` and `assist-jwt-secret`
- `jwt-secret`, `jwt-spot-secret`, and `token-secret`
- `jwt-refresh-secret`, `jwt-spot-refresh-secret`, and `jwt-mcp-secret`

The three HelmForge dependency subcharts consume the same Secret by default.

## Storage and data services

The default dependencies are HelmForge PostgreSQL, Redis, and ClickHouse plus a
pinned RustFS Deployment. Disable each bundled service independently and set the
corresponding endpoint under `database` or `objectStorage`.

All pipeline workers mount the scratch claim at `/mnt/efs`. The default
ReadWriteOnce mode is a single-node baseline; use ReadWriteMany for multi-node
scheduling. `scratch.ephemeral=true` is intended only for the
isolated validation profile and loses in-flight recordings when pods restart.

## Migrations and upgrades

The revision-scoped migration Job fetches exactly the `v1.28.0` schema from the
official repository and runs the upstream PostgreSQL, ClickHouse, and object
storage migration scripts with pinned clients. A version ConfigMap blocks
downgrades by default.

Back up all durable stores and credentials before upgrade. Helm `--atomic`
cannot reverse database or object-store changes. Backend 1.28 requires tracker
19.x and Assist 11.x.

## Observability

Set `monitoring.serviceMonitor.enabled=true` when Prometheus Operator CRDs are
already installed. ServiceMonitors target the upstream metrics ports. Monitor
ingestion failure rate, worker restarts, storage capacity, queue delay, and
database errors. The chart does not bundle Prometheus.

## Network policy

`networkPolicy.enabled=true` restricts selected application pods. Egress rules
include data-plane ports and HTTPS; production environments should add precise
namespace, pod, or IP peers through `extraTo` and `extraEgress`.

## Backup and restore

One volume snapshot is not a complete OpenReplay backup. Protect PostgreSQL,
ClickHouse, S3 buckets, the credentials Secret, and relevant scratch/Valkey
state. Quiesce ingestion or coordinate store snapshots. Restore data services
first, verify them, then let migrations and application pods start.

## Security scan

Security scan results use the same Kubescape policy set as HelmForge CI.

Security Scan: openreplay

| Framework                |      Score |
| ------------------------ | ---------: |
| MITRE                    | **100.00%** |
| NSA                      |  **80.72%** |
| SOC 2                    |  **84.83%** |
| Aggregate resource score |  **86.02%** |

Kubescape reported no critical failures. The remaining findings reflect
upstream-required writable root filesystems, opt-in NetworkPolicy defaults,
and incomplete CPU-limit coverage across the multi-service topology. Official
OpenReplay images are digest-pinned but currently have no verifiable Cosign
signatures or published SBOM. See [docs/security.md](docs/security.md) for the
vulnerability snapshot and hardening rationale.

## Validation profile

The default chart topology is installed and exercised on k3d, including all
fifteen application components, bundled data services, object storage, schema
migration, router health, and frontend delivery. Reduced CI profiles separately
cover Ingress, Gateway API, dual-stack Services, and External Secrets.

## Additional documentation

- [Architecture](docs/architecture.md)
- [Operations](docs/operations.md)
- [Security](docs/security.md)
- [Upstream Kubernetes guide](https://docs.openreplay.com/en/deployment/deploy-kubernetes/)
- [Upstream upgrade guide](https://docs.openreplay.com/en/deployment/upgrade/)

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md).

<!-- @AI-METADATA
type: chart-readme
title: OpenReplay Chart
description: Production-ready OpenReplay chart
keywords: openreplay, session-replay, observability, gateway-api
purpose: Chart usage documentation
scope: Chart
relations:
  - charts/openreplay/Chart.yaml
  - charts/openreplay/values.yaml
path: charts/openreplay/README.md
version: 1.0
date: 2026-10-12
-->
