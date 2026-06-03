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
| `externalDatabase.*` | — | Managed PostgreSQL (when `postgresql.enabled=false`). |
| `ingress.*` / `gatewayApi.*` | disabled | Expose the UI via Ingress or Gateway API (HTTPRoute). |
| `externalSecrets.*` | disabled | Source the app/DB secrets from an External Secrets store. |
| `backup.*` | disabled | Scheduled `pg_dump` of the analytics database. |

## Database

PostgreSQL is the single source of truth (sites, events, sessions, users). Use
the bundled subchart for small installs, or point at managed PostgreSQL via
`externalDatabase.*`. The connection is assembled as a `DATABASE_URL` with the
password injected from a secret — never templated into a ConfigMap.

> Umami also supports MySQL upstream; this chart standardizes on **PostgreSQL**.

## Access

With ingress/Gateway API disabled, port-forward the Service:

```bash
kubectl port-forward svc/<release>-umami 3000:80
# open http://localhost:3000/  (default login: admin / umami)
```

Change the default admin password immediately after first login.

## Secrets and backup

- `externalSecrets.enabled=true` sources the `APP_SECRET` and DB credentials from
  your secret store (see [external-secrets.md](external-secrets.md) if present, or
  the `externalSecrets.*` values).
- `backup.enabled=true` schedules `pg_dump` of the analytics DB — the only
  durable state — to S3-compatible storage.

## Scaling

Umami's app tier is stateless (state lives in PostgreSQL), so it can scale behind
the Service; scale PostgreSQL for data resilience.
