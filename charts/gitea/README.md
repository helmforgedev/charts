# Gitea Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/helmforge)](https://artifacthub.io/packages/search?repo=helmforge)

Helm chart for deploying [Gitea](https://gitea.io/) self-hosted Git service on Kubernetes using the official [`gitea/gitea`](https://hub.docker.com/r/gitea/gitea) rootless Docker image.

- **Current application version** `28.2.0`
- **Default image** `docker.io/gitea/gitea:28.2.0-rootless`
- **Chart lock policy** source chart does not commit `Chart.lock`; dependencies are resolved during packaging/validation
- **Rootless storage** optional initContainer can prepare PVC paths for UID/GID 1000 when required

## Features

- **Official rootless image** based on `gitea/gitea:<version>-rootless` (UID 1000)
- **Database backends** SQLite3 (default), PostgreSQL, or MySQL with auto-detection
- **PostgreSQL and MySQL subcharts** optional bundled database deployments
- **External database** connect to an existing PostgreSQL or MySQL instance
- **Persistent storage** repositories, LFS objects, config, and SQLite in `/var/lib/gitea`
- **HTTP + SSH services** separate services for web UI and Git SSH access
- **Configurable HTTP listener** application and Service ports remain independent
- **Optional NetworkPolicy** namespace-local ingress by default when enabled
- **SSH NodePort** optional NodePort for SSH access from outside the cluster
- **Admin user creation** optional post-install Job to bootstrap an admin account
- **S3-compatible backup** database-aware CronJob (SQLite tar, pg_dump, mysqldump)
- **Ingress support** configurable ingress with TLS for HTTP access
- **Extra environment variables** any `GITEA__SECTION__KEY` for app.ini overrides

## Documentation

- [Chart design](DESIGN.md)
- [Architecture](docs/architecture.md)
- [Database modes and secrets](docs/database-modes.md)
- [Operations and backup](docs/operations-and-backup.md)

## Security

The main rootless process runs as UID/GID 1000, drops all Linux capabilities,
disables privilege escalation, uses RuntimeDefault seccomp, and does not mount a
Kubernetes API token by default. The upstream entrypoint requires a writable root
filesystem during initialization, while durable data and configuration stay on
the PVC. Enable `networkPolicy.enabled` only after confirming the allowed peers
include the namespace of your ingress controller or Gateway. When admin bootstrap
is configured, its Job is allowed to reach the HTTP port independently of those
peer rules.

### Security Scan: `gitea`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **83.54978%** |

> Security posture acceptable.

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

### Custom HTTP Listener and Service Port

```yaml
containerPorts:
  http: 3100
service:
  http:
    port: 8080
```

The chart sets `GITEA__server__HTTP_PORT=3100`, exposes that container port as
`http`, and maps Service port `8080` to the named target. Changing only
`service.http.port` never changes the process listener.

## Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `gitea/gitea` | Container image repository |
| `image.tag` | `"28.2.0-rootless"` | Image tag |
| `replicaCount` | `1` | Number of replicas |
| `strategy.type` | `Recreate` | Deployment strategy for single-writer local state |
| `podAnnotations` | `{}` | Additional annotations for the Gitea pod |
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
| `volumePermissions.enabled` | `false` | Opt in to a root initContainer that prepares PVC ownership for UID/GID 1000 |
| `containerPorts.http` | `3000` | HTTP port listened on by the Gitea process |
| `service.http.type` | `ClusterIP` | HTTP service type |
| `service.http.port` | `3000` | HTTP service port |
| `service.ssh.enabled` | `true` | Enable SSH service |
| `service.ssh.type` | `ClusterIP` | SSH service type |
| `service.ssh.port` | `2222` | SSH service port |
| `service.ssh.nodePort` | `""` | SSH NodePort (when type is NodePort) |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `""` | Ingress class |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount a Kubernetes API token into chart pods |
| `networkPolicy.enabled` | `false` | Restrict HTTP and SSH ingress to configured peers |
| `networkPolicy.ingressFrom` | `[]` | Allowed ingress peers; empty means same namespace; admin bootstrap remains allowed |
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

## Upgrade Notes

The Deployment now defaults to the `Recreate` strategy for every database mode,
not only SQLite. PostgreSQL and MySQL externalize relational data, but Gitea
still keeps repositories, queues, indexes, and configuration on the local data
volume. `Recreate` prevents two Gitea processes from using that single-writer
state during an upgrade and avoids `ReadWriteOnce` multi-attach failures. Only
override `strategy.type` after externalizing every shared-state dependency and
validating the storage access mode.

This update moves the default rootless image to `28.2.0-rootless`. Back up the
database, repositories, LFS objects, packages, attachments, and the retained
configuration before upgrading; Gitea runs required database migrations during
the first startup.

Gitea 28 introduces an internal proxy for Git network operations. Existing
`ALLOWED_HOST_LIST`, `BLOCKED_HOST_LIST`, `ALLOWED_DOMAINS`, and
`BLOCKED_DOMAINS` overrides must be reviewed: wildcard and domain matching
changed, the `external` preset was removed, and an exclusive allow list now
requires `EGRESS_MODE = strict`. Configure replacements through
`gitea.extraEnv` with `GITEA__security__...` variables.

Completed Actions runs now default to 400 days of retention. Set
`GITEA__actions__RUN_RETENTION_DAYS` to `0` before the upgrade if all historical
runs must be retained. Review the [v28.0.0 migration notes](https://github.com/go-gitea/gitea/releases/tag/v28.0.0)
and the [v28.2.0 fixes](https://github.com/go-gitea/gitea/releases/tag/v28.2.0)
before production rollout. The rootless UID, ports, work directory, data path,
and `GITEA_APP_INI` contract remain compatible with this chart.

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

## Pod Security Restricted

The default install avoids root init containers so it can run in namespaces that enforce the Kubernetes `restricted`
Pod Security profile. The chart preserves the rootless Gitea config path at `/etc/gitea/app.ini` for upgrade
compatibility and mounts it from the `config` subPath on the data PVC.

The built-in `wait-for-db` init container uses the same restricted container
security context as Gitea. It runs as non-root, disables privilege escalation,
and drops all Linux capabilities by default.

Set `volumePermissions.enabled=true` only when your storage class requires an explicit root `chown` step. That opt-in
mode renders a root initContainer with `CHOWN`/`FOWNER`; keep it disabled in restricted namespaces unless your policy
explicitly allows that init container.

## Architecture

The Deployment serves both HTTP and SSH while Kubernetes exposes each protocol
through a separate Service. HTTP traffic from Ingress or Gateway API reaches the
named `http` target port; SSH can remain cluster-local or use a dedicated
NodePort. A single PVC stores repositories, LFS objects, attachments, SQLite,
and the rootless configuration. PostgreSQL and MySQL may be bundled or external.
See [DESIGN.md](DESIGN.md) and [docs/architecture.md](docs/architecture.md) for
the complete boundaries and data flow.

## Troubleshooting

If the pod does not become ready, inspect the startup probe and all containers:

```bash
kubectl describe pod -l app.kubernetes.io/name=gitea -n <namespace>
kubectl logs -l app.kubernetes.io/name=gitea -n <namespace> --all-containers --tail=100
```

For an overridden HTTP listener, confirm `GITEA__server__HTTP_PORT`, the named
container port, and Service endpoints agree. For SQL modes, inspect the
`wait-for-db` init container and verify its Secret key. See
[operations and backup](docs/operations-and-backup.md) for the full runbook.

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
