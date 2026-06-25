<!-- SPDX-License-Identifier: Apache-2.0 -->

# Gitea Chart Design

This chart deploys Gitea as a rootless, single-writer Git service with explicit
storage, database, HTTP, SSH, backup, and admin-bootstrap contracts. The default
profile is intentionally small: a single Gitea pod, SQLite on a persistent volume,
ClusterIP HTTP and SSH services, and restricted-compatible pod defaults.

## Goals

- Run the official `docker.io/gitea/gitea:1.26.4-rootless` image without Bitnami
  or third-party runtime substitutions.
- Keep the default install zero-config through SQLite while making PostgreSQL,
  MySQL, and external database modes explicit.
- Preserve Git HTTP and Git SSH as separate Kubernetes Services so operators can
  expose each protocol with the right network policy, ingress, or NodePort.
- Provide database-aware S3-compatible backups without coupling the chart to one
  object storage vendor.
- Keep admin bootstrap optional and secret-backed, with External Secrets support
  guarded against credential drift.

## Non-Goals

- Multi-replica write scaling with SQLite. SQLite uses a `Recreate` deployment
  strategy and should stay at one replica.
- Managing repository mirroring, runners, OAuth providers, mailers, or app.ini
  sections beyond environment-variable passthrough.
- Running privileged maintenance containers by default. PVC ownership repair is
  available only through the explicit `volumePermissions.enabled` opt-in.

## Runtime Model

The deployment mounts one data PVC in two subPaths:

- `/var/lib/gitea` for repositories, LFS objects, attachments, logs, and SQLite
  data.
- `/etc/gitea` for the rootless `app.ini` path expected by the upstream image.

The main container initializes the `GITEA_APP_INI` path if it does not exist and
then delegates to the upstream image entrypoint. Security context defaults run as
UID/GID `1000`, drop Linux capabilities, disable privilege escalation, and use
`RuntimeDefault` seccomp.

## Database Selection

`database.mode: auto` resolves in this order:

1. `database.external.host` or `database.external.existingSecret`.
2. `postgresql.enabled`.
3. `mysql.enabled`.
4. SQLite.

The helpers fail template rendering when multiple database sources are configured
or when an explicit mode is missing the matching settings. This makes the chart
fail early rather than starting Gitea with ambiguous database values.

## Network Surfaces

The chart renders one HTTP Service named `<release>-gitea-http` and, when enabled,
one SSH Service named `<release>-gitea-ssh`. Ingress and Gateway API HTTPRoute only
target the HTTP service. SSH exposure is configured separately through
`service.ssh.type`, including optional NodePort.

## Secrets

The chart can create these secrets:

- `<release>-gitea-admin` for admin bootstrap credentials.
- `<release>-gitea-database` for managed database passwords.
- `<release>-gitea-backup-s3` for S3-compatible backup credentials.
- `<release>-gitea-backup-db` for backup-specific database credentials.

Existing secrets can replace admin, external database, S3, and backup database
credentials. When `externalSecrets.enabled=true`, `admin.existingSecret` is
required so the ExternalSecret owns the target admin secret and the chart does not
create a competing secret.

## Backup Model

When `backup.enabled=true`, a CronJob runs one database-aware dump step and one S3
upload step:

- SQLite archives the mounted Gitea data directory.
- PostgreSQL uses `pg_dump`.
- MySQL uses `mysqldump`.

The upload container uses the HelmForge MinIO client image and writes to the
configured S3-compatible endpoint, bucket, and prefix. The chart does not run the
backup CronJob during Helm validation; operators should smoke-test object storage
credentials in a staging namespace before relying on production schedules.

## Validation Coverage

CI covers default SQLite, service IP family settings, PostgreSQL subchart, MySQL
subchart, SSH NodePort, backup rendering, and External Secrets rendering. The
external database example stays in `examples/` because behavioral validation needs
a real database Service, while template validation still verifies the external
database contract. Unit tests cover deployment, service, ingress, PVC, secret,
admin job, and backup CronJob templates.
