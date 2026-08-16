# Ente - Research Findings

**Chart request:** [#980](https://github.com/helmforgedev/charts/issues/980)
**Requester:** `@Alxtp`
**Upstream:** <https://github.com/ente/ente>
**Research date:** 2026-08-15

## Recommendation

Ship Ente as a stable HelmForge chart. The upstream server release process builds
an official image from the exact commit currently running in Ente production,
which provides a defensible stable channel even though Museum does not use
semantic image tags. The chart must pin that commit and must not use `latest`.

The chart should deploy Ente Photos, not every Ente product. Its supported
runtime consists of Museum, the web bundle, PostgreSQL, and externally managed
S3-compatible object storage. S3 is intentionally not bundled because Ente's
official documentation recommends an external provider for long-lived installs.

## Core Architecture

Ente Photos has four runtime responsibilities:

1. Museum provides the API on port 8080 and Prometheus metrics on port 2112.
2. The official web image serves Photos and supporting apps on separate ports.
3. PostgreSQL stores account metadata and the encryption keys needed to recover
   objects.
4. S3-compatible storage holds encrypted objects and is accessed directly by
   clients through presigned URLs.

Museum applies database migrations on startup. `GET /ping` checks PostgreSQL but
does not check S3. A successful readiness probe therefore does not prove that
uploads work.

The web image contains these applications:

| Application | Port | Included scope |
| --- | ---: | --- |
| Photos | 3000 | Enabled by default |
| Accounts | 3001 | Enabled by default |
| Albums | 3002 | Enabled by default |
| Auth | 3003 | Optional |
| Cast | 3004 | Optional |
| Share | 3005 | Optional |
| Embed | 3006 | Optional |
| Paste | 3008 | Out of Ente Photos scope |
| Locker | 3009 | Out of Ente Photos scope |
| Memories | 3010 | Optional |

## Release And Image Policy

Ente does not publish semantic releases for Museum or the web bundle.

- Museum: `ghcr.io/ente/server:0472c929b6070e61fecaf2013d47efce2dcda462`
- Web: `ghcr.io/ente/web:5ab0c5b4c7a89c4e470ef6f793600da33cebf35d`

Both official images were verified as multi-architecture manifests for
`linux/amd64` and `linux/arm64`. Museum's tag is the commit returned by Ente's
production `/ping` endpoint and is published by the monthly official workflow.
The web tag is the current commit published by the official weekly workflow.

## Required Configuration

Museum requires:

- PostgreSQL host, port, database, user, password, and SSL mode.
- Primary S3 credentials under the historically fixed `b2-eu-cen` key.
- A 32-byte base64 encryption key.
- A 64-byte base64 hash key.
- A 32-byte base64 URL-safe JWT secret.

SMTP is strongly recommended because Ente uses one-time codes for login. Without
SMTP, the code is written to Museum logs, which is unsuitable for production.

The S3 endpoint must be reachable by browsers and mobile clients. Its CORS policy
must allow Ente's origins, methods, `Content-MD5`, and `UPLOAD-URL`. Object lock
and versioning must not be enabled for Ente file-data buckets because upstream
does not handle them.

## High Availability

Cron and background cleanup run inside every Museum process. Not every job has a
database lock, so multiple cron-enabled replicas are unsafe.

The supported HA topology is:

- Two or more API replicas with `jobs.cron.skip=true`.
- One singleton worker using the same Museum image with cron enabled.
- No Service or external route for the worker.
- A `Recreate` strategy for the worker to avoid overlapping schedulers.

All instances still run migrations at startup. Rolling API updates should avoid
unnecessary startup concurrency. Ente replication remains disabled by default
because its workers start in every Museum process and require three buckets.

## Security Requirements

- Preserve generated cryptographic material across upgrades with `lookup`.
- Prefer an existing Secret or External Secrets Operator in production.
- Run Museum as a non-root user with a read-only root filesystem.
- Prepare the web files and writable nginx paths before running nginx non-root.
- Disable service account token mounts.
- Apply restrictive pod and container security contexts.
- Provide NetworkPolicy with explicit DNS, PostgreSQL, S3, SMTP, and custom
  egress extension points.
- Keep metrics and ServiceMonitor opt-in.
- Require TLS at the external Ingress or Gateway for production examples.

## Backup And Restore

A recoverable Ente backup is an inseparable set:

1. Museum configuration and cryptographic secrets.
2. PostgreSQL data.
3. S3 objects.

Objects cannot be recovered from S3 alone because their encryption metadata is
stored in PostgreSQL. Ente's multi-bucket replication is availability, not a
backup. Documentation must include a complete restore drill.

## Existing Charts Analysis

### Official chart

Ente does not maintain an official Helm chart. Its documentation references the
community `l4gdev/helm-charts` implementation.

### l4gdev/ente-photos

Strengths:

- Covers Museum and the web applications.
- Includes Ingress, NetworkPolicy, PDB, ServiceMonitor, and schema files.
- Supports external PostgreSQL.

Limitations:

- Uses floating `latest` tags from the retired `ente-io` image namespace.
- Regenerates critical cryptographic keys during renders.
- Leaves security contexts and resources effectively unset.
- Does not provide Gateway API, ESO, backup, HPA, or production restore guidance.
- Allows overly broad network ingress and cannot express private S3 egress well.
- Models some upstream configuration keys incorrectly.
- Creates a separate Deployment for every web application even though one image
  can serve all ports.

### jatinkatyal13/ente-helm

This chart is a homelab-oriented minimal deployment. It uses floating images,
hard-coded secrets and storage assumptions, and does not cover the PostgreSQL,
S3, security, observability, schema, or validation contracts required here.

## HelmForge Differentiation

| Capability | Community charts | HelmForge |
| --- | --- | --- |
| Official images | Floating or retired namespace | Current official SHA pins |
| Secret upgrades | Keys may rotate | `lookup`, existing Secret, and ESO |
| PostgreSQL | External only or ad hoc | HelmForge dependency and external mode |
| S3 contract | Basic credentials | Client reachability, CORS, TLS, validation |
| HA cron safety | Not modeled | API replicas plus singleton worker |
| Kubernetes exposure | Ingress | Ingress and Gateway API |
| Security | Mostly unset | Non-root, read-only, tokenless, NetworkPolicy |
| Observability | Partial | Metrics Service, ServiceMonitor, alerts |
| Backup | Not integrated | PostgreSQL-to-S3 job and full restore guide |
| Validation | Template-level | Unit, schema, kubeconform, and k3d behavior |

## Risks And Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| No semantic upstream server version | Upgrade tracking ambiguity | Pin the production commit and document provenance |
| S3 is not checked by `/ping` | Ready pods can still fail uploads | Validate S3 configuration and exercise S3 in k3d |
| Multiple Museum jobs | Duplicate scheduled work | Singleton worker architecture |
| Web image expects writable nginx paths | Hardened pod may fail | Init copy plus writable `emptyDir` mounts |
| Secret loss | Permanent data loss | Stable generated Secret and production secret guidance |
| Replication starts workers per process | Unexpected duplicate workers | Disable by default and document topology limits |

## Primary Sources

- <https://github.com/ente/ente/blob/main/server/RUNNING.md>
- <https://github.com/ente/ente/blob/main/server/configurations/local.yaml>
- <https://github.com/ente/ente/blob/main/web/docs/docker.md>
- <https://help.ente.io/self-hosting/installation/config>
- <https://help.ente.io/self-hosting/administration/object-storage>
- <https://help.ente.io/self-hosting/administration/backup>
- <https://github.com/ente/ente/blob/main/.github/workflows/server-publish-ghcr.yml>
- <https://github.com/ente/ente/blob/main/.github/workflows/web-publish-ghcr.yml>
