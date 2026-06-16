<!-- SPDX-License-Identifier: Apache-2.0 -->

# alf.io Chart Design

The alf.io chart packages the official `docker.io/alfio/alf.io` image with a
PostgreSQL backend. It is intended for event organizers that need a
self-hosted ticketing system with attendee management, check-in, invoicing, and
public ticket sales.

## Architecture

The chart deploys a single Spring Boot application `Deployment`, one HTTP
`Service`, an optional `Ingress`, a credentials `Secret`, and optional extra
manifests. PostgreSQL is provided by the HelmForge PostgreSQL subchart by
default and can be replaced by an external PostgreSQL service for production
teams that operate databases separately.

alf.io itself is stateful through PostgreSQL. The application pod does not
mount application data by default, so the durable boundary is the database. The
chart keeps the web tier single-replica because the upstream application and
session behavior are not validated here for horizontal scaling.

## Database Modes

- Bundled PostgreSQL is the default and is useful for development, demos, and
  small installations that accept chart-managed database lifecycle.
- External PostgreSQL is the production ownership model. Set
  `postgresql.enabled=false` and provide `database.external.*` values, preferably
  through `database.external.existingSecret`.
- The init container waits for the configured database endpoint before the
  application starts, which makes startup ordering deterministic in k3d and CI.

## Exposure Model

The chart exposes alf.io over HTTP through a ClusterIP Service. Ingress is
optional and should be enabled only after `alfio.baseUrl` is set to the public
URL that users will use for ticket purchase and admin access. TLS termination is
delegated to the Ingress controller and certificate automation used by the
cluster.

## Security Boundaries

- The chart uses the official upstream image and a pinned tag.
- Database credentials are rendered into a Kubernetes Secret or consumed from an
  operator-managed existing Secret.
- `serviceAccount.create` defaults to `false` because the application does not
  require Kubernetes API access.
- Resource and pod/container security contexts are intentionally user-tunable;
  production installs should set CPU/memory limits and a non-root-compatible
  security posture after validating image behavior in their environment.

## Operational Notes

Set `alfio.profiles=spring-boot` and a non-empty `alfio.baseUrl` for production.
The default `dev` profile is convenient for local validation but should not be
treated as a production posture. Use external PostgreSQL when database backup,
replication, or compliance requirements are owned outside the Helm release.

## Validation

From `helmforge-ops`, use `make validate-chart CHART=alfio` as the required
gate before a chart PR is considered ready. From the `charts` repository, use
`./test.sh alfio` as the repo-local CI parity helper. The full HelmForge gate
adds strict kubeconform, Artifact Hub lint, and k3d behavioral validation for
the default, external database, and ingress scenarios.
