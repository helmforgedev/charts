# Paperless-ngx Architecture Notes

This chart packages Paperless-ngx as one application Deployment backed by Valkey
and a database, with persistent volumes for its data and documents.

## Supported Model

- one Paperless-ngx pod running the web server, task worker, scheduler, and consumer
- PostgreSQL from the bundled subchart, an external PostgreSQL, or SQLite in the data volume
- Valkey from the bundled subchart, or any external Redis-compatible broker (Valkey or Redis)
- optional Apache Tika and Gotenberg Deployments for office documents and emails
- HTTP exposed through a ClusterIP Service, optional Ingress, or optional Gateway API HTTPRoute
- optional External Secrets Operator integration for the external database password

## Replica Model

Paperless-ngx is not horizontally scalable in this layout. The scheduler and the
file consumer must run exactly once, and the data volume holds the search index
and classifier. The chart therefore accepts only `replicaCount` `0` or `1` and
uses the `Recreate` strategy so two pods never share the volumes.

## Volumes

| Volume | Mount path | Default | Content |
|--------|------------|---------|---------|
| `data` | `/usr/src/paperless/data` | PVC, 2Gi | search index, classifier, SQLite database, logs |
| `media` | `/usr/src/paperless/media` | PVC, 10Gi | original and archived documents, thumbnails |
| `consume` | `/usr/src/paperless/consume` | emptyDir | watched input folder |
| `export` | `/usr/src/paperless/export` | emptyDir | `document_exporter` output |

Each volume accepts `enabled`, `existingClaim`, `storageClass`, `accessMode`,
`size`, and `annotations`. Point `persistence.consume.existingClaim` at a
shared scanner volume to ingest scans. NFS and SMB do not deliver inotify
events, so set `paperless.consumer.pollingInterval` for those filesystems.

## Database Modes

- `auto` (default): external PostgreSQL when `database.external.host` is set,
  otherwise the PostgreSQL subchart when `postgresql.enabled=true`, otherwise SQLite
- `postgresql`: the bundled subchart
- `external`: `database.external.*`, with the password inline or in an existing Secret
- `sqlite`: no database service; the database file lives in the data volume

Advanced driver settings such as TLS or pool size go into `database.options`,
which maps to `PAPERLESS_DB_OPTIONS`.

## Office Documents And Emails

With `tika.enabled=true` and `gotenberg.enabled=true` the chart deploys both
services and sets `PAPERLESS_TIKA_ENABLED`, `PAPERLESS_TIKA_ENDPOINT`, and
`PAPERLESS_TIKA_GOTENBERG_ENDPOINT`. Gotenberg runs with JavaScript disabled
and only local files allowed, matching the upstream compose files, so tracking
pixels and scripts in emails are not fetched.

## Security

- Paperless-ngx runs as UID/GID `1000` with `runAsNonRoot`, `fsGroup`,
  `RuntimeDefault` seccomp, no privilege escalation, and all capabilities dropped
- Tika runs as `35002` and Gotenberg as `1001`, the users of the upstream images
- service account tokens are not mounted
- the root filesystem stays writable because s6-overlay writes to `/run`

## Version Pinning Note

`appVersion` and `image.tag` are `3.3.2`, verified on GitHub Releases and as
`ghcr.io/paperless-ngx/paperless-ngx:3.3.2`. Tika `3.3.1.0` and Gotenberg
`8.37.0` match the versions used in the upstream compose files for that release.

<!-- @AI-METADATA
type: chart-docs
title: Paperless-ngx - Architecture Notes
description: Architecture and deployment notes for the Paperless-ngx Helm chart

keywords: paperless-ngx, architecture, postgresql, valkey, sqlite, tika, gotenberg, volumes, consumer

purpose: Explain the supported Paperless-ngx deployment model and key architectural constraints
scope: Chart

relations:
  - charts/paperless-ngx/README.md
  - charts/paperless-ngx/DESIGN.md
path: charts/paperless-ngx/docs/architecture.md
version: 1.0
date: 2026-10-18
-->
