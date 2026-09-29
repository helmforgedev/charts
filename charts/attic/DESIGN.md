# Attic chart design

## Goals

Provide a safe default for a persistent single-node Nix cache and a deliberate
path to the upstream-recommended PostgreSQL/S3 architecture. Encode the
constraints that are otherwise left to deployment-specific manifests.

## Topology decision

The chart uses a Deployment in both modes. Standalone selects Recreate, one
replica, SQLite and a single PVC. This retains the operational simplicity of a
single process while making volume ownership and rollout behavior explicit.

Distributed mode selects RollingUpdate and `api-server`, creates one separate
garbage-collector Deployment and runs migrations as a Helm pre-install and
pre-upgrade Job. The existing Secret is a precondition because the hook runs
before ordinary release resources. This avoids generating or rotating
production credentials inside the release lifecycle.

## Database and object storage

Only two combinations are supported:

- SQLite plus local PVC in standalone mode.
- PostgreSQL plus S3-compatible storage in distributed mode.

Supporting every cross-product would imply safety the upstream architecture
does not provide. In particular, a shared filesystem does not make SQLite a
multi-writer database, and local objects do not make stateless API replicas
portable without a separately managed coherent RWX layer.

PostgreSQL and S3 are external rather than subchart dependencies. Operators can
use HelmForge PostgreSQL, a Kubernetes operator or managed services. Keeping
their lifecycles independent is important because Attic backup and restore must
coordinate metadata and objects across both systems.

## Configuration and secrets

Non-secret TOML is rendered into a ConfigMap and checked before process start.
Secret values use upstream environment overrides. Standalone mode may generate
a stable HS256 key using Helm lookup; distributed mode requires stable external
credentials and supports the canonical External Secrets adapter.

## Health and observability

The pinned upstream build has no dedicated health or metrics endpoint. TCP
probes are therefore honest process checks. The chart does not render a
ServiceMonitor. Dependency readiness is verified operationally with cache
create/push/pull behavior and external PostgreSQL/S3 monitoring.

## Security

Kubernetes overrides the official image's root default with UID/GID 10001,
RuntimeDefault seccomp, no capabilities and a read-only root filesystem. The
PVC and `/tmp` are the only writable mounts. The pod receives no Kubernetes API
token.

## Exposure

Ingress and Gateway API are first-class because Attic is an HTTP application.
The values contract keeps canonical URL and accepted hosts explicit and leaves
controller-specific large-upload limits to annotations or policy resources.

## Maturity

The chart is beta because upstream publishes no semantic releases, describes
the project as an early prototype and reserves the right to make incompatible
database changes. HelmForge can provide a production-oriented deployment
contract, but cannot manufacture an upstream stability guarantee.

## Rejected alternatives

- A generic app-template dependency: obscures Attic lifecycle and validation.
- Floating `latest` or `main` image tags: violates reproducibility.
- Bundled Bitnami PostgreSQL: violates HelmForge image/dependency policy.
- Prometheus ServiceMonitor without a metrics endpoint: produces false
  observability claims.
- Multiple monolithic replicas: races SQLite/local storage and duplicates GC.
- Automatic production signing-key rotation: invalidates existing tokens.
