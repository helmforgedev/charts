<!-- SPDX-License-Identifier: Apache-2.0 -->
# Umami — Configuration

Umami is a privacy-first, self-hosted web-analytics platform (a lightweight,
cookie-less alternative to Google Analytics). This chart runs the Umami app
(Next.js, port 3000) backed by PostgreSQL.

## Key values

| Value | Default | Purpose |
|---|---|---|
| `umami.port` | `3000` | App container port (Service exposes 80). |
| `postgresql.enabled` | `true` | Bundle the HelmForge PostgreSQL subchart. |
| `database.external.*` | — | Managed PostgreSQL (when `postgresql.enabled=false`). |
| `ingress.*` / `gatewayApi.*` | disabled | Expose the UI via Ingress or Gateway API (HTTPRoute). |
| `externalSecrets.*` | disabled | Source the app/DB secrets from an External Secrets store. |
| `backup.*` | disabled | Scheduled `pg_dump` of the analytics database. |
| `commonAnnotations` | `{}` | Annotations propagated to chart-owned resources. |

## Database

PostgreSQL is the single source of truth (sites, events, sessions, users). Use
the bundled subchart for small installs, or point at managed PostgreSQL via
`database.external.*`. The connection is assembled as a `DATABASE_URL` with the
password injected from a secret — never templated into a ConfigMap.

Set `database.external.parameters` to append connection arguments such as
`pgbouncer=true` to the generated URL. For a complete URL override, store the
URL in `database.external.existingSecret` and select its key with
`database.external.existingSecretUrlKey`. The structured host, port, and name
remain in use by readiness, initialization, and backup jobs. Backups also need
the password key selected by `database.external.existingSecretPasswordKey`, or
a backup-specific Secret configured through `backup.database.existingSecret`.

> Umami also supports MySQL upstream; this chart standardizes on **PostgreSQL**.

## Access

With ingress/Gateway API disabled, port-forward the Service:

```bash
kubectl port-forward svc/<release>-umami 3000:80
# open http://localhost:3000/  (default login: admin / umami)
```

Change the default admin password immediately after first login.

## Secrets and backup

- `externalSecrets.enabled=true` turns on External Secrets support, but each
  Secret also needs its own flag: `externalSecrets.app.enabled` (`APP_SECRET`),
  `externalSecrets.database.enabled` (external database password, with
  `postgresql.enabled=false`), and `externalSecrets.backup.enabled` (S3
  credentials). All three default to `false`; see
  [examples/external-secrets.yaml](../examples/external-secrets.yaml).
- `backup.enabled=true` schedules `pg_dump` of the analytics DB — the only
  durable state — to S3-compatible storage.
- Set `backup.s3.credentialsFromPodIdentity=true` and configure the dedicated
  `backup.serviceAccount` for EKS Pod Identity or IRSA. This mode does not
  render or inject static S3 access keys. Supply `backup.s3.region`, allow DNS,
  HTTPS, and the applicable metadata endpoint, and grant only object access;
  bucket creation remains opt-in. EKS Pod Identity requires an association
  between the IAM role, release namespace, and backup ServiceAccount; it does
  not use a ServiceAccount annotation. Use `backup.serviceAccount.annotations`
  only for IRSA or another annotation-based integration.

## Custom initialization

The built-in database readiness check is enabled by default. Mirror or replace
its image when public-registry access is restricted, or disable it when
database readiness is enforced elsewhere:

```yaml
initContainers:
  waitForDatabase:
    enabled: true
    image: registry.example.com/platform/busybox:1.37
    pullPolicy: IfNotPresent
```

Use `extraInitContainers` with `extraVolumes` and `extraVolumeMounts` when Umami
needs files prepared before the application starts, such as a GeoIP database,
custom tracker assets, or organization-owned configuration mounted from a
shared volume:

```yaml
extraVolumes:
  - name: geoip
    emptyDir: {}

extraInitContainers:
  - name: download-geoip
    image: docker.io/library/busybox:1.37
    command: ["sh", "-ec"]
    args:
      - wget -O /geoip/GeoLite2-City.mmdb https://example.com/GeoLite2-City.mmdb
    volumeMounts:
      - name: geoip
        mountPath: /geoip

extraVolumeMounts:
  - name: geoip
    mountPath: /app/geoip
```

The chart renders custom init containers after the enabled internal init
containers. Keep external downloads pinned to trusted URLs or use an internal
artifact mirror for reproducible installs.

## Scaling

Umami's app tier is stateless (state lives in PostgreSQL), so it can scale behind
the Service; scale PostgreSQL for data resilience.
