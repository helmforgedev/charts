# Paperless-ngx Chart Design

This chart packages Paperless-ngx as a single application Deployment backed by
Valkey, PostgreSQL or SQLite, and persistent volumes for data and documents.
Apache Tika and Gotenberg can be deployed alongside it for office documents and
emails.

## Architecture

```text
User / scanner
  |
  +-- Ingress or Gateway API HTTPRoute
        |
        +-- Service (webserver)
              |
              +-- Deployment (1 replica, Recreate)
                    |-- Paperless-ngx: web server, task worker, scheduler, consumer
                    |-- PVC data     (/usr/src/paperless/data)
                    |-- PVC media    (/usr/src/paperless/media)
                    |-- consume      (PVC, existing claim, or emptyDir)
                    |-- export       (PVC, existing claim, or emptyDir)
                    |-- PostgreSQL subchart, external PostgreSQL, or SQLite
                    |-- Valkey subchart or external Valkey
                    +-- optional Tika and Gotenberg Deployments
```

## Design Choices

- The official image runs the web server, Celery worker, scheduler, and file
  consumer under s6-overlay in one container. The scheduler and consumer must
  run once, so `replicaCount` is limited to `0` or `1` and the default update
  strategy is `Recreate`.
- Default installs use the HelmForge PostgreSQL `2.0.5` and Valkey `2.0.4`
  subcharts. `database.mode=sqlite` keeps the upstream SQLite default for small
  installs; the database file lives in the data volume.
- The container runs rootless as UID/GID `1000` with `fsGroup`, which upstream
  supports since 3.x. Installing extra OCR languages through
  `PAPERLESS_OCR_LANGUAGES` requires root and is not exposed as a first-class
  value.
- Volumes are made writable through `fsGroup: 1000` rather than a root
  `chown` init container. Paperless-ngx logs a "not owned by current user"
  warning for its directories because the owner stays root; writes work.
- The startup probe starts after 60 seconds. Paperless-ngx spends about 40
  seconds in its s6 init before it listens, and earlier probes only create
  `Unhealthy` events.
- Probes send `Host: localhost`. Paperless-ngx always allows `localhost`,
  while the pod IP is rejected once `PAPERLESS_ALLOWED_HOSTS` is restricted.
- `PAPERLESS_URL` is derived from the first ingress host or gateway hostname
  when `paperless.url` is empty, so CSRF and allowed hosts work out of the box.
- The secret key and superuser password are generated once and reused on
  connected upgrades through `lookup`. Existing Secrets are supported for
  GitOps renderers where `lookup` is unavailable.
- Tika and Gotenberg are separate Deployments with their own component labels,
  so the web Service never selects them. They must be enabled together because
  Paperless-ngx needs both. Image tags follow the upstream compose files.
- PVCs carry `helm.sh/resource-policy: keep` so documents survive
  `helm uninstall`.
- External Secrets Operator support follows the HelmForge pattern for the
  external database password and requires `database.external.existingSecret`
  to avoid drift.

## Out of Scope

- A scheduled backup CronJob. A database dump alone does not include the
  documents in the media volume; a follow-up should run the upstream
  `document_exporter` against the export volume.
- MariaDB. Upstream supports it with caveats; PostgreSQL is recommended.
- NetworkPolicy resources.

## Security And Operations

The chart exposes pod and container security contexts, scheduling controls,
resource configuration, Secret indirection, Gateway API, Ingress, dual-stack
Service settings, and External Secrets support. `templates/NOTES.txt` shows
how to read the generated superuser password, run the sanity checker, and
export documents.

<!-- @AI-METADATA
type: chart-design
title: Paperless-ngx Chart Design
description: Architecture and design decisions for the Paperless-ngx Helm chart

keywords: paperless-ngx, design, architecture, postgresql, valkey, sqlite, tika, gotenberg, rootless

purpose: Record the deployment model and design trade-offs of the Paperless-ngx chart
scope: Chart

relations:
  - charts/paperless-ngx/README.md
  - charts/paperless-ngx/docs/architecture.md
path: charts/paperless-ngx/DESIGN.md
version: 1.0
date: 2026-10-18
-->
