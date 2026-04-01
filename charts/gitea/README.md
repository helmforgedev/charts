# Gitea Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/helmforge)](https://artifacthub.io/packages/search?repo=helmforge)

Helm chart for deploying [Gitea](https://gitea.io/) self-hosted Git service on Kubernetes using the official [`gitea/gitea`](https://hub.docker.com/r/gitea/gitea) rootless Docker image.

## Features

- **Official rootless image** based on `gitea/gitea:<version>-rootless` (UID 1000)
- **Database backends** SQLite3 (default), PostgreSQL, or MySQL with auto-detection
- **PostgreSQL and MySQL subcharts** optional bundled database deployments
- **External database** connect to an existing PostgreSQL or MySQL instance
- **Persistent storage** repositories, LFS objects, config, and SQLite in `/var/lib/gitea`
- **HTTP + SSH services** separate services for web UI and Git SSH access
- **SSH NodePort** optional NodePort for SSH access from outside the cluster
- **Admin user creation** optional post-install Job to bootstrap an admin account
- **S3-compatible backup** database-aware CronJob (SQLite tar, pg_dump, mysqldump)
- **Ingress support** configurable ingress with TLS for HTTP access
- **Extra environment variables** any `GITEA__SECTION__KEY` for app.ini overrides

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install gitea helmforge/gitea
```

### OCI Registry

```bash
helm install gitea oci://ghcr.io/helmforgedev/helm/gitea
```

## Quick Start

Default installation uses SQLite3 with persistent storage — no external database required:

```bash
helm install gitea helmforge/gitea
```

Access the web UI at `http://<service-ip>:3000` and complete the initial setup wizard.

## Examples

### SQLite with Admin User

```yaml
gitea:
  rootUrl: https://git.example.com/
  sshDomain: git.example.com
  disableRegistration: true

admin:
  username: gitea_admin
  password: "change-me-now"
  email: admin@example.com

ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: git.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: gitea-tls
      hosts:
        - git.example.com
```

### PostgreSQL Subchart

```yaml
gitea:
  rootUrl: https://git.example.com/

postgresql:
  enabled: true
  auth:
    database: gitea
    username: gitea
    password: "db-password"

ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: git.example.com
      paths:
        - path: /
          pathType: Prefix
```

### External MySQL

```yaml
database:
  external:
    vendor: mysql
    host: mysql.database.svc
    port: 3306
    name: gitea
    username: gitea
    password: "db-password"

gitea:
  rootUrl: https://git.example.com/
```

## Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `gitea/gitea` | Container image repository |
| `image.tag` | `""` | Image tag (defaults to `appVersion-rootless`) |
| `replicaCount` | `1` | Number of replicas |
| `gitea.appName` | `"Gitea: Git with a cup of tea"` | Application display name |
| `gitea.runMode` | `prod` | Run mode (dev, prod, test) |
| `gitea.rootUrl` | `""` | Root URL for links and clone URLs |
| `gitea.sshDomain` | `""` | SSH domain in clone URLs |
| `gitea.sshPort` | `2222` | SSH listen port |
| `gitea.lfsEnabled` | `true` | Enable Git LFS |
| `gitea.disableRegistration` | `false` | Disable self-registration |
| `gitea.requireSignIn` | `false` | Require sign-in to view pages |
| `admin.username` | `""` | Admin username (triggers admin creation Job) |
| `admin.password` | `""` | Admin password |
| `admin.email` | `""` | Admin email |
| `admin.existingSecret` | `""` | Existing secret with admin credentials |
| `database.mode` | `auto` | Database mode: auto, sqlite, external, postgresql, mysql |
| `database.sqlite.file` | `/var/lib/gitea/data/gitea.db` | SQLite file path |
| `database.external.vendor` | `postgres` | External DB vendor |
| `database.external.host` | `""` | External DB host |
| `database.external.port` | `""` | External DB port |
| `database.external.name` | `gitea` | Database name |
| `database.external.username` | `gitea` | Database username |
| `database.external.existingSecret` | `""` | Existing secret for DB password |
| `postgresql.enabled` | `false` | Deploy PostgreSQL subchart |
| `mysql.enabled` | `false` | Deploy MySQL subchart |
| `persistence.enabled` | `true` | Enable persistent storage |
| `persistence.size` | `10Gi` | Volume size |
| `service.http.type` | `ClusterIP` | HTTP service type |
| `service.http.port` | `3000` | HTTP service port |
| `service.ssh.enabled` | `true` | Enable SSH service |
| `service.ssh.type` | `ClusterIP` | SSH service type |
| `service.ssh.port` | `2222` | SSH service port |
| `service.ssh.nodePort` | `""` | SSH NodePort (when type is NodePort) |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `""` | Ingress class |
| `backup.enabled` | `false` | Enable S3 backup CronJob |
| `backup.schedule` | `"0 3 * * *"` | Backup cron schedule |
| `backup.s3.endpoint` | `""` | S3-compatible endpoint URL |
| `backup.s3.bucket` | `""` | S3 bucket name |
| `backup.s3.existingSecret` | `""` | Existing secret with S3 credentials |

## Database Auto-Detection

When `database.mode` is `auto` (default), the chart detects which database to use:

1. If `database.external.host` is set → **external** database
2. If `postgresql.enabled` is `true` → **PostgreSQL subchart**
3. If `mysql.enabled` is `true` → **MySQL subchart**
4. Otherwise → **SQLite3** (zero configuration)

Only one database source can be active. The chart fails with a clear error if multiple are configured.

## SSH Access

The chart creates a separate SSH service. For external SSH access:

```yaml
service:
  ssh:
    type: NodePort
    nodePort: 30022
```

Then clone with: `git clone ssh://git@<node-ip>:30022/<user>/<repo>.git`

## Backup

The backup CronJob is database-aware:

- **SQLite**: archives the entire `/var/lib/gitea` directory
- **PostgreSQL**: runs `pg_dump` and compresses the output
- **MySQL**: runs `mysqldump` and compresses the output

All backups are uploaded to S3-compatible storage using the MinIO client.

## More Information

- [Gitea documentation](https://docs.gitea.com/)
- [Gitea Docker rootless guide](https://docs.gitea.com/installation/install-with-docker-rootless)
- [Chart source](https://github.com/helmforgedev/charts/tree/main/charts/gitea)

<!-- @AI-METADATA
type: chart-readme
title: Gitea Helm Chart
description: Self-hosted Git service with SQLite, PostgreSQL, MySQL, SSH, admin creation, and S3 backup

keywords: gitea, git, scm, self-hosted, version-control

purpose: Chart README with install, config, database, SSH, backup, and values reference
scope: Chart

relations:
  - charts/gitea/values.yaml
  - charts/gitea/docs/database-modes.md
path: charts/gitea/README.md
version: 1.0
date: 2026-03-31
-->
