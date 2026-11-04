<!-- SPDX-License-Identifier: Apache-2.0 -->

# Discourse research

Issue: helmforgedev/charts#1822

## Feasibility decision

Discourse is an open-source community platform built on Ruby, PostgreSQL, and
Redis. The upstream-supported self-hosting path uses `discourse_docker` and its
launcher to build a site-specific image. Kubernetes and the directly runnable
`discourse/discourse` image remain classified by upstream as experimental and
unsupported for production.

The maintainer explicitly authorized an experimental HelmForge exception. The
chart must remain beta, must never claim upstream production support, and must
pin the official image by both version and immutable multi-architecture digest.

## Official runtime

- Official image: `docker.io/discourse/discourse:2026.7.4`.
- Immutable image index: `sha256:8ae4f1e692a5da1548a36a6d9fc2bae18cf28d1efbebb12ba16928b31b14783d`.
- Platforms: `linux/amd64` and `linux/arm64`.
- Boot: root-owned `/sbin/boot` supervises Nginx, Pitchfork/Unicorn, and
  Sidekiq through runit.
- HTTP: Nginx listens on port 80 and exposes `/srv/status`.
- State: `/shared` contains uploads, backups, logs, and runtime state.
- Services: PostgreSQL 15 or newer and Redis 7 are required.
- Boot operations: migrations, asset precompilation, and database creation are
  enabled by default in the experimental image.

The image cannot safely use `runAsNonRoot`, a read-only root filesystem, or a
complete capability drop without replacing upstream boot behavior. Those are
documented security exceptions, not accidental omissions.

## Existing charts

| Option | Strengths | Gaps or policy conflict |
|---|---|---|
| UpstreamYard `discourse` | Current app, web/Sidekiq split, migration Jobs, schema | Uses a community-built image; no NetworkPolicy, PDB, Gateway API, ESO, or dual-stack |
| Bitnami `discourse` | Broad historical configuration, bundled PostgreSQL/Redis | Deprecated community image, prohibited by HelmForge, no current production support |
| Riftbit `discourse` | Familiar Bitnami-derived surface | Stale, no schema, old dependencies and image model |
| `trizvanov/helm-discourse` | Small proof of concept | Abandoned; missing scaling, workers, SMTP, and S3 |

There is no upstream-supported official Discourse Helm chart.

## Experimental production boundary

The supported initial topology is intentionally conservative:

- one Discourse replica;
- one official all-in-one web runtime, including its supervised Sidekiq worker;
- HelmForge PostgreSQL and Redis subcharts by default, with external-service
  contracts for operators that provide managed services;
- a ReadWriteOnce `/shared` PVC;
- Recreate rollout strategy;
- no HPA, no multi-replica claim, and no plugin installation at boot;
- opt-in Ingress, Gateway API, External Secrets, NetworkPolicy, and dual-stack.

S3-backed uploads and independent workers are deferred until the upstream
image contract is supported and validated. Plugins require a custom image and
are outside this chart's official-image-only scope.

## HelmForge differentiation

| Feature | Impact | HelmForge approach |
|---|---:|---|
| Reproducible official runtime | 5/5 | Exact ESR tag plus immutable multi-arch digest |
| Safe dependency contract | 5/5 | Current HelmForge PostgreSQL and Redis subcharts or explicit external endpoints |
| Honest support boundary | 5/5 | Beta maturity, singleton enforcement, root/runtime exceptions, and no unsupported HA claims |
| Secret lifecycle | 5/5 | Existing Secrets plus canonical External Secrets `items[]` integration |
| Kubernetes exposure | 5/5 | Named Service target, dual-stack, Ingress, and Gateway API HTTPRoute |
| Operational evidence | 5/5 | `/srv/status` probes, k3d smoke, logs/events review, persistence and upgrade validation |

## Security and operations

- Generate or reference a stable `DISCOURSE_SECRET_KEY_BASE` Secret.
- Keep database, Redis, and SMTP credentials out of ConfigMaps.
- Disable service-account token mounting.
- Allow the upstream root boot contract while dropping all unnecessary
  capabilities and preventing privilege escalation where runtime validation
  permits it.
- Recommend managed PostgreSQL/Redis and object storage for serious evaluation,
  while making clear that upstream still does not support this Kubernetes path.
- Back up both PostgreSQL and `/shared`; a database-only backup is incomplete.

## Sources

- <https://github.com/discourse/discourse>
- <https://github.com/discourse/discourse_docker>
- <https://meta.discourse.org/t/is-docker-image-discourse-discourse-considered-safe-and-production-ready/380646>
- <https://meta.discourse.org/t/discourse-discourse-docker-image-sources/412520>
- <https://meta.discourse.org/t/discourse-setup-on-kubernetes-cluster-using-helm/256785>
- <https://artifacthub.io/packages/helm/upstreamyard/discourse>
- <https://github.com/bitnami/charts/tree/main/bitnami/discourse>
