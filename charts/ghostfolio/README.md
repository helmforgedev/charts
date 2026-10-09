# Ghostfolio Helm chart

Deploy [Ghostfolio](https://ghostfol.io), the open-source wealth-management
application, with an immutable official image, PostgreSQL, Redis, OIDC,
External Secrets, hardened networking, and upstream-native health checks.

## Install

```bash
helm install ghostfolio oci://ghcr.io/helmforgedev/helm/ghostfolio \
  --version 1.0.0 \
  --namespace ghostfolio \
  --create-namespace
```

The first registered account becomes the administrator. Keep the installation
private until that registration is complete.

## Runtime model

Ghostfolio's official entrypoint runs Prisma migrations, seeds the database,
and starts the NestJS server. Scheduled portfolio work also runs in the
application process. Because upstream does not document migration or cron
leader election, the chart enforces one replica and a `Recreate` rollout.

The default topology includes HelmForge PostgreSQL and Redis dependencies for a
complete installation. Use managed services for production by disabling both
dependencies and configuring the external Secret contracts described in
[docs/external-services.md](docs/external-services.md).

## Image provenance

The default is the official multi-platform image
`docker.io/ghostfolio/ghostfolio:3.82.0`, pinned to OCI index digest
`sha256:3b87436abfe7daae20a8bd5862bda230d327a5af49a837f888c007863ecb94fb`.
The manifest was verified for Linux amd64, arm/v7, and arm64 on 2026-10-09.

## Health contract

- Startup and liveness: `GET /api/v1/health/liveness`, independent of state
  services and safe during dependency outages.
- Readiness: `GET /api/v1/health`, checks PostgreSQL and Redis. Its timeout is
  at least five seconds because that is the upstream Redis health bound.

The chart waits for both TCP listeners before starting the upstream entrypoint,
but it does not replace authenticated migrations or readiness checks with TCP.

## Secrets

By default, the chart creates random `ACCESS_TOKEN_SALT` and `JWT_SECRET_KEY`
values and preserves them with Helm `lookup`. For deterministic GitOps or
disaster recovery, set `ghostfolio.existingSecret` and provide both configured
keys. Rotating either value invalidates authentication material.

OIDC client credentials, external database URLs, Redis passwords, and market
data API keys always belong in Secrets. The canonical `externalSecrets.items`
contract can materialize any of them through External Secrets Operator.

## Public exposure

Ingress and Gateway API are opt-in and mutually exclusive. Set
`ghostfolio.rootUrl` to the canonical HTTPS origin in production. The chart can
derive it from the first Ingress host or HTTPRoute hostname, but an explicit
value makes OIDC callback behavior unambiguous. Set `ghostfolio.trustProxy` to
the exact Express proxy trust policy for the chosen ingress path.

## Network policy

The default policy permits namespace-local HTTP ingress, DNS, the bundled data
services, and public HTTP/HTTPS for Ghostfolio market-data providers. Public
egress excludes private and special-use ranges. External private PostgreSQL and
Redis services therefore require `networkPolicyPeers` or `extraEgress`.

## State and recovery

PostgreSQL is the system of record. The application has no chart-owned data
PVC. Redis persistence supports cache continuity but does not replace a
PostgreSQL backup. Before upgrades:

1. Create a transactionally consistent PostgreSQL backup.
2. Record the Ghostfolio image and chart versions.
3. Preserve the application Secret and external credentials.
4. Restore into an isolated namespace and verify login, account history,
   holdings, and provider refresh before declaring recovery successful.

See [docs/operations.md](docs/operations.md) for rollout and recovery details.

## Key values

| Value | Default | Purpose |
|---|---:|---|
| `image.tag` | `3.82.0@sha256:...` | Immutable official application image |
| `replicaCount` | `1` | Enforced singleton migration and cron owner |
| `ghostfolio.rootUrl` | derived | Canonical external origin |
| `ghostfolio.existingSecret` | `""` | Retained access-token salt and JWT secret |
| `oidc.enabled` | `false` | Experimental upstream OpenID Connect |
| `postgresql.enabled` | `true` | Bundled PostgreSQL dependency |
| `redis.enabled` | `true` | Bundled Redis dependency |
| `database.external.enabled` | `false` | Complete external DATABASE_URL Secret mode |
| `redis.external.enabled` | `false` | External Redis mode |
| `networkPolicy.enabled` | `true` | Product-aware ingress and egress isolation |
| `service.ipFamilyPolicy` | `""` | Cluster default or explicit dual-stack policy |
| `gatewayAPI.rootUrlScheme` | `https` | Scheme used for an HTTPRoute-derived public URL |

Every value and nested contract is documented in [values.yaml](values.yaml)
and validated by [values.schema.json](values.schema.json).

## Validation scenarios

The chart carries runtime scenarios for default services, Ingress, Gateway API,
dual-stack, OIDC, External Secrets, and external PostgreSQL/Redis. The
product-specific smoke test proves migrations and seed ran, both official
health endpoints return `OK`, the runtime is singleton, and application identity
is backed by a nonempty Secret.

## Security scan

Security scan results use the same Kubescape policy set as HelmForge CI.

Security Scan: ghostfolio

| Framework                | Score |
| ------------------------ | ----: |
| MITRE                    | **100.00%** |
| NSA                      |  **91.25%** |
| SOC 2                    |  **94.29%** |
| Aggregate resource score |  **93.83%** |

Kubescape reported no critical or high-severity failures. Remaining medium and
low findings come from the maintained PostgreSQL and Redis dependency workloads,
including their independent NetworkPolicy, service-account, seccomp, and
writable-database-filesystem contracts.

## Limitations

- OIDC and health endpoints are marked experimental by upstream.
- No upstream Prometheus endpoint is documented, so the chart does not create a
  misleading ServiceMonitor.
- Horizontal application scaling is intentionally unsupported until Ghostfolio
  documents safe migration and scheduled-job coordination.
- The chart cannot validate external data-provider availability or correctness.

## Additional documentation

- [Design](DESIGN.md)
- [External PostgreSQL and Redis](docs/external-services.md)
- [OIDC](docs/oidc.md)
- [Operations and recovery](docs/operations.md)
- [Production example](examples/production.yaml)
