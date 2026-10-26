<!-- SPDX-License-Identifier: Apache-2.0 -->

# Ghostfolio Helm chart

Deploy [Ghostfolio](https://ghostfol.io), the open-source wealth-management
application, with a pinned official image, PostgreSQL, Redis, OIDC,
External Secrets, hardened networking, and upstream-native health checks.

## Features

- Official, pinned Ghostfolio image with no floating tag.
- Maintained PostgreSQL and Redis dependencies plus explicit external-service
  Secret contracts.
- A configurable application listener that changes the real upstream `PORT`.
- Ingress and Gateway API exposure with canonical URL and proxy controls.
- Experimental OIDC, native External Secrets resources and retained identity.
- Hardened non-root runtime, read-only root filesystem and product-aware
  NetworkPolicy.
- Upstream liveness and dependency-aware readiness probes.

## Architecture

One Ghostfolio Deployment owns migrations, seeding, scheduled work and the web
server. PostgreSQL is the system of record and Redis provides operational cache
state. Both services can be deployed as HelmForge dependencies or supplied
externally through Secret-backed contracts. See [DESIGN.md](DESIGN.md) for
topology diagrams, boundaries and the singleton rationale.

## Install

```bash
helm install ghostfolio oci://ghcr.io/helmforgedev/helm/ghostfolio \
  --namespace ghostfolio \
  --create-namespace
```

The first registered account becomes the administrator. Keep the installation
private until that registration is complete.

## Configuration

`containerPorts.http` configures the real Ghostfolio HTTP listener through the
official `PORT` environment variable. `service.port` independently controls the
Kubernetes Service port and targets the named `http` container port. Both
default to `3333`. Because the application runs as UID 1000 with every Linux
capability dropped, the listener must remain at or above 1024.

| Value                                         | Default  | Purpose |
| --------------------------------------------- | -------- | ------- |
| `containerPorts.http`                         | `3333`   | Ghostfolio process listener |
| `service.port`                                | `3333`   | Kubernetes Service-facing port |
| `ghostfolio.rootUrl`                          | derived  | Canonical public origin and OIDC callback base |
| `ghostfolio.trustProxy`                       | `""`     | Exact Express trusted-proxy policy |
| `ghostfolio.existingSecret`                   | `""`     | Stable access-token salt and JWT secret |
| `postgresql.enabled`                          | `true`   | Deploy the HelmForge PostgreSQL dependency |
| `redis.enabled`                               | `true`   | Deploy the HelmForge Redis dependency |
| `database.external.enabled`                   | `false`  | Use complete external PostgreSQL URL Secrets |
| `redis.external.enabled`                      | `false`  | Use an external Redis endpoint and password Secret |
| `serviceAccount.automountServiceAccountToken` | `false`  | Keep the Kubernetes API token unmounted |
| `networkPolicy.enabled`                       | `true`   | Apply product-aware ingress and egress isolation |

Every value and nested contract is documented in [values.yaml](values.yaml)
and validated by [values.schema.json](values.schema.json).

## Examples

Use [`examples/production.yaml`](examples/production.yaml) as a hardened
starting point and [`examples/oidc.yaml`](examples/oidc.yaml) for experimental
OIDC. Store all application identity, provider, database and Redis credentials
in Kubernetes Secrets or native ExternalSecret resources.

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

The default is the official release image
`docker.io/ghostfolio/ghostfolio:3.88.0`. Its manifest was verified for Linux
amd64, arm/v7, and arm64 on 2026-10-15.

Ghostfolio 3.88.0 adds yearly performance views and experimental AI imports,
expands MCP sharing permissions, and improves historical market-data queries.
It also fixes negative-UTC date ranges, benchmark dates, filtered cash balances,
mobile overflow, and MCP access enforcement. Upstream documents no breaking
configuration change between 3.82.0 and 3.88.0. Review the
[3.88.0 release notes](https://github.com/ghostfolio/ghostfolio/releases/tag/3.88.0)
before production rollout.

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

## Security

The application and dependency-wait containers run without root privileges or
added capabilities. Ghostfolio receives no Kubernetes API token and can write
only to its bounded temporary and npm-cache volumes. The default NetworkPolicy
permits DNS, bundled state services and public HTTP/HTTPS market-data traffic;
private external destinations require explicit peers. Keep first-user
registration private and use HTTPS for every public endpoint.

## Key values

| Value | Default | Purpose |
|---|---:|---|
| `image.tag` | `3.88.0` | Pinned official application release |
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

## Troubleshooting

- If startup stalls, inspect both dependency-wait init containers and confirm
  the PostgreSQL and Redis Services have endpoints.
- If readiness fails while liveness succeeds, inspect `/api/v1/health` and the
  database and Redis credentials; dependency loss intentionally withdraws
  traffic without restarting the process.
- If OIDC redirects fail, align `ghostfolio.rootUrl`, the registered callback
  and the proxy trust policy.
- If NetworkPolicy blocks an external private service, add the appropriate
  `networkPolicyPeers` or native `networkPolicy.extraEgress` rule.
- Keep `replicaCount=1`; the chart rejects additional replicas because upstream
  does not document migration or scheduled-job leader election.

## Security Scan: `ghostfolio`

Security scan results use the same Kubescape policy set as HelmForge CI.

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
