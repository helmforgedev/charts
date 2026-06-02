# changedetection.io Chart Design

This chart packages changedetection.io as a practical single-instance
Kubernetes workload with persistent SQLite storage and optional browser
rendering.

## Architecture

```text
User or automation
  |
  +-- Ingress or Gateway API HTTPRoute
        |
        +-- Service
              |
              +-- Deployment
                    |-- changedetection.io container
                    |-- optional browserless Chromium sidecar
                    +-- PVC mounted at /datastore
```

## Design Choices

- The workload is a `Deployment` with one replica and `Recreate` strategy
  because changedetection.io stores runtime state in SQLite under
  `/datastore`.
- Persistence is enabled by default so watches, history, and snapshots survive
  upgrades and pod rescheduling.
- The optional browser sidecar is colocated in the pod so JavaScript rendering
  is available through localhost without exposing an additional Service.
- Gateway API and Ingress are mutually independent disabled-by-default routing
  options. The chart uses only `gateway`, matching HelmForge naming standards.
- External Secrets support is generic and disabled by default. It is intended
  for environment secrets or notification integration credentials consumed via
  `changedetection.envFrom` or `changedetection.extraEnv`.
- The upstream `EXTRA_PACKAGES` hook is supported without running the container
  as root by using a Python user install path under `/datastore`.
- Service dual-stack fields are optional and rendered only when explicitly set.

## Security Model

The default pod drops Linux capabilities, disables privilege escalation, uses a
runtime default seccomp profile, and runs the main container as UID/GID 1000.
The root filesystem remains writable because changedetection.io writes runtime
state and temporary files.

## Non-Goals

- Horizontal scaling is not supported while upstream uses SQLite for runtime
  state.
- The chart does not manage notification provider credentials directly. Use
  Kubernetes Secrets or External Secrets Operator.
- Browser rendering is optional because it increases CPU and memory usage.

## Validation Focus

- Default install with persistent datastore
- JavaScript rendering sidecar
- Ingress and Gateway API routing
- ExternalSecret rendering for environment-backed configuration
- Dual-stack Service rendering

## Related Files

- `charts/changedetection/README.md`
- `charts/changedetection/docs/production.md`
- `charts/changedetection/examples/production.yaml`

---

keywords: changedetection, monitoring, website-monitoring, design
path: charts/changedetection/DESIGN.md
