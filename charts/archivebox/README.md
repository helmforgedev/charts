# ArchiveBox Helm Chart

Deploy [ArchiveBox](https://archivebox.io) on Kubernetes using the official
[archivebox/archivebox](https://hub.docker.com/r/archivebox/archivebox)
container image.

ArchiveBox is a self-hosted web archiving platform that captures websites in
multiple formats, including HTML, PDF, PNG, WARC, and media, using Chromium
headless.

## Features

- **Multi-format archiving** - HTML, PDF, screenshot, WARC, media extraction
- **Chromium headless** - full page rendering with `/dev/shm` tmpfs
- **SQLite or PostgreSQL** - embedded SQLite is the default; external PostgreSQL is also supported
- **Persistent storage** - archived content and SQLite database on PVC, can also be configured to use remote Postgres
- **Admin credentials** - managed via Kubernetes Secret
- **Ingress support** - TLS with cert-manager
- **S3-compatible backups** - optional CronJob for `/data` archives

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install archivebox helmforge/archivebox -f values.yaml
```

**OCI registry:**

```bash
helm install archivebox oci://ghcr.io/helmforgedev/helm/archivebox -f values.yaml
```

## Basic Example

```yaml
# values.yaml
archivebox:
  adminUsername: admin
  adminPassword: "your-secure-password"
```

After deploying:

```bash
kubectl port-forward svc/<release>-archivebox 5797:80
# Open http://localhost:5797/
```

## Architecture Guides

- [Chart design](DESIGN.md)
- [Runtime architecture](docs/architecture.md)
- [Backup guide](docs/backup.md)

One Recreate Deployment owns the `/data` dataset: SQLite, indexes,
configuration, and captured artifacts. The optional backup CronJob reads that
same claim and uploads a volume archive to S3-compatible storage. The chart
deploys one ArchiveBox replica.

The chart owns Kubernetes workload, storage, routing, credentials, and optional
backup resources. TLS policy, capture-egress controls, malicious-content
isolation, storage lifecycle, off-cluster retention, and monitoring remain
platform responsibilities. See [DESIGN.md](DESIGN.md) for the Mermaid topology,
security and observability boundaries, gaps, and explicit non-goals.

## Examples

- [Minimal local installation](examples/simple.yaml)
- [Ingress with TLS](examples/ingress.yaml)
- [Scheduled S3 backup](examples/s3-backup.yaml)

## Using an Existing Secret

```yaml
archivebox:
  existingSecret: my-archivebox-secret
  existingSecretUsernameKey: admin-username
  existingSecretPasswordKey: admin-password
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `archivebox.port` | `5797` | Application port |
| `archivebox.adminUsername` | `admin` | Admin username |
| `archivebox.adminPassword` | `""` | Admin password (auto-generated if empty) |
| `archivebox.allowedHosts` | `*` | Allowed hostnames |
| `archivebox.publicIndex` | `True` | Public index page |
| `archivebox.publicAddLinks` | `False` | Public URL submission view |
| `archivebox.baseUrl` | `""` | BASE_URL environment variable; empty uses configuration from the admin UI |
| `archivebox.serverSecurityMode` | `auto` | Server security mode |
| `archivebox.puid` / `archivebox.pgid` | `""` | Optional UID/GID overrides; otherwise autodetected |
| `archivebox.mediaMaxSize` | `750m` | Max media download size |
| `archivebox.timeout` | `60` | URL archiving timeout (seconds) |
| `externalDatabase.enabled` | `false` | Use external PostgreSQL |
| `externalDatabase.existingSecret` | `""` | Secret containing the PostgreSQL password |
| `persistence.enabled` | `true` | Enable persistence for /data |
| `persistence.size` | `50Gi` | PVC size (plan for large archives) |
| `ingress.enabled` | `false` | Enable ingress |
| `service.port` | `80` | Service port |
| `backup.enabled` | `false` | Enable scheduled S3-compatible backup |
| `backup.schedule` | `0 3 * * *` | Backup CronJob schedule |

## Public URL

Configure `BASE_URL` through the first-use admin UI. To set it through Helm,
set `archivebox.baseUrl` to the public URL, such as `https://archive.example.com`.
`BASE_URL` configures links, CSRF origins, and HTTPS handling.

With `archivebox.serverSecurityMode: auto`, raw archived HTML uses no-JS replay
on public hostnames. For full JavaScript replay on separate subdomains, use
`safe-subdomains-fullreplay` with wildcard DNS and ingress, plus a wildcard
certificate for HTTPS. See the [upstream security modes](https://github.com/ArchiveBox/ArchiveBox/blob/v0.9.77/docs/Configuration.md#server_security_mode).

## External PostgreSQL

SQLite is the default database. To use an existing PostgreSQL database:

```yaml
externalDatabase:
  enabled: true
  host: postgres.database.svc.cluster.local
  name: archivebox
  user: archivebox
  existingSecret: archivebox-postgres
  existingSecretPasswordKey: database-password
```

Create the database, role, and password Secret first. `/data` stores archived
files and configuration.
For existing collections, migrate SQLite records to PostgreSQL before changing
the backend.

## Upgrading

- Remove `archivebox.publicSnapshots`; manage snapshot permissions in the UI.
  If it was `"False"`, preserve private capture defaults through
  `archivebox.extraEnv` with `name: PERMISSIONS` and `value: private`.
- Review saved security contexts and remove fixed UID/GID overrides to use
  autodetection. Migrate removed keys before reusing saved values, preserving
  existing Secret and PVC references.

## Security Scan

The upstream entrypoint starts as root, prepares writable paths, then runs
ArchiveBox as non-root. It detects the existing collection owner unless
`archivebox.puid` / `archivebox.pgid` are set, falling back to 911 for a new
root-owned collection. It retains CHOWN, DAC_OVERRIDE, FOWNER, SETUID, and SETGID
for startup.

Security Scan:

Kubescape scan for `MITRE,NSA,SOC2` with the default values:

| Framework | Score |
|-----------|-------|
| MITRE | 100.00% |
| NSA | 70.00% |
| SOC2 | 80.00% |
| Aggregate resource score | 78.79% |

Expected follow-up hardening is operator-dependent:

- Set explicit CPU and memory requests and limits for the ArchiveBox workload.
- Add namespace-level NetworkPolicy where the platform requires restricted
  ingress and egress.
- Use an existing Secret for admin and S3 credentials in production.

## Limitations

- **Single instance only** - horizontal scaling is not supported, including
  with PostgreSQL
- **Storage-heavy** - each archived snapshot is commonly 2-50MB; plan PVC size
  accordingly
- **Chromium resources** - requires at least 2Gi RAM for Chromium headless
  rendering
- **`/dev/shm`** - automatically mounted as memory-backed tmpfs for Chromium

## Troubleshooting

- If startup remains incomplete, inspect application logs, confirm data and
  runtime paths are writable by the selected UID/GID, and allow enough time for
  migrations on a large archive.
- If captures fail, check Chromium memory pressure, DNS and outbound network
  policy, the target site's behavior, and per-URL timeout settings.
- If the UI rejects the public hostname, align `archivebox.baseUrl` with
  the Ingress host and TLS name.
- If backup Jobs fail, inspect both containers, verify the S3 endpoint and Secret
  keys, and test restore of the full archive before relying on retention.

## More Information

- [ArchiveBox documentation](https://docs.archivebox.io)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/archivebox)

<!-- @AI-METADATA
type: chart-readme
title: ArchiveBox Helm Chart
description: README for the ArchiveBox web archiving platform Helm chart

keywords: archivebox, archive, web-archiving, chromium, wayback, self-hosted

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/archivebox/values.yaml
path: charts/archivebox/README.md
version: 1.0
date: 2026-04-01
-->
