<!-- SPDX-License-Identifier: Apache-2.0 -->

# Documenso Helm chart

Deploy [Documenso](https://documenso.com), an open-source electronic-signature
platform, with a pinned official image, PostgreSQL, optional BullMQ, object
storage, External Secrets, and hardened Kubernetes networking.

## Features

- Official Documenso image pinned by immutable multi-platform digest.
- Bundled HelmForge PostgreSQL and optional Redis 3.1 dependency, or complete
  external-service Secret contracts.
- Local, BullMQ, and Inngest background-job modes with scale-out safeguards.
- Database or S3-compatible document storage and Secret-backed PKCS#12 signing.
- Native External Secrets resources, Ingress, Gateway API, HPA, PDB, and
  dual-stack Service support.
- Restricted non-root runtime, additive NetworkPolicy controls, native health
  probes, and behavioral k3d validation.

## Install

```bash
helm install documenso oci://ghcr.io/helmforgedev/helm/documenso \
  --version 1.0.0 \
  --namespace documenso \
  --create-namespace
```

Keep public registration protected until the initial administrative account and
mail delivery have been verified.

## Architecture

The official entrypoint applies Prisma migrations and starts the Node.js
application on port 3000. The chart waits for PostgreSQL but does not replace
the authenticated migration or health checks with a TCP test.

The default topology is a basic single-replica installation with HelmForge
PostgreSQL and database-backed local jobs. It starts the application, but
document signing remains unavailable until a PKCS#12 certificate is configured.
Production scale-out requires
`documenso.jobsProvider=bullmq`, shared Redis, and S3-compatible storage. The
chart enforces those prerequisites when `replicaCount` is greater than one or
autoscaling is enabled.

The full component and trust-boundary topology is documented in
[DESIGN.md](DESIGN.md).

## Image provenance

The default image is
`ghcr.io/documenso/documenso@sha256:d9985f66c19c59128f64b1439f057683da0110deb0e518655b97f06e3141f173`,
the official v2.21.0 Linux amd64/arm64 manifest verified on 2026-10-21. Review
the [upstream release](https://github.com/documenso/documenso/releases/tag/v2.21.0)
before production rollout.

## Health contract

- Startup and readiness: `GET /api/health`, including PostgreSQL and
  certificate status.
- Liveness: TCP port 3000, deliberately independent of PostgreSQL.
- Certificate diagnostics: `GET /api/certificate-status`.

A missing signing certificate can produce a health warning without preventing a
basic rollout. Production signing should enable the Secret-backed certificate.

## Secrets and signing

By default, the chart creates and retains `NEXTAUTH_SECRET` and both encryption
keys using Helm cluster lookup. Set `documenso.existingSecret` for deterministic
GitOps and disaster recovery. Rotating encryption keys without an application
migration can make stored values unreadable.

Set `certificate.enabled` and provide a PKCS#12 file and passphrase through an
existing Secret. SMTP, S3, database, Redis, and Gotenberg credentials are also
Secret references. The canonical `externalSecrets.items` contract can
materialize any of them with External Secrets Operator.

## Network and public exposure

Ingress and Gateway API are opt-in and mutually exclusive. Set the canonical
HTTPS `documenso.publicUrl` explicitly in production. The chart can derive it
from the first Ingress host or HTTPRoute hostname for simpler environments.

NetworkPolicy permits namespace-local HTTP ingress, DNS, selected PostgreSQL and
Redis services, and public HTTP/HTTPS. Broad public egress excludes private
ranges; private SMTP, object-storage, Gotenberg, identity-provider, and webhook
destinations need explicit `networkPolicy.extraEgress` rules. Add an Ingress or
Gateway controller from another namespace to `networkPolicy.ingressFrom`. A
non-empty list replaces the default namespace-local peer; include
`podSelector: {}` alongside the controller peer to preserve same-namespace
access.

## State and recovery

PostgreSQL is the system of record. With database storage it also contains
documents; with S3, database and bucket must be backed up consistently.
Recovery must preserve:

1. PostgreSQL.
2. The S3 bucket when enabled.
3. The application identity Secret.
4. The signing certificate and integration Secrets.
5. Redis when in-flight BullMQ jobs must survive.

Restore the same image version into an isolated namespace, verify login,
document access, and signing, and only then perform an upgrade.

## Examples

The production example combines external PostgreSQL and Redis, BullMQ, S3,
signing, and hardened exposure. Copy
[examples/production.yaml](examples/production.yaml), replace every placeholder
Secret and hostname, then install it with:

```bash
helm upgrade --install documenso oci://ghcr.io/helmforgedev/helm/documenso \
  --namespace documenso --create-namespace -f production.yaml
```

## Configuration

Start with the default single-replica topology for evaluation, then make the
state, identity, mail, and exposure choices explicit before production. The
local job provider stores work in PostgreSQL and calls back into the application;
it is intended for development and small installations. BullMQ requires Redis
6.2 or later and provides a self-hosted production queue. Inngest remains an
upstream-managed alternative configured through `documenso.extraEnv`.

Documenso can keep documents in PostgreSQL, but an S3-compatible store is the
appropriate shared backend for multi-replica and high-volume installations.
Production signing additionally requires a PKCS#12 certificate, while recipient
notifications require SMTP. Treat the database, object store, application
identity keys, certificate, and integration credentials as one recovery set.
The table highlights every operational group; [values.yaml](values.yaml) is the
complete, commented contract, including resource and scheduling subfields.

| Value | Default | Purpose |
|---|---:|---|
| `global` | `{}` | Values shared with dependency charts |
| `image.tag` | `v2.21.0` | Human-readable upstream release |
| `image.digest` | pinned | Immutable official multi-platform manifest |
| `replicaCount` | `1` | Application replicas |
| `autoscaling.enabled` | `false` | CPU-based HPA with scale-out safeguards |
| `autoscaling.minReplicas` | `2` | Minimum HPA replica count |
| `autoscaling.maxReplicas` | `5` | Maximum HPA replica count |
| `podDisruptionBudget.enabled` | `true` | Protect voluntary disruption availability |
| `documenso.publicUrl` | `""` | Canonical public URL, or derive from routing |
| `documenso.mailFromAddress` | `noreply@example.com` | Transactional sender address |
| `documenso.jobsProvider` | `local` | PostgreSQL, BullMQ, or Inngest jobs |
| `documenso.existingSecret` | `""` | Persistent identity keys |
| `documenso.extraEnv` | `[]` | Supported advanced upstream settings |
| `database.external.enabled` | `false` | Use externally managed PostgreSQL |
| `database.external.existingSecret` | `""` | Complete URL-encoded database URLs |
| `database.external.directUrlEnabled` | `false` | Supply a direct Prisma migration URL |
| `postgresql.enabled` | `true` | Bundled HelmForge PostgreSQL 2.1.1 |
| `postgresql.standalone.persistence.size` | `8Gi` | Bundled database capacity |
| `redis.enabled` | `false` | Bundled HelmForge Redis 3.1.0 for BullMQ |
| `redis.external.enabled` | `false` | Use an external Redis service |
| `redis.external.existingSecret` | `""` | External Redis password Secret |
| `smtp.enabled` | `false` | Configure authenticated SMTP |
| `smtp.existingSecret` | `""` | SMTP username and password Secret |
| `objectStorage.provider` | `database` | Database or S3 document storage |
| `objectStorage.s3.bucket` | `""` | S3-compatible document bucket |
| `objectStorage.s3.existingSecret` | `""` | S3 access credentials |
| `certificate.enabled` | `false` | Secret-backed PKCS#12 signing |
| `certificate.existingSecret` | `""` | Certificate and passphrase Secret |
| `gotenberg.enabled` | `false` | Use an external conversion service |
| `externalSecrets.enabled` | `false` | Render native ExternalSecret resources |
| `externalSecrets.items` | `[]` | Complete ExternalSecret specifications |
| `serviceAccount.automountServiceAccountToken` | `false` | Keep API credentials out of the pod |
| `service.type` | `ClusterIP` | Kubernetes Service type |
| `service.port` | `3000` | Client-facing Service port |
| `ingress.enabled` | `false` | Render Kubernetes Ingress |
| `gatewayAPI.enabled` | `false` | Render Gateway API HTTPRoutes |
| `probes.startup.enabled` | `true` | Protect migration startup time |
| `probes.readiness.enabled` | `true` | Gate traffic on native health |
| `runtimeStorage.sizeLimit` | `512Mi` | Per-runtime `emptyDir` capacity |
| `networkPolicy.enabled` | `true` | Product-aware traffic isolation |
| `networkPolicy.egressIsolation` | `true` | Restrict application egress |
| `networkPolicy.ingressFrom` | `[]` | Additional Ingress or Gateway controller peers |
| `networkPolicy.extraEgress` | `[]` | Installation-specific egress rules |

Every value is documented in [values.yaml](values.yaml) and checked by
[values.schema.json](values.schema.json).

## Validation scenarios

The chart tests the default topology, BullMQ with Redis, Ingress, Gateway API,
dual-stack Service, native External Secrets, immutable identity keys, external
service invariants, disruption protection, autoscaling, and scale-out safety.
The chart-owned `scripts/runtime-smoke.mjs` check verifies application health,
UID 1001, and a non-empty identity Secret. The k3d wrapper separately verifies
rollout readiness, restart state, warning or failure events, and selected crash
or error signatures in Pod logs.

## Security scan

Security Scan: documenso

| Framework | Score |
|---|---:|
| MITRE | **100.00%** |
| NSA | **95.83%** |
| SOC 2 | **96.00%** |
| Aggregate resource score | **96.87%** |

Kubescape reported no critical or high-severity failures. The remaining medium
and low findings are in the maintained stateful-service dependencies, whose
writable data filesystems and independent NetworkPolicy contracts are required.

## Limitations

- Upstream runs migrations in every application process; use controlled rolling
  updates and tested backups.
- The local jobs provider is unsuitable for multi-replica production.
- No native Prometheus endpoint is documented, so the chart does not create a
  misleading ServiceMonitor.
- Webhook destinations are dynamic and may require per-installation egress rules.

## Troubleshooting

- If the pod is ready but signing fails, configure `certificate.enabled` and
  inspect `/api/certificate-status`; upstream intentionally starts without a
  signing certificate.
- If startup waits for PostgreSQL, verify the bundled database pod or the
  external host, port, Secret URLs, and NetworkPolicy peers.
- If BullMQ jobs do not advance, confirm `documenso.jobsProvider=bullmq`, Redis
  authentication, and access to the configured Redis service.
- If local jobs cannot call back through a reverse proxy, set the upstream
  `NEXT_PRIVATE_INTERNAL_WEBAPP_URL` through `documenso.extraEnv`.
- If SMTP, S3, Gotenberg, OAuth, or webhooks time out, add explicit egress rules
  for private destinations and confirm the cluster CNI enforces NetworkPolicy.

## Additional documentation

- [Design](DESIGN.md)
- [External services](docs/external-services.md)
- [Operations and recovery](docs/operations.md)
- [Production example](examples/production.yaml)
