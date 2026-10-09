# NautilusTrader chart design

## Workload model

A live trading node is a singleton Deployment with `Recreate` updates. Parallel strategies belong in separate Helm
releases so each has an independent lifecycle and failure boundary. Backtests use Jobs and scheduled backtests use a
CronJob. The chart intentionally provides no HPA or replica setting.

## Safe default and user code

The official image contains the Python package but no universal application entrypoint. A small chart-managed runner
adds Kubernetes lifecycle, health, and signal handling without inventing a strategy. `validate` is the non-trading
default. `live` loads a user-owned factory and calls its `run`, `stop`, and `dispose` methods when present.

## Image policy

Upstream has no versioned release image tags. The default is the official multi-architecture image by immutable digest,
resolved from `latest` and tied to its source revision in chart documentation. This avoids a floating deployment while
preserving the normal image values contract for operators.

## Security and state

The pod runs as UID/GID 10001 with RuntimeDefault seccomp, no privilege escalation, dropped capabilities, a read-only
root filesystem, and no service-account token. Writable temporary state uses `emptyDir`; catalog, event-store, and
result paths can use existing or generated PVCs. Credentials enter only through Secret references or ExternalSecret.

## Integrations and exposure

PostgreSQL and Redis are optional dependencies and can be replaced with external services. Their connection variables
are an interface to user factories, not an assertion that upstream enables an adapter. The Service exposes only the
runner health and metrics endpoint inside the cluster. NautilusTrader is not an HTTP application, so Ingress and
Gateway API resources would be misleading and are intentionally absent.
