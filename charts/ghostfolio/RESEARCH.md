# Ghostfolio chart research

## Request

- Issue: `helmforgedev/charts#1419`
- Requester: `Aidas-dev`
- Upstream: <https://github.com/ghostfolio/ghostfolio>
- Research date: 2026-10-09

## Verified upstream contract

Ghostfolio 3.82.0 is an Angular and NestJS wealth-management application. The
official container is `docker.io/ghostfolio/ghostfolio:3.82.0`; its
multi-platform OCI index was verified for Linux amd64, arm/v7, and arm64 and
resolved to
`sha256:3b87436abfe7daae20a8bd5862bda230d327a5af49a837f888c007863ecb94fb`.
The digest records the verification evidence; the chart default uses the
official release tag `3.82.0`. The image runs as the upstream `node` user and
exposes port 3333.

PostgreSQL and Redis are mandatory. The upstream entrypoint runs
`prisma migrate deploy`, seeds the database, and only then starts the server.
The upstream documentation identifies `/api/v1/health` as a readiness check of
both dependencies and `/api/v1/health/liveness` as the dependency-free startup
and liveness check. Redis checks can take five seconds.

Ghostfolio exposes experimental OIDC authentication and requires issuer,
client ID, and client secret when enabled. `ROOT_URL` determines generated
callbacks. The process also owns scheduled data gathering by default. Neither
migration locking nor cron leader election is documented, so the chart is
deliberately singleton.

## Existing chart comparison

Community charts exist, including `ByTheHugo/ghostfolio-helm` and TrueCharts.
They reduce installation effort but do not form an official upstream release
contract. The HelmForge implementation differentiates itself through:

1. Immutable official multi-architecture image selection and validation.
2. Maintained optional PostgreSQL and Redis dependencies plus exact external
   connection Secret contracts.
3. Upstream-specific startup, liveness, and readiness probes.
4. Retained application salts, native OIDC Secret integration, and canonical
   External Secrets resources.
5. Ingress, Gateway API, dual-stack Service, restrictive NetworkPolicy, and
   baseline Pod Security defaults.
6. Explicit singleton enforcement for migration and scheduled-job safety.

## Production boundaries

- Bundled data services are convenient evaluation and small-installation
  topologies. Managed PostgreSQL and Redis are recommended for production.
- PostgreSQL is the system of record. Back up it consistently and verify
  restores in isolation before upgrades.
- Redis persistence does not replace PostgreSQL backups.
- Ghostfolio has no documented Prometheus endpoint, so this chart does not
  invent a ServiceMonitor.
- Market-data collection requires public HTTP and HTTPS egress. Private
  database or Redis destinations require explicit NetworkPolicy peers.
- The application has no chart-owned data PVC; imported portfolio data lives
  in PostgreSQL.

## Sources

- <https://github.com/ghostfolio/ghostfolio/releases/tag/3.82.0>
- <https://github.com/ghostfolio/ghostfolio/blob/3.82.0/README.md>
- <https://github.com/ghostfolio/ghostfolio/blob/3.82.0/Dockerfile>
- <https://github.com/ghostfolio/ghostfolio/blob/3.82.0/docker/entrypoint.sh>
- <https://github.com/ghostfolio/ghostfolio/blob/3.82.0/docker/docker-compose.yml>
- <https://hub.docker.com/r/ghostfolio/ghostfolio/tags>
- <https://github.com/ByTheHugo/ghostfolio-helm>
