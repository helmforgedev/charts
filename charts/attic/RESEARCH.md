# Attic Helm Chart Research

**Chart request:** helmforgedev/charts#1378
**Requester:** Aidas-dev
**Upstream:** <https://github.com/zhaofengli/attic>
**Research date:** 2026-09-29

## Product and release state

Attic is a self-hosted, multi-tenant Nix binary cache with global content
deduplication, managed signing keys, token-scoped access and garbage collection.
The upstream project remains an early prototype: it has no GitHub releases or
git tags and warns that APIs and database formats may change incompatibly.

The official image is `ghcr.io/zhaofengli/attic`. HelmForge pins the immutable
commit tag `9eda345a743f50999de04f59a170806c3e029eea`, whose manifest digest is
`sha256:325036ce0776ed6e2705819c6bd1ebd1635b0422723110116adf56edf8ea12bd`.
It supports linux/amd64 and linux/arm64. The image entrypoint is `/bin/atticd`,
runs as root unless Kubernetes overrides the UID, and has no image healthcheck.

## Runtime architecture

Attic listens on port 8080 and reads TOML configuration. It supports:

- `monolithic`: migrations, API and garbage collection in one process;
- `api-server`: stateless HTTP API that can be replicated;
- `db-migrations`: one-shot schema migration;
- `garbage-collector`: singleton periodic collector;
- `check-config`: configuration validation.

SQLite plus local object storage is suitable only for a single replica. The
upstream recommendation for production is PostgreSQL plus S3-compatible object
storage, separate API and garbage-collector processes, and TLS at a proxy or
load balancer. There is no native Prometheus endpoint or deep health endpoint.

## Existing deployment options

| Option | Strengths | Material gaps |
| --- | --- | --- |
| drbh/attic-helm | Dedicated chart, PVC and S3 options | Floating image, no schema, HA, ESO, policy or tests |
| maybeanerd/home-cluster | PostgreSQL and probes | Environment-specific app-template wrapper, one replica |
| agentydragon/cluster | PostgreSQL option and Ingress | Bitnami dependency, default password, floating image |
| jeiang/k8s-manifests | Non-root and external services | Unofficial image and private-environment coupling |
| vrozaksen/home-ops | Split API, migration and GC topology | GitOps-specific app-template configuration, not a distributable chart |

No official chart or maintained Artifact Hub package was found.

## Production requirements

- Preserve a single persistent domain for SQLite metadata and local objects.
- Reject multiple replicas outside PostgreSQL plus S3 mode.
- Run database migrations once before distributed API startup.
- Keep garbage collection singleton.
- Source database, JWT and S3 credentials from a Secret; support External
  Secrets without placing credentials in values.
- Keep `require-proof-of-possession=true` by default.
- Require an explicit canonical API endpoint and allowed hosts when external
  exposure is enabled.
- Run the official root-default image as an arbitrary non-root UID with a
  read-only root filesystem and writable data/tmp mounts.
- Treat `/` probes as process checks only; document that they do not validate
  PostgreSQL or S3.
- Back up metadata and object storage as a coordinated set. There is no native
  Attic backup command.
- Document large request-body and timeout requirements for proxies.

## HelmForge differentiation

1. Explicit `standalone` and `distributed` topologies with fail-fast safety.
2. Correct migration/API/GC lifecycle rather than a single generic Deployment.
3. Official immutable multi-architecture image and conservative beta maturity.
4. Existing Secret and canonical External Secrets support.
5. Ingress, Gateway API, dual-stack Service and NetworkPolicy contracts.
6. Product-specific docs for Nix trust, cache bootstrap, retention and backup.
7. Behavioral validation that exercises the real Attic image and HTTP API.

## Risks and non-goals

- Upstream does not offer a semver release channel.
- Database compatibility across image updates is not guaranteed.
- Custom S3 endpoints used for presigned URLs must be reachable by clients.
- The chart does not invent Prometheus metrics or claim deep dependency probes.
- The chart does not automate creation or rotation of long-lived signing keys.
- Bundled PostgreSQL is intentionally omitted; operators may use the HelmForge
  PostgreSQL chart or a managed service and pass its URL through a Secret.

## Sources

- <https://github.com/zhaofengli/attic>
- <https://docs.attic.rs/tutorial.html>
- <https://docs.attic.rs/reference/atticd-cli.html>
- <https://github.com/zhaofengli/attic/blob/main/server/src/config-template.toml>
- <https://github.com/zhaofengli/attic/pkgs/container/attic>
- <https://github.com/vrozaksen/home-ops/blob/main/kubernetes/platform/development/attic/helmrelease.yaml>
