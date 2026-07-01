# BookLore Helm Chart

A Helm chart for deploying [BookLore](https://github.com/booklore-app/booklore)
on Kubernetes. BookLore is a self-hosted, multi-user digital library with smart
shelves, automatic metadata fetching, Kobo and KOReader sync, BookDrop imports,
OPDS support, and a built-in reader for EPUB, PDF, and comics.

## Prerequisites

- Kubernetes 1.26+
- Helm 3.x

## Quick start

```bash
helm install booklore oci://ghcr.io/helmforgedev/helm/booklore
```

## Parameters

See [values.yaml](values.yaml) for the full list of configurable parameters.

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
| bookdrop | /bookdrop | disabled | BookDrop import folder |

## Security Scan

<!-- kubescape results placeholder -->

## Links

- [HelmForge Documentation](https://helmforge.dev/docs/charts/booklore)
- [Upstream Source](https://github.com/booklore-app/booklore)
- [Chart Issues](https://github.com/helmforgedev/charts/issues)
