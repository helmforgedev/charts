<!-- SPDX-License-Identifier: Apache-2.0 -->

# Architecture

WebODM runs as one web Deployment and one or more Celery worker pods. They
share `/webodm/app/media`, PostgreSQL/PostGIS stores metadata, and Redis carries
Celery messages and results. A private NodeODM Deployment performs processing.

The web pod stays singleton because its upstream startup script runs database
migrations, grid synchronization, Celery Beat, cron, NGINX, and Gunicorn. The
Recreate strategy prevents overlapping schedulers during upgrades.

The processor registration hook waits for PostgreSQL, authenticated NodeODM,
and WebODM readiness before it uses `manage.py addnode`. The processor token is
sourced from a Secret and never stored in a ConfigMap. NodeODM and `addnode`
receive it as a process argument, so users with pod exec access can inspect it.

WebODM's application listener is configured by `web.containerPort`. The chart
passes it to the real upstream NGINX process as `WO_PORT` and uses the same
named port for startup, readiness, and liveness probes. NodeODM receives
`processing.containerPort` through its `--port` argument. `service.port` and
`processingService.port` are independent client-facing ports; both Services use
the named `http` target port so a listener override cannot silently break
routing.

PostgreSQL and the shared media claim form one recovery domain. Redis carries
ephemeral Celery coordination and can be reconstructed after the durable state
is restored. The processing claim retains NodeODM task files, but WebODM's
database and media remain authoritative for users, projects, and outputs.
