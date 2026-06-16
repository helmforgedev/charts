# ChiefOnboarding Chart Design

## Purpose

The `chiefonboarding` chart deploys ChiefOnboarding, a Django-based employee
onboarding and workflow automation application, with a PostgreSQL backend. The
chart supports the HelmForge PostgreSQL subchart for simple installations and
an external PostgreSQL service for production-managed database platforms.

## Workload Model

The chart renders one application `Deployment` and one `Service`. The
application container runs the official ChiefOnboarding image and receives its
database connection through `DATABASE_URL`.

The deployment includes a `wait-for-db` init container that blocks startup until
the configured PostgreSQL endpoint accepts TCP connections. This makes database
availability an explicit runtime dependency and keeps application startup
failures easier to diagnose.

## Database Model

Two database modes are supported:

- Bundled PostgreSQL through the HelmForge `postgresql` subchart.
- External PostgreSQL through `database.external.*`.

When the subchart is enabled, database name, username, and password come from
`postgresql.auth`. When it is disabled, the chart uses
`database.external.host`, `database.external.port`, `database.external.name`,
`database.external.username`, and either an inline password or an existing
Secret.

The app reads `DATABASE_PASSWORD` from a Secret and constructs `DATABASE_URL`
with that value reference.

## Secret Model

ChiefOnboarding requires a Django `SECRET_KEY`. The chart can create an app
Secret automatically or reference an existing Secret through
`chiefonboarding.existingSecret`.

Production installations should provide stable existing Secrets for:

- `chiefonboarding.existingSecret`
- `database.external.existingSecret` when using an external database
- `postgresql.auth.password` or the subchart password Secret workflow when using
  the bundled database

## Access Model

The Service is ClusterIP by default. Ingress is optional and supports host/path
rules and TLS. The default ingress class is `traefik`, matching the HelmForge
local validation cluster.

Set `chiefonboarding.baseUrl` to the public URL when exposing the application
through ingress. This keeps generated links and application redirects aligned
with the externally visible endpoint.

## Security Posture

The chart uses the official `chiefonboarding/chiefonboarding` image pinned by
tag. Security contexts and resources are intentionally configurable because the
upstream image and deployment environment may require operator-specific
hardening.

Recommended production hardening:

- Set explicit CPU and memory requests and limits.
- Configure `podSecurityContext` and `securityContext` according to the runtime
  policy validated for the upstream image.
- Use existing Secrets for application and database credentials.
- Restrict ingress and egress with namespace-level NetworkPolicy where the
  platform requires it.
- Enable TLS on ingress.

## Validation

The chart is validated with the HelmForge chart gate:

```bash
make validate-chart CHART=chiefonboarding
```

Security posture is tracked with Kubescape:

```bash
kubescape scan framework "MITRE,NSA,SOC2" charts/chiefonboarding
```

Latest local scan during this standards backfill:

- MITRE: 100.00%
- NSA: 67.50%
- SOC2: 90.00%
- Aggregate resource score: 78.79%
