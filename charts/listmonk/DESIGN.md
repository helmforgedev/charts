<!-- SPDX-License-Identifier: Apache-2.0 -->

# Listmonk Design

## Purpose

The Listmonk chart deploys the newsletter application with the infrastructure
pieces it needs to start safely on Kubernetes: PostgreSQL connectivity, uploads
storage, database bootstrap and upgrade init containers, HTTP Service, optional
Ingress, and optional S3-compatible database backups.

## Default Architecture

```text
Browser
   |
   | port-forward or Ingress
   v
Listmonk Service
   |
   v
Listmonk Deployment
   |
   +--> wait-for-postgresql init container
   +--> db-init init container
   +--> listmonk container on port 9000
   +--> uploads PVC mounted at /listmonk/uploads
   +--> PostgreSQL subchart or external PostgreSQL
```

Default characteristics:

- one Listmonk replica;
- bundled PostgreSQL subchart enabled;
- persistent uploads PVC enabled;
- no public ingress by default;
- SMTP configured after install through the UI or through extra environment
  variables;
- database install and upgrade commands run before the main container starts.

## Database Strategy

`database.mode=auto` selects the bundled PostgreSQL subchart unless external
database settings are present. Explicit modes fail fast when values conflict:

- `postgresql` requires `postgresql.enabled=true`;
- `external` requires external host or Secret configuration and forbids the
  bundled subchart;
- `auto` rejects ambiguous configurations where both bundled and external
  database settings are active.

The chart uses PostgreSQL Secret keys from either the subchart or an external
Secret. Inline external passwords render into a chart-managed Secret, but
production installs should prefer `database.external.existingSecret`.

## Bootstrap and Upgrade

The Listmonk container starts only after two init containers complete:

- `wait-for-postgresql` uses `pg_isready` against the configured database host,
  port, user, and database;
- `db-init` runs `./listmonk --install --idempotent --yes --config=""` and then
  `./listmonk --upgrade --yes --config=""` with the same database and app
  address environment required by the Listmonk binary.

This keeps fresh installs and upgrades deterministic while avoiding manual SQL
steps for the bundled PostgreSQL path.

## Storage Model

Uploaded media is mounted at `/listmonk/uploads`. The PVC is independent from the
PostgreSQL data volume managed by the subchart. Database backup does not back up
uploaded media; operators need a separate PVC backup or object-store strategy for
uploads.

## Backup Model

When `backup.enabled=true`, the chart renders:

- a backup script ConfigMap;
- a backup Secret when inline S3 credentials are used;
- a CronJob with a `pg_dump` init container and an upload container.

The backup path is intentionally database-only. It is useful for PostgreSQL
restore points, but it is not a complete Listmonk disaster recovery plan unless
uploads storage is backed up separately.

## Security Posture

The chart exposes resource, service account, pod security, and container security
settings without hardcoding a single platform baseline. Production values should
set resource requests and limits for Listmonk, PostgreSQL, and backup jobs, use
Secrets for credentials, and add namespace NetworkPolicies or equivalent
platform policy.

## Validation

The HelmForge gate for this chart is:

```bash
make validate-chart CHART=listmonk
```

This includes the bundled PostgreSQL path, external database templates, ingress,
unit tests, kubeconform with real schemas, Artifact Hub lint, and k3d behavioral
validation.
