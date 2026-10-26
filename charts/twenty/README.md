# Twenty

Twenty CRM with its native server and worker, a private initial workspace, PostgreSQL, authenticated Redis and retained
encryption identity.

## Features

- Private first-administrator enrollment with public signup closed after activation.
- Retained PostgreSQL, Redis queue state, application files and cryptographic identity.
- Optional external PostgreSQL/Redis with strict TLS, private S3, SMTP recovery and native Prometheus metrics.
- Ingress, Gateway API, External Secrets, dual-stack Services and default-deny NetworkPolicies.

## Architecture

The chart runs one application Pod containing the native Twenty server and worker so migrations, enrollment and local
file ownership remain serialized. An admission helper protects the native listener while a public proxy Service exposes
only the supported application path. PostgreSQL, Redis and file storage are stateful boundaries that must be backed up
and restored together with `ENCRYPTION_KEY`, `SERVER_ID` and the ownership marker. See [DESIGN.md](DESIGN.md) for the
topology, trust boundaries and intentional non-goals.

## Operating contract

- Official `twentycrm/twenty:v2.49.0` image pinned by immutable manifest digest.
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

## Examples

- [Production values](examples/production.yaml) demonstrates existing Secrets, external TLS dependencies, private S3,
  SMTP, metrics, ingress policy and resource settings.
- `ci/default-values.yaml` exercises the complete default dependency topology.
- `ci/external-dependencies-values.yaml` demonstrates external PostgreSQL and Redis with private CA trust.

Render an example before installation with `helm template crm helmforge/twenty -n crm -f examples/production.yaml` and
replace every example hostname, Secret reference and network range.

## Configuration

The values contract is validated by `values.schema.json`. The chart intentionally supports one application Pod because
enrollment, migrations, the native worker, and local file ownership must remain serialized. Keep credentials in existing
Secrets or External Secrets and inspect the full contract with `helm show values helmforge/twenty`.

| Parameter | Default | Purpose |
|---|---:|---|
| `replicaCount` | `1` | Fixed single-Pod application topology. |
| `image.tag` | `v2.49.0@sha256:...` | Official Twenty image pinned by release digest. |
| `server.publicUrl` | `""` | Required stable HTTPS origin used by authentication and links. |
| `bootstrap.email` | `owner@example.test` | Initial administrator email. |
| `bootstrap.workspaceName` | `HelmForge CRM` | Initial workspace display name. |
| `bootstrap.existingSecret` | `""` | Secret containing the initial administrator password. |
| `identity.existingSecret` | `""` | Existing retained `ENCRYPTION_KEY`, `SERVER_ID`, and ownership marker. |
| `service.port` | `3000` | Public proxy Service port; the native port stays private. |
| `ingress.enabled` | `false` | Render an Ingress for the public proxy. |
| `gatewayAPI.enabled` | `false` | Render canonical HTTPRoutes to an existing Gateway. |
| `persistence.enabled` | `true` | Retain local files and installation ownership. |
| `persistence.size` | `10Gi` | Application PVC capacity. |
| `persistence.retain` | `true` | Keep the application PVC after release deletion. |
| `runtime.temporarySize` | `1Gi` | Bound SDK generation and native temporary files. |
| `postgresql.enabled` | `true` | Deploy the HelmForge PostgreSQL dependency. |
| `database.host` | `""` | External PostgreSQL host when the dependency is disabled. |
| `database.tls.enabled` | `true` | Require TLS for external PostgreSQL. |
| `redis.enabled` | `true` | Deploy authenticated persistent HelmForge Redis. |
| `cache.host` | `""` | External Redis host when the dependency is disabled. |
| `cache.tls.enabled` | `true` | Require TLS for external Redis. |
| `networkPolicy.enabled` | `true` | Enforce chart-owned ingress and egress policies. |
| `networkPolicy.allowPublicHttps` | `false` | Permit public HTTPS egress only when explicitly needed. |
| `files.driver` | `local` | Store files on the PVC or select private S3. |
| `smtp.enabled` | `false` | Enable authenticated implicit-TLS mail delivery. |
| `metrics.enabled` | `false` | Enable the private native Prometheus endpoint. |
| `metrics.serviceMonitor.enabled` | `false` | Render a ServiceMonitor for an installed Prometheus Operator. |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resources for referenced credentials. |

Configuration changes that switch databases, Redis, file storage, or identity are migrations, not ordinary toggles.
Follow the linked guides and take a coordinated recovery point before changing those providers.

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

## Upgrading to 2.49.0

Twenty 2.49.0 includes minor upstream performance improvements, bug fixes and updated workspace drivers. Database
migrations run automatically on server Pod startup. No manual migration or breaking values changes are required.

Upstream release notes: [v2.49.0](https://github.com/twentyhq/twenty/releases/tag/twenty%2Fv2.49.0).

## Upgrading to 2.46.0

Twenty 2.46 includes the 2.44-2.46 native migrations and breaking API changes.
Application registration variables must be declared through manifests, record
sharing and usage-limit APIs changed, application upgrades are now queued jobs,
and `sendInboxMessage` now accepts workspace member IDs. Review the
[2.44](https://github.com/twentyhq/twenty/releases/tag/twenty%2Fv2.44.0),
[2.45](https://github.com/twentyhq/twenty/releases/tag/twenty%2Fv2.45.0) and
[2.46](https://github.com/twentyhq/twenty/releases/tag/twenty%2Fv2.46.0)
releases and take a coordinated database, files and Redis backup before
upgrading. Preserve `ENCRYPTION_KEY`, `SERVER_ID` and the ownership marker.
Startup applies native migrations; test custom applications, MCP clients,
sharing integrations and workflow agents against the new contracts first.

Private-network SSO issuers, mail and calendar hosts now require the native
`OUTBOUND_HTTP_ALLOWED_INTERNAL_HOSTS` allowlist through `extraEnv`. Use explicit
hostnames or IP literals and corresponding NetworkPolicy peers. The deprecated
`OUTBOUND_HTTP_SAFE_MODE_ENABLED=false` still overrides the allowlist and should
be removed when migrating; link-local metadata addresses remain blocked.

The bundled Redis chart updates to 3.1.0, retaining the existing
authentication and storage contract while improving dependency maintenance.
The image also fixes SMTP retry propagation, upload size enforcement, SDK job
initialization and migration-time repository updates. Ports, retained volumes,
private enrollment and the colocated native worker remain unchanged.

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

## Troubleshooting

- If enrollment refuses an existing database, verify that the retained identity Secret, ownership marker, database,
  Redis and files belong to the same installation. Do not bypass the ownership check.
- If startup probes time out, inspect server and worker logs and confirm PostgreSQL/Redis readiness before increasing
  probe budgets.
- If uploads or SDK jobs fail, verify shared file storage permissions and available `runtime.temporarySize` capacity.
- If metrics are not scraped, confirm the Prometheus Operator is installed and that its selectors match the rendered
  ServiceMonitor labels.
- If external connections fail, validate TLS hostnames, CA Secrets and the corresponding NetworkPolicy egress peers.

The operational guides under `docs/` contain provider-specific recovery and integration details.

## Security Scan: `twenty`

| Framework | Score      |
| --------- | ---------- |
| Overall   | **99.12%** |
| MITRE     | **99.26%** |
| NSA       | **98.54%** |
| SOC2      | **97.50%** |

Kubescape 4.0.14, default rendered manifests, 2026-09-15. No controls were suppressed. C-0012 matches the literal Bearer
authorization construction in the initializer's ConfigMap code; it does not contain a credential. C-0034 identifies the
released Redis dependency's missing Pod-level token-automount field. Redis has a dedicated account without RBAC grants
and denied egress. The production profile shares an explicitly named tokenless account with the dependencies and checks
every Pod for projected API tokens. See [dependency hardening](docs/dependencies.md). This manifest scan does not
replace application review or image vulnerability management.
