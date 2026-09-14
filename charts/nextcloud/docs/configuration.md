# Configuration and exposure

## Public URL and proxies

Set `nextcloud.trustedDomains` to the exact hostnames clients use. The chart
reconciles this list on every rollout, including existing installations. Never
use a wildcard merely to make probes pass; the probes send a configured Host.
Set `overwriteCliUrl` to the canonical HTTPS URL used in email and background
jobs. Configure `trustedProxies` with the actual ingress/gateway source addresses
and set `overwriteProtocol: https` when TLS terminates there.

Ingress supports `ingressClassName`, controller annotations, hosts/paths and TLS
Secrets. Gateway API uses `gatewayAPI.httpRoutes[]`, with a default backend to the
Nextcloud service when none is supplied. Install the chosen controller and its
CRDs separately. Configure request-size limits and timeouts for large WebDAV
uploads; the chart's PHP upload limit does not change your proxy's limit.

CalDAV/CardDAV discovery uses the native `.htaccess` rules. Route the complete
application path, preserve WebDAV methods and headers, and verify client discovery
through your actual public proxy. Do not expose the data or config directories
through an extra web server or volume-sharing sidecar.

## Database and Redis

The defaults deploy official HelmForge PostgreSQL and Redis subcharts. Their
password Secrets are referenced directly, avoiding divergent parent-generated
credentials. Use each subchart's `auth.existingSecret` contract in production.

For external PostgreSQL, set `postgresql.enabled: false` and supply all
`externalDatabase` connection and Secret fields. The account must own the target
database and have schema creation/migration rights. For external standalone Redis,
set `redis.enabled: false` and configure `externalRedis`. Sentinel and Redis
Cluster are not supported by this chart's connection contract.

Retain credential providers with your recovery procedures. The persisted native
configuration holds Nextcloud's identity, while the chart reconciles the current
database connection and native Redis snippets read their environment. Using new
database credentials during an empty-database restore does not rename Nextcloud
users or reset their account passwords.

## Background jobs and email

Cron runs in the application Pod every 300 seconds by default and selects native
cron mode. Disable it only when replacing it with a deliberately managed external
scheduler. Nextcloud's administration overview reports the last background job
execution. Inspect the `cron` container logs if that timestamp becomes stale.

SMTP supports STARTTLS or implicit TLS, an explicit sender address/domain and an
existing password Secret. Configure email before relying on account recovery or
share notifications. The SMTP server, DNS and network policy must all allow the
connection. Validate a real test email through your provider.

## Network policy

Opt-in NetworkPolicy permits same-namespace HTTP clients and database/Redis
connections, plus DNS to kube-system. Add explicit ingress peers for controllers
in other namespaces and `extraEgress` rules for external databases, SMTP,
federation, app downloads and object storage. Backup coordinator stages also need
the Kubernetes API destination on the port used by your CNI/service routing.
Rules apply to application and backup Pods. Enabling policy without these rules
can intentionally block integrations; test the actual network path.

## External Secrets

`externalSecrets.enabled` and `items[]` render canonical `external-secrets.io/v1`
resources. Each item supplies its provider spec and target name. Point the
appropriate `existingSecret` field at that target. When an item targets the default
administrator Secret name, the chart suppresses its generated Secret so only ESO
owns that target. Verify ExternalSecret readiness
before diagnosing missing application credentials.
