# BookLore Helm Chart

A Helm chart for deploying [BookLore](https://github.com/booklore-app/booklore)
on Kubernetes. BookLore is a self-hosted, multi-user digital library with smart
shelves, automatic metadata fetching, Kobo and KOReader sync, BookDrop imports,
OPDS support, and a built-in reader for EPUB, PDF, and comics.

## Features

- Official pinned BookLore image with a configurable runtime listener.
- Bundled HelmForge MariaDB or an operator-managed external database.
- Independent persistence for application data, books, and BookDrop imports.
- Ingress, Gateway API, External Secrets, NetworkPolicy, HPA, PDB, and optional
  ServiceMonitor resources.
- Fail-fast validation for unsafe multi-replica storage and incomplete external
  database or routing contracts.

## Prerequisites

- Kubernetes 1.26+
- Helm 3.x

## Quick start

```bash
helm install booklore oci://ghcr.io/helmforgedev/helm/booklore
```

## Parameters

See [values.yaml](values.yaml) for the full list of configurable parameters.

## Architecture

BookLore runs as one Spring Boot Deployment that serves the API and bundled
web interface on `app.port`. A ClusterIP Service targets the named `http`
container port. MariaDB is bundled by default and can be replaced with an
external service. Separate storage domains preserve application data, the book
library, and the optional BookDrop import directory.

## Configuration reference

| Parameter | Default | Purpose |
|---|---:|---|
| `replicaCount` | `1` | Fixed BookLore replica count when HPA is disabled |
| `image.repository` | `ghcr.io/booklore-app/booklore` | Official image repository |
| `image.tag` | `v2.3.1` | Pinned upstream release |
| `app.port` | `6060` | BookLore HTTP listener and probe port |
| `app.allowedOrigins` | `*` | Browser origins accepted by upstream CORS |
| `app.diskType` | `LOCAL` | `LOCAL` or read-safe `NETWORK` storage mode |
| `service.port` | `6060` | Kubernetes Service-facing port |
| `persistence.data.size` | `10Gi` | Application data volume size |
| `persistence.books.size` | `50Gi` | Managed book library volume size |
| `persistence.bookdrop.enabled` | `false` | Enable the BookDrop import volume |
| `mariadb.enabled` | `true` | Deploy the bundled MariaDB dependency |
| `database.external.host` | `""` | External MariaDB host when bundled mode is off |
| `database.external.existingSecret` | `""` | Secret containing the external DB password |
| `ingress.enabled` | `false` | Render a Kubernetes Ingress |
| `gatewayAPI.enabled` | `false` | Render configured Gateway API HTTPRoutes |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resources |
| `networkPolicy.enabled` | `false` | Restrict ingress and optional egress |
| `autoscaling.enabled` | `false` | Render an HPA subject to RWX validation |
| `pdb.enabled` | `false` | Protect the supported replica during disruption |
| `monitoring.serviceMonitor.enabled` | `false` | Render an opt-in ServiceMonitor |

## Database

By default the chart deploys a MariaDB instance via the HelmForge MariaDB
subchart. To use an external database set `mariadb.enabled=false` and configure
`database.external.*`.

## Exposure

The chart supports both traditional **Ingress** and **Gateway API** for external
access. See [examples/](examples/) for ready-to-use configurations.

## Persistence

| Volume | Mount | Default | Description |
|--------|-------|---------|-------------|
| data | /app/data | 10Gi | Library data, configuration, metadata |
| books | /books | 50Gi | Library book files |
| bookdrop | /bookdrop | disabled | BookDrop import folder |

Local filesystems use `app.diskType=LOCAL`. For network-attached book storage,
set `app.diskType=NETWORK`; upstream then disables file writes and
reorganization to avoid unsafe filesystem behavior.

## Production

Production deployments should pin the public browser origin, source database
credentials from a Secret, protect all three persistent data domains, and keep
the application at one replica unless shared-storage concurrency has been
validated independently. See [docs/production.md](docs/production.md) and
[examples/production.yaml](examples/production.yaml).

## Examples

- [Simple installation](examples/simple.yaml)
- [Production installation](examples/production.yaml)
- [Ingress exposure](examples/ingress.yaml)
- [Gateway API exposure](examples/gateway-api.yaml)

## Security

- The pod does not mount a Kubernetes API token by default.
- The main container drops all capabilities except the four required by the
  upstream entrypoint to create and switch to its runtime user.
- Use existing Secrets or External Secrets for production database
  credentials; inline values remain visible in Helm release state.
- Restrict `app.allowedOrigins` to the public HTTPS origin and review outbound
  NetworkPolicy rules for MariaDB and metadata providers.

## Troubleshooting

- Slow startup: wait for Flyway migrations and inspect the BookLore and
  MariaDB logs before restarting the pod.
- Probe failures: verify `BOOKLORE_PORT` and `app.port` match, then request
  `/api/v1/healthcheck` inside the application container.
- Database failures: confirm the JDBC host, port, database, username, and
  Secret key all refer to the same MariaDB instance.
- Missing books: verify the `/books` PVC is mounted and that `app.diskType`
  matches the underlying filesystem type.
- Multi-replica validation errors: every enabled persistence volume requires
  `ReadWriteMany`; otherwise keep one replica.

## Documentation

- [Exposure](docs/exposure.md)
- [Storage](docs/storage.md)
- [Production operations](docs/production.md)
- [Examples](examples/)

## Security Scan: `booklore`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **89.90%** |

> Security posture acceptable.

## Links

- [HelmForge Documentation](https://helmforge.dev/docs/charts/booklore)
- [Upstream Source](https://github.com/booklore-app/booklore)
- [Chart Issues](https://github.com/helmforgedev/charts/issues)
