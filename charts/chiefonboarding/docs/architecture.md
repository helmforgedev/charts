# ChiefOnboarding Architecture

## Overview

ChiefOnboarding is a Django application for employee onboarding workflows. In
this chart, the application is deployed as a single stateless web workload that
depends on PostgreSQL for persistent state.

The chart renders:

- One application Deployment.
- One ClusterIP Service.
- One application Secret unless an existing Secret is provided.
- An optional Ingress.
- An optional PostgreSQL subchart.

## Runtime Startup

Before the application container starts, the `wait-for-db` init container checks
database connectivity with `nc`. It retries until the configured database host
and port are reachable.

This startup flow protects the main container from failing early because the
database is still provisioning. It also makes database connection problems
visible in init container logs.

## Application Configuration

The chart maps Helm values to environment variables:

| Value | Environment variable | Purpose |
| --- | --- | --- |
| `chiefonboarding.baseUrl` | `BASE_URL` | Public application URL |
| `chiefonboarding.secretKey` | `SECRET_KEY` | Django signing secret |
| database values | `DATABASE_URL` | PostgreSQL connection string |
| database password Secret | `DATABASE_PASSWORD` | Password injected into URL |
| `chiefonboarding.extraEnv` | custom | Advanced upstream settings |

`BASE_URL` is only emitted when `chiefonboarding.baseUrl` is set.

## Database Topologies

### Bundled PostgreSQL

The default topology deploys the HelmForge PostgreSQL subchart. This is useful
for evaluation, small installations, and environments that prefer app-owned
database lifecycle.

### External PostgreSQL

Production platforms often manage PostgreSQL separately. Disable the subchart
and configure `database.external.*` to point ChiefOnboarding at that service.

Use `database.external.existingSecret` for the database password in production.

## Ingress Topology

Ingress is disabled by default. When enabled, the chart renders rules from
`ingress.hosts` and TLS entries from `ingress.tls`.

Set these values together for internet-facing deployments:

- `chiefonboarding.baseUrl`
- `ingress.enabled`
- `ingress.hosts`
- `ingress.tls`
- `ingress.ingressClassName`

## Scaling Boundaries

The chart defaults to one application pod. The app is mostly stateless, but the
chart does not expose replica controls today. Database capacity, email delivery,
and background workflow behavior should be validated before any future
horizontal scaling support is introduced.

## Troubleshooting

Start with:

```bash
kubectl logs -n <namespace> deploy/<release>-chiefonboarding -c chiefonboarding
kubectl logs -n <namespace> deploy/<release>-chiefonboarding -c wait-for-db
kubectl get endpoints -n <namespace>
```

Common issues:

- The init container cannot reach PostgreSQL.
- `chiefonboarding.baseUrl` does not match the ingress URL.
- The Secret key name does not match `chiefonboarding.existingSecretKey`.
- External database credentials are missing or use the wrong key.
