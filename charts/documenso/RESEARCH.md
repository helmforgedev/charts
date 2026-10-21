# Documenso research

Research date: 2026-10-21.

## Upstream release and image

The chart targets Documenso v2.21.0, commit
`359177ee9054e5187e8ff66cf11e98cbae3bca70`. The official multi-platform
image `ghcr.io/documenso/documenso:v2.21.0` was verified as Linux amd64 and
arm64 with manifest digest
`sha256:d9985f66c19c59128f64b1439f057683da0110deb0e518655b97f06e3141f173`.
Documenso is licensed under AGPL-3.0.

## Runtime contract

The official image runs a Node.js application on port 3000 as UID/GID 1001.
Its entrypoint applies Prisma migrations before starting the server. PostgreSQL
14 or newer is required. Background jobs use PostgreSQL in `local` mode,
Redis with `bullmq`, or managed Inngest. There is no separate worker image.

`GET /api/health` reports database and certificate health. Liveness uses TCP
so a state-service outage removes readiness without repeatedly restarting the
application. The chart keeps the upstream entrypoint and allows five minutes
for startup migrations.

## State and integrations

The application itself is stateless. Documents are stored in PostgreSQL by
default or in S3-compatible storage. Production identity depends on stable
NextAuth and encryption keys. Signing can use a Secret-backed PKCS#12 file.
SMTP, Gotenberg, OAuth, webhooks, and object storage are outbound integrations.

The chart therefore includes HelmForge PostgreSQL, optional HelmForge Redis,
external-service Secret contracts, native External Secrets resources, and
explicit egress controls. It intentionally creates no application PVC and no
ServiceMonitor because upstream exposes no Prometheus endpoint.

## Existing implementations

Upstream publishes Kubernetes examples but no maintained Helm chart. The
community chart reviewed during research was pinned to an old application,
placed secrets in a ConfigMap, probed the root page, and omitted schema,
Gateway API, ESO, dependency, security, and recovery contracts. This chart is
an independent production design rather than a wrapper around that chart.

## Sources

- [Release v2.21.0](https://github.com/documenso/documenso/releases/tag/v2.21.0)
- [Architecture](https://github.com/documenso/documenso/blob/v2.21.0/ARCHITECTURE.md)
- [Container startup](https://github.com/documenso/documenso/blob/v2.21.0/docker/start.sh)
- [Self-hosting](https://docs.documenso.com/docs/self-hosting)
- [Environment variables](https://docs.documenso.com/docs/self-hosting/configuration/environment)
- [Background jobs](https://docs.documenso.com/docs/self-hosting/configuration/background-jobs)
- [Storage](https://docs.documenso.com/docs/self-hosting/configuration/storage)
- [Backups](https://docs.documenso.com/docs/self-hosting/maintenance/backups)
