<!-- SPDX-License-Identifier: Apache-2.0 -->

# Gitea Architecture

The Gitea chart is organized around one rootless Gitea workload and a small set of
optional companion resources. It keeps HTTP, SSH, database, backup, and bootstrap
responsibilities separate so each surface can be exposed and secured independently.

## Components

| Component | Resource | Purpose |
| --- | --- | --- |
| Gitea app | `Deployment` | Runs the upstream rootless image and serves HTTP plus Git SSH. |
| HTTP endpoint | `Service` | Exposes the web UI and Git-over-HTTP on port `3000`. |
| SSH endpoint | `Service` | Exposes Git-over-SSH on port `2222` by default. |
| Data volume | `PersistentVolumeClaim` | Stores repositories, LFS data, attachments, config, logs, and SQLite. |
| Admin bootstrap | Helm hook `Job` | Creates an admin user after install when `admin.username` is set. |
| Backup scripts | `ConfigMap` | Holds database-aware backup and upload scripts. |
| Backup schedule | `CronJob` | Creates SQLite, PostgreSQL, or MySQL backups and uploads them to S3. |
| ExternalSecret | `ExternalSecret` | Optionally reconciles admin credentials from an external store. |

## Storage Layout

The same PVC is mounted through subPaths:

| Mount | SubPath | Contents |
| --- | --- | --- |
| `/var/lib/gitea` | `data` | Repositories, LFS objects, attachments, logs, and SQLite database. |
| `/etc/gitea` | `config` | Rootless `app.ini` path used by the upstream image. |

Default persistence is enabled because repository data is stateful. Disable it
only for disposable CI or local smoke checks.

## Request Flow

HTTP requests reach `svc/<release>-gitea-http`, then the Gitea container on port
`3000`. Ingress and Gateway API HTTPRoute both route only to this service.

SSH requests reach `svc/<release>-gitea-ssh`, then the same container on the
configured SSH listen port. Use `service.ssh.type=NodePort` when clone URLs must
be reachable outside the cluster without a TCP-aware gateway.

## Database Flow

SQLite is local to the Gitea data volume. PostgreSQL and MySQL modes add a
`wait-for-db` init container so the main process starts after the configured
database endpoint accepts connections. Database passwords are passed through
Kubernetes Secrets rather than inline environment values in the pod spec.

## Security Posture

The main workload runs as UID/GID `1000`, denies privilege escalation, drops all
Linux capabilities, and uses the runtime default seccomp profile. The root
`volumePermissions` init container is disabled by default and should remain off in
namespaces enforcing the Kubernetes restricted Pod Security profile.
