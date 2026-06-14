# Apache Guacamole Chart Design

## Purpose

This chart deploys Apache Guacamole as a clientless remote desktop gateway for
RDP, VNC, SSH, telnet, and Kubernetes access. It packages the Guacamole web
application, the `guacd` protocol daemon, database initialization, optional
identity provider integrations, and scheduled database backups into one
production-oriented Helm release.

## Workload Model

The runtime workload is a single Deployment with two containers:

- `guacamole`: the Java/Tomcat web application that serves HTTP on port 8080.
- `guacd`: the protocol daemon that handles remote desktop protocol sessions on
  port 4822.

`guacamole` talks to `guacd` over `localhost`, keeping protocol traffic inside
the pod. The Kubernetes Service exposes only the HTTP endpoint. This avoids a
separate `guacd` Service and keeps remote desktop protocol handling private to
the application pod.

The Deployment includes an init container that waits for the configured
database endpoint before starting the application containers. HTTP startup,
liveness, and readiness probes check the web application, while TCP probes check
the `guacd` sidecar.

## Database Strategy

Apache Guacamole requires a relational database for users, connection
definitions, permissions, and authentication state. The chart supports three
database modes:

- PostgreSQL subchart, enabled by default.
- MySQL subchart, selected with `database.type: mysql`, `postgresql.enabled:
  false`, and `mysql.enabled: true`.
- External PostgreSQL or MySQL, selected by setting `database.external.host` and
  disabling the bundled database subchart.

Database connection values are resolved through helpers so the Deployment, init
job, and backup CronJob share one source of truth for host, port, database name,
username, password secret name, and password key. Inline external passwords
create a chart-managed Secret; `database.external.existingSecret` delegates
password ownership to the platform.

## Schema Initialization

When `initDb.enabled` is true, a post-install hook Job initializes the Guacamole
schema. The job waits for the database, generates the vendor-specific schema
with Guacamole's bundled `initdb.sh`, checks for the `guacamole_user` table, and
applies the schema only when it is missing.

This keeps first installs self-contained while avoiding destructive behavior on
reinstalls or external databases that already contain Guacamole data. Operators
can set `initDb.enabled: false` when database provisioning and migrations are
managed outside the chart.

## Authentication Integrations

The chart enables Guacamole authentication extensions through environment
variables consumed by the official image:

- OIDC uses authorization, JWKS, issuer, client ID, scopes, username claim, and
  groups claim settings. The redirect URI is auto-derived from the first ingress
  host when `oidc.redirectUri` is empty.
- SAML uses IdP metadata or IdP URL, entity ID, callback URL, strict mode,
  request/response compression, and group attribute settings. Entity ID and
  callback URL can also be derived from ingress.
- TOTP is enabled with `totp.enabled`.

The chart does not create identity provider objects. It expects the external IdP
to own client registration, redirect URIs, scopes, certificates, and group claim
mapping.

## Networking

The Service exposes the Guacamole web application on `service.port`. Ingress is
optional and supports `ingress.ingressClassName`, arbitrary annotations, host
paths, and TLS entries. Reverse proxy handling is enabled by default through
Tomcat RemoteIpValve settings so Guacamole can preserve client IP and protocol
information behind an ingress controller.

## Backup Strategy

When `backup.enabled` is true, the chart creates a CronJob that dumps the active
database into an `emptyDir` scratch volume and uploads the compressed archive to
an S3-compatible endpoint:

- PostgreSQL backups use `pg_dump --clean --if-exists`.
- MySQL backups use `mysqldump --single-transaction --quick`.
- Uploads use the HelmForge `mc` image and optional bucket creation.

S3 credentials can be supplied inline for chart-managed Secret creation or via
`backup.s3.existingSecret` for externally managed credentials. The backup flow
stores database state only; remote desktops and target systems remain external
to Guacamole.

## Security Posture

The chart uses official Apache Guacamole images, pinned tags, chart-managed
Secrets for generated credentials, and existing Secret hooks for platform-owned
database and S3 credentials. The default ServiceAccount is reused unless
`serviceAccount.create` is enabled, and pod/container security contexts remain
operator-configurable because upstream Guacamole and database client images may
require environment-specific hardening.

The default `guacadmin` account is created by Guacamole itself after schema
initialization. Operators must change the default password immediately after
first login or rely on OIDC/SAML controls for production access.

## Validation Coverage

The CI values cover:

- Default PostgreSQL deployment.
- MySQL deployment.
- External PostgreSQL documented example and template coverage.
- OIDC with ingress-derived callback behavior.
- SAML with ingress-derived callback behavior.
- S3 backup CronJob rendering.

Full validation for chart changes must use `make validate-chart
CHART=guacamole`.

<!-- @AI-METADATA
type: chart-design
title: Apache Guacamole Chart Design
description: Architecture and operational design for the Apache Guacamole HelmForge chart
keywords: guacamole, guacd, remote desktop, postgresql, mysql, oidc, saml, backup
purpose: Explain chart architecture, tradeoffs, and validation boundaries
scope: Chart
relations:
  - charts/guacamole/Chart.yaml
  - charts/guacamole/values.yaml
  - charts/guacamole/templates/deployment.yaml
  - charts/guacamole/templates/initdb-job.yaml
  - charts/guacamole/templates/backup-cronjob.yaml
path: charts/guacamole/DESIGN.md
version: 1.0
date: 2026-06-14
-->
