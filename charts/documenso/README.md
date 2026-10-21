# Documenso Helm chart

Deploy [Documenso](https://documenso.com), an open-source electronic-signature
platform, with a pinned official image, PostgreSQL, optional BullMQ, object
storage, External Secrets, and hardened Kubernetes networking.

## Install

```bash
helm install documenso oci://ghcr.io/helmforgedev/helm/documenso \
  --version 1.0.0 \
  --namespace documenso \
  --create-namespace
```

Keep public registration protected until the initial administrative account and
mail delivery have been verified.

## Runtime model

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
destinations need explicit `networkPolicy.extraEgress` rules.

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

## Key values

| Value | Default | Purpose |
|---|---:|---|
| `image.tag` | `v2.21.0` | Human-readable upstream release |
| `image.digest` | pinned | Immutable official multi-platform manifest |
| `replicaCount` | `1` | Application replicas |
| `autoscaling.enabled` | `false` | CPU-based HPA with scale-out safeguards |
| `podDisruptionBudget.enabled` | `true` | Protect voluntary disruption availability |
| `documenso.jobsProvider` | `local` | PostgreSQL, BullMQ, or Inngest jobs |
| `documenso.existingSecret` | `""` | Persistent identity keys |
| `postgresql.enabled` | `true` | Bundled HelmForge PostgreSQL |
| `redis.enabled` | `false` | Bundled HelmForge Redis for BullMQ |
| `objectStorage.provider` | `database` | Database or S3 document storage |
| `certificate.enabled` | `false` | Secret-backed PKCS#12 signing |
| `networkPolicy.enabled` | `true` | Product-aware traffic isolation |

Every value is documented in [values.yaml](values.yaml) and checked by
[values.schema.json](values.schema.json).

## Validation scenarios

The chart tests the default topology, BullMQ with Redis, Ingress, Gateway API,
dual-stack Service, native External Secrets, immutable identity keys, external
service invariants, disruption protection, autoscaling, and scale-out safety. The k3d smoke verifies application
health, the upstream UID, generated identity, clean events/logs, and stable
rollout.

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

## Additional documentation

- [Design](DESIGN.md)
- [External services](docs/external-services.md)
- [Operations and recovery](docs/operations.md)
- [Production example](examples/production.yaml)
