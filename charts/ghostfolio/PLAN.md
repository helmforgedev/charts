# Ghostfolio chart implementation plan

## Objective

Deliver the first production-oriented HelmForge Ghostfolio release as chart
version 1.0.0, using the official application image and preserving the exact
upstream startup contract.

## Priority 1: safe runnable foundation

- Deploy exactly one Ghostfolio pod with the pinned official release image.
- Provide retained JWT and access-token salts without placing generated values
  in a Deployment.
- Connect to bundled or external PostgreSQL and Redis.
- Wait for dependency sockets before the upstream migration entrypoint runs.
- Use native startup, liveness, and readiness endpoints.

## Priority 2: production integration

- Support OIDC with client secrets sourced only from a Kubernetes Secret.
- Support Ingress and Gateway API without enabling either implicitly.
- Support IPv4, IPv6, and dual-stack Service selection.
- Enforce non-root, tokenless, least-privilege runtime defaults.
- Restrict network ingress and document public market-data egress.
- Support External Secrets Operator through the canonical items contract.

## Priority 3: operations and evidence

- Document PostgreSQL backup and restore ownership, upgrades, OIDC callbacks,
  network policy, provider credentials, and singleton limitations.
- Test generated and existing Secrets, dependency modes, probes, routing,
  dual-stack, OIDC, and invalid configurations.
- Validate default, external-service, OIDC, Gateway API, Ingress, dual-stack,
  and External Secrets scenarios locally and in CI.

## Validation strategy

The acceptance gate is `make validate-chart CHART=ghostfolio`, followed by
`make standards-check CHART=ghostfolio`, the dedicated External Secrets
runtime test, site lint/build, and the repository-wide preflight. Runtime smoke
must prove the real 3.82.0 image becomes Ready against PostgreSQL and Redis and
that both official health endpoints answer successfully.

## Risks and mitigations

- Concurrent Prisma migrations or duplicate cron work: enforce one replica.
- Random Secret rotation under GitOps rendering: recommend explicit existing
  Secrets; cluster installs preserve generated values with `lookup`.
- Redis readiness latency: keep probe timeout at least five seconds.
- External poolers: expose a distinct `DIRECT_URL` Secret key for migrations.
- Undocumented metrics: do not publish a false monitoring contract.
