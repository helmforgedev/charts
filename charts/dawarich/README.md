# Dawarich Helm Chart

Private location history with the official Dawarich image, PostGIS and
authenticated Redis. Rails, Sidekiq and the public NGINX proxy run together in a
single Recreate Pod so local attachments and watched imports have consistent
storage ownership and scheduling.

## Installation

Create an administrator password Secret through the cluster's approved secret
management workflow, then configure the stable browser-visible origin:

```yaml
server:
  publicUrl: https://locations.example.com
bootstrap:
  email: owner@example.com
  existingSecret: dawarich-administrator
  passwordKey: password
ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-body-size: 100m
  hosts:
    - host: locations.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: locations-tls
      hosts: [locations.example.com]
networkPolicy:
  ingressFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
```

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm upgrade --install dawarich helmforge/dawarich \
  --namespace locations --create-namespace --values production-values.yaml
```

The initial password requires at least 16 characters and at most 72 UTF-8 bytes.
If an existing Secret or
explicit password is omitted, the chart generates and retains an initial
credential. It does not reset an existing account when the credential changes.

## Administrator and registration policy

Initialization applies native schema and data migrations, creates the first user
through the native Rails model and its password/API-key callbacks, and only then
runs the upstream seeds. This prevents the known demo account from becoming the
initial public administrator. No HTTP server runs during model provisioning.
An existing unsafe demo credential blocks startup and requires explicit repair.

The public proxy forwards to a Rails listener bound exclusively to loopback. It
denies the unconditional native API registration routes, Apple/Google enrollment,
the OAuth web namespace and the public signup page. The chart implements a
local-account policy; enabling an OAuth environment variable does not remove these
guards.

A chart-owned initializer uses the Rails middleware extension point to reject
Devise account creation after `Rack::MethodOverride` has interpreted HTML form
methods. This preserves the distinction between registration and authenticated
PUT/PATCH/DELETE profile operations. The bootstrap also disables the native cached
registration setting. These are explicit chart adaptations, not an upstream
universal registration flag.

Native administrator user management and trusted Rails console access remain
operator responsibilities. The policy does not attempt to restrict a cluster
administrator with Pod exec access.

## Data and identity

The application PVC contains native local storage, the shared public directory,
imports and an identity fingerprint. Separate bounded emptyDirs provide temporary
files, Rails logs and NGINX scratch space. The application runs as UID/GID 1000 with
a read-only image filesystem, dropped capabilities and no Kubernetes API token.

The retained identity Secret holds `SECRET_KEY_BASE`,
`OTP_ENCRYPTION_PRIMARY_KEY`, `OTP_ENCRYPTION_DETERMINISTIC_KEY` and
`OTP_ENCRYPTION_KEY_DERIVATION_SALT`. An existing user database must match the
fingerprint on its PVC. Preserve all four keys when replacing Pods, upgrading or
restoring data. Changing them is an explicit native key-rotation operation.

Quiesce both Rails and Sidekiq before coordinating a PostGIS dump with a complete
filesystem snapshot or archive. Retain the matching identity and dependency
Secrets. PVC retention alone does not provide an off-cluster backup or prove that
a backup can be restored.

## PostGIS and Redis

The PostgreSQL subchart uses the official PostGIS 18-3.6 image, pinned by digest
and verified with PostgreSQL 18.6, and installs `postgis` and
`pgcrypto` in the application database. The verified bundled image targets amd64;
the database Pod has a matching architecture selector. An ARM application deployment
requires a separately operated, compatible PostGIS database.

Disable `postgresql.enabled` and configure `database.*` for external PostGIS.
The application role needs migration privileges and must own its application
objects; the DBA installs the required extensions first. External TLS uses libpq
`verify-full` and requires an explicit CA Secret.

Disable `redis.enabled` and configure `cache.*` independently for external Redis.
Cache and job queues require distinct logical databases. Redis Cluster is not a
drop-in replacement. Credentials are URL-encoded, including reserved characters
and IPv6 host formatting. Custom Redis CA trust augments the image's system bundle
for Ruby/OpenSSL clients; it does not disable certificate or hostname verification.
That additional trust is process-wide. Rotate trust and credentials through a
controlled restart.

Bundled Redis enables authentication, persistence and `noeviction`. Its NetworkPolicy
accepts only this release's application Pods and denies egress. External connections
need explicit `networkPolicy.extraEgress` rules for their destination addresses and
ports. Reverse-geocoding services are not configured by default.

## Exposure and health

Use Ingress or canonical `gatewayAPI.httpRoutes[]` with explicit parent references.
Controllers must support the selected HTTPS origin, upload limits and WebSocket
upgrades. The internal proxy streams responses without buffering large exports
into its temporary volume. `proxy.bodySize` bounds incoming requests.

Startup and liveness use native HTTP health. Readiness additionally executes a
fresh PostGIS query and authenticated Redis PING. Dependency outages remove
readiness without making database availability a web liveness restart condition.
Actual queued import completion is validated separately from HTTP health.

Worker readiness checks its native Sidekiq heartbeat and rejects stale or quiet
processes. `runtime.threads` sets the native Rails thread/database pool limit and
must cover `worker.concurrency`. The default single Pod deliberately keeps jobs
and local files together; this topology does not provide horizontal scaling or
zero-downtime maintenance.

## Native monitoring and object storage

Optional authenticated web and Sidekiq exporters expose two private targets. The
ServiceMonitor reads credentials from a retained or existing Secret; a
PrometheusRule detects unavailable targets. Restrict `metrics.ingressFrom` to the
monitoring namespace. Public `/metrics` remains inaccessible.

Native S3 storage supports existing credential Secrets, HTTPS endpoints and
verified custom CA trust. It retains the application PVC for shared files and
identity. S3 primary storage is independent of backup retention and recovery.

## Operational guides

- [Identity, administrator and native 2FA](docs/identity.md)
- [PostGIS and Redis dependencies](docs/dependencies.md)
- [Native Prometheus monitoring](docs/monitoring.md)
- [Storage and coordinated recovery](docs/storage-recovery.md)
- [Architecture and supported boundaries](DESIGN.md)

## Validation status

Isolated behavioral scenarios have passed native administrator login, closed
registration, browser profile forms, queued GPX imports, two-factor enrollment,
TOTP and recovery-code replay rejection, verified external PostGIS/Redis TLS,
authenticated Prometheus scraping, S3 storage and Pod replacement. Acceptance
checks original attachment bytes and retained identity keys as well as HTTP health.

Coordinated recovery into a fresh PostGIS database and PVC passed, including a
custom spatial reference, original attachment bytes, exact coordinates and native
2FA. Production acceptance also verifies tokenless dependency Pods and withdrawn
readiness for a quiet worker.

The complete `make validate-chart CHART=dawarich` gate passed on 2026-09-11:
23 validation layers, 36 Helm unit tests and 13 isolated k3d scenarios, including
all CI profiles. It covers real CRD schemas, ESO, dual-stack Services, Ingress,
Gateway API, browser interaction, private Prometheus scraping, external TLS,
coordinated recovery and original S3 object bytes. Application and dependency
Pods had no unexpected restarts or crash terminations in the accepted scenarios.

## Security Scan: `dawarich`

| Framework | Score |
| --- | --- |
| Overall | **98.53%** |
| MITRE | **98.32%** |
| NSA | **97.57%** |
| SOC2 | **94.29%** |

Kubescape 4.0.13, default rendered manifests, 2026-09-11. C-0012 flags the literal
`ALLOW_EMAIL_PASSWORD_REGISTRATION=false` policy setting and TLS admission code
that reads credential environment variables; neither contains a credential value.
No controls were suppressed.

C-0034 identifies a real default limitation in the released Redis subchart: its
Pod does not explicitly disable service-account token mounting. The production
example configures Redis to reuse the chart-created tokenless ServiceAccount.
Rails, Sidekiq and PostgreSQL already disable token mounting. The scan covers
manifests; it does not replace image vulnerability management or application review.

## Sources

- [Dawarich 1.14.4](https://github.com/Freika/dawarich/tree/1.14.4)
- [Official PostGIS image](https://github.com/postgis/docker-postgis)
- [Official unprivileged NGINX image](https://github.com/nginx/docker-nginx-unprivileged)
