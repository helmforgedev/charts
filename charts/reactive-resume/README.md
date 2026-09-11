# Reactive Resume Helm Chart

Reactive Resume v5 with native PDF generation, PostgreSQL, retained authentication
and encryption keys, and private initial enrollment before the public proxy starts.

Optional integration scenarios have passed behavioral acceptance individually.
The complete `make validate-chart` gate remains required before release.

## Architecture and defaults

The official image runs as UID/GID 1000 with a read-only root filesystem. One
`Recreate` Pod shares its upload PVC with the initializer and serves public traffic
through unprivileged NGINX. The application and its independent admission helper
use tokenless ServiceAccounts, resource limits and explicit NetworkPolicies.

The HelmForge PostgreSQL dependency is enabled by default. Disable it for an
existing PostgreSQL database with an explicit role password Secret and verified
TLS. Native migrations need permission to create their database-local schema;
the bundled initialization grants that permission without granting superuser or
cluster-wide `CREATEDB` privileges.

The initial account is a native ordinary user. The chart does not silently promote
it to administrator. Public signup remains disabled after private enrollment.
An enforcing CNI and trusted namespace policy ownership are installation
prerequisites: readiness alone cannot isolate the native wildcard listener.
See [onboarding](docs/onboarding.md) for the admission checks and their limits.

## Installation

```sh
helm repo add helmforge https://repo.helmforge.dev
helm upgrade --install resumes helmforge/reactive-resume \
  --namespace resumes --create-namespace -f values-production.yaml
```

Prepare the referenced Secrets and public HTTPS endpoint before installation.
See [the production example](examples/production.yaml); its hostnames are placeholders.

## Supported configuration

| Capability       | Configuration and behavior                                                       |
| ---------------- | -------------------------------------------------------------------------------- |
| PostgreSQL       | HelmForge dependency or external database; external TLS verifies CA and hostname |
| Uploads          | Local PVC or existing private S3-compatible bucket over HTTPS                    |
| Native email     | Authenticated implicit TLS SMTP with optional additional CA                      |
| Single sign-on   | Custom OAuth2 provider with explicit endpoints and linked existing accounts      |
| Exposure         | Ingress with explicit class or canonical `gatewayAPI.httpRoutes[]`               |
| Secrets          | Retained chart-managed identity Secrets, existing Secrets and ESO `items[]`      |
| Address families | Configurable public Service families; admission checks every application Pod IP  |
| Recovery         | Coordinated PostgreSQL, upload storage, identity marker and retained keys        |

For S3, the application performs authenticated bucket requests and serves public
picture URLs through its own proxy. A private bucket does not make picture URLs
private to authenticated users. See [storage](docs/storage.md).

SMTP exposes implicit TLS only. Without SMTP, mail-dependent account routes are
blocked because the native fallback writes token-bearing links to logs. See
[email configuration](docs/smtp.md). Additional integration CAs augment the native
Node process trust store and apply to all its TLS clients.

The pinned image uses Better Auth 1.7.3. The custom provider callback is
`/api/auth/callback/custom`, and native PKCE defaults to enabled. This chart's
manual OAuth2 contract does not claim OIDC ID-token validation. See
[single sign-on](docs/oauth.md).

## Operating limits

Native v5 PDF generation needs no Browserless sidecar. It fetches fallback fonts
over HTTPS even for a Latin-only resume using standard PDF fonts. The default
egress policy permits public TCP 443 with private and special ranges excluded.
Replace this with approved egress controls as needed; standard NetworkPolicy
cannot enforce CDN hostname allowlists. An offline renderer is not claimed.

One application replica serializes native migrations and owns the retained
volume. Horizontal autoscaling and highly available application replicas are
outside this contract. Kubernetes probes are health checks, not Prometheus
metrics; no fabricated ServiceMonitor endpoint is exposed.

Redis-backed AI agent queues, paid AI-provider behavior and private AI attachments
are outside the validated feature set. The retained encryption key prepares
correct identity preservation without claiming those integrations work.

## Upgrades and recovery

The image tag is paired with an immutable digest because the upstream `v5.3.0`
tag has been rebuilt beyond its Git release tag. Validate the actual replacement
image, migrations and integrations before changing that digest.

Preserve `AUTH_SECRET`, `ENCRYPTION_SECRET`, PostgreSQL and the hidden identity
marker together with uploads. Changing the bootstrap password Secret does not
reset an existing native password. The initializer refuses mismatched keys,
missing ownership markers and missing or banned initial users.

See [dependency requirements](docs/dependencies.md) and
[coordinated recovery](docs/retained-state.md). S3 backups also need a consistent
bucket recovery point; the local restore profile does not prove S3 disaster recovery.

## Validation

The initial k3d MVP proved ordinary-user login, closed signup, native private resume
CRUD, actual PDF text and retention after Pod replacement. Its admission test
deliberately exposed the native port and verified refusal before ordinary
positive-public/negative-native checks for every Pod address family.

Behavioral acceptance also exercises delivered SMTP password recovery and one-use
tokens, actual private S3 object bytes and certificate failures, external PostgreSQL
TLS, native OAuth linking after email verification, state/PKCE/replay/closed signup,
real HTTPS browser PDF download, existing Secrets/ESO and fresh database/PVC recovery.
Recovery preserves the original session, private resume, upload hash and generated PDF.
The final complete gate must pass against the release candidate; static tests alone
are not a substitute for these application checks.

## Security Scan: `reactive-resume`

| Framework | Score |
| --------- | ----- |
| Overall   | 100%  |
| NSA       | 100%  |
| MITRE     | 100%  |
| SOC2      | 100%  |

Kubescape 4.0.13, default rendered manifests, 2026-09-11. No resources failed this
configuration scan. This does not replace image vulnerability management or
application security review.
