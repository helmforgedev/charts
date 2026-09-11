# Twenty

Twenty CRM with its native server and worker, a private initial workspace, PostgreSQL, authenticated Redis and retained
encryption identity.

## Operating contract

- Official `twentycrm/twenty:v2.39.0` image pinned by immutable manifest digest.
- One Recreate Pod serializes migrations and shares local files between server and worker. This chart does not claim
  application HA or horizontal scaling.
- Native first-administrator and workspace activation before public startup, followed by explicit closure of public
  workspace invite links.
- PostgreSQL and persistent noeviction Redis through HelmForge dependencies, or existing services with native TLS and
  optional private CA trust.
- UID 1000, read-only application image layers, dropped Linux capabilities, tokenless application/helper Pods and
  explicit temporary volumes.
- Native attachments backed by local storage or a private S3 bucket, with the same storage available to native
  SDK-generation jobs.
- Authenticated implicit-TLS SMTP for actual native password recovery.
- Private native server metrics, ServiceMonitor and target-availability rules. The co-located worker has separate health
  checks and job acceptance; it does not share the server's fixed Prometheus port.
- Existing credential Secrets, External Secrets Operator, Ingress with an explicit class, canonical Gateway API routes
  and dual-stack Services.

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm upgrade --install crm helmforge/twenty \
  --namespace crm --create-namespace \
  --set server.publicUrl=https://crm.example.com \
  --set bootstrap.email=owner@example.com \
  --set bootstrap.existingSecret=crm-initial-owner
```

Create that Secret in the namespace with the `user-password` key before installing. Configure HTTPS exposure and an
enforcing CNI with trusted namespace policy ownership. Set explicit NetworkPolicy peers for ingress and external
integrations. An ordinary readiness probe cannot protect first-administrator enrollment.

Use the [production example](examples/production.yaml) as a deployment-specific starting point. Hostnames, Secret
references and example network ranges require replacement. The example demonstrates external services; the default
topology uses the HelmForge PostgreSQL and Redis dependencies.

## Credentials and enrollment

Retain `ENCRYPTION_KEY` and `SERVER_ID`, the ownership marker, database, files and Redis queue state together. The
generated encryption key encodes 32 random bytes; the server identity is a UUID v4. Rotating the bootstrap password
Secret does not reset an existing native password. Native email/password changes remain native.

Existing accounts without the matching marker and incompatible retained keys are refused before migration. The chart
does not silently adopt an unrelated database or rewrite administrator privileges through SQL. See
[private enrollment](docs/onboarding.md) and [recovery](docs/retained-state.md).

## Integration boundaries

SMTP uses native port 465 because other ports would use opportunistic STARTTLS in this upstream driver. With SMTP
disabled, the chart selects a refused loopback SMTP transport instead of the upstream token-printing LOGGER driver.
Native recovery requests can still acknowledge submission without delivery. Enable SMTP and verify receipt before
relying on recovery or invitations.

S3 stores application files and generated SDK archives; it is not a backup policy or permission to scale the
application. Presigned browser-to-bucket transfer is disabled, keeping the application file proxy as the browser-facing
endpoint. Signed application download links remain temporary bearer capabilities.

The supported contract keeps native configuration environment-owned. Database configuration overrides are disabled;
workspace records and permissions remain native database state. OIDC/SSO licensing, third-party account synchronization,
AI providers and hosted function execution are outside the tested integration set.

See [dependencies](docs/dependencies.md), [storage](docs/storage.md), [SMTP](docs/smtp.md) and
[observability](docs/observability.md).

## Validation

Behavioral acceptance passed native administrator/workspace enrollment, closed
uninvited signup without a new database user, company creation, signed attachment
transfer with exact download bytes, actual SDK job completion and retained session,
identity and company after Pod replacement. An intentionally exposed native port
must cause the isolation admission check to reject startup.

The integration profiles passed actual HTTPS browser login with a Secure HttpOnly
session, external PostgreSQL and Redis TLS with negative controls, private S3 bytes,
delivered SMTP recovery with one-use tokens and preserved password changes, real
Prometheus collection and denied unauthorized scrape traffic. The production
profile verifies tokenless application, helper, PostgreSQL and Redis Pods.

Coordinated recovery restores into a fresh database and fresh application/Redis
PVCs, preserves the original session and attachment, and requires a previously
pending native job to execute and rewrite its SDK archive afterward.

Run `make validate-chart CHART=twenty` against each release candidate. The complete
gate includes all CI profiles, static checks and behavioral acceptance; individual
diagnostic profiles do not replace that gate.

## Security Scan: `twenty`

| Framework | Score      |
| --------- | ---------- |
| Overall   | **99.12%** |
| MITRE     | **99.26%** |
| NSA       | **98.54%** |
| SOC2      | **97.50%** |

Kubescape 4.0.13, default rendered manifests, 2026-09-11. No controls were suppressed. C-0012 matches the literal Bearer
authorization construction in the initializer's ConfigMap code; it does not contain a credential. C-0034 identifies the
released Redis dependency's missing Pod-level token-automount field. Redis has a dedicated account without RBAC grants
and denied egress. The production profile shares an explicitly named tokenless account with the dependencies and checks
every Pod for projected API tokens. See [dependency hardening](docs/dependencies.md). This manifest scan does not
replace application review or image vulnerability management.
