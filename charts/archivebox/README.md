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
- **SQLite or external PostgreSQL** - embedded SQLite by default, with optional PostgreSQL for the main index
- **Persistent storage** - archives, configuration, Personas, and local indexes on a PVC with either database backend
- **Built-in search and workers** - Sonic, capture workers, and scheduled crawls run in the application container
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
# Open http://admin.archivebox.localhost:5797/admin/
```

## Architecture Guides

- [Chart design](DESIGN.md)
- [Runtime architecture](docs/architecture.md)
- [Backup guide](docs/backup.md)
- [Upgrade and migration guide](docs/upgrading.md)

One Recreate Deployment owns the `/data` dataset and runs the web server,
capture workers, and built-in Sonic service. SQLite is the default main index;
external PostgreSQL is optional. The optional backup CronJob uploads a volume
archive to S3-compatible storage, but does not back up external PostgreSQL or
guarantee a consistent live SQLite backup. Never run two ArchiveBox instances
against the claim, even when using PostgreSQL or ReadWriteMany storage.

The chart owns Kubernetes workload, storage, routing, credentials, and optional
backup resources. TLS policy, capture-egress controls, malicious-content
isolation, storage lifecycle, off-cluster retention, and monitoring remain
platform responsibilities. See [DESIGN.md](DESIGN.md) for the Mermaid topology,
security and observability boundaries, gaps, and explicit non-goals.

## Examples

- [Minimal local installation](examples/simple.yaml)
- [Ingress with TLS](examples/ingress.yaml)
- [Scheduled S3 backup](examples/s3-backup.yaml)
- [External PostgreSQL](examples/external-postgresql.yaml)

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
| `archivebox.baseUrl` | `""` | Canonical public URL; inferred from ingress when unset |
| `archivebox.serverSecurityMode` | `auto` | Upstream replay and control-plane isolation mode |
| `archivebox.allowedHosts` | `*` | Advanced Django host restriction |
| `archivebox.publicIndex` | `True` | Public index page |
| `archivebox.publicAddPage` | `False` | Allow anonymous URL submissions |
| `archivebox.puid` / `archivebox.pgid` | `""` | Optional numeric UID/GID overrides; otherwise autodetected |
| `archivebox.searchBackendEngine` | `sonic` | Search engine (ripgrep, sqlite, sonic) |
| `archivebox.mediaMaxSize` | `750m` | Max media download size |
| `archivebox.timeout` | `60` | URL archiving timeout (seconds) |
| `externalDatabase.enabled` | `false` | Use an existing PostgreSQL server for the main index |
| `externalDatabase.existingSecret` | `""` | Secret holding the PostgreSQL password |
| `persistence.enabled` | `true` | Persist /data with either database backend |
| `persistence.size` | `50Gi` | PVC size (plan for large archives) |
| `ingress.enabled` | `false` | Enable ingress |
| `service.port` | `80` | Service port |
| `backup.enabled` | `false` | Enable scheduled S3-compatible backup |
| `backup.schedule` | `0 3 * * *` | Backup CronJob schedule |

## Public URL and Access

Set `archivebox.baseUrl` to the canonical URL users visit, such as
`https://archive.example.com`. If it is empty, the chart uses the first ingress
hostname and selects HTTPS when a matching TLS entry exists. Without ingress it
uses `http://archivebox.localhost:<archivebox.port>` for local port-forwarding.
Local `.localhost` hostnames support upstream subdomain-isolated replay; use
`admin.archivebox.localhost` for the admin UI. Set an explicit URL for another
hostname, proxy, or external port.

`BASE_URL` controls generated links, redirects, CSRF origins, and secure cookies.
Do not use `CSRF_TRUSTED_ORIGINS` as a replacement for it.

The default `archivebox.serverSecurityMode: auto` uses safer single-domain replay
without JavaScript on ordinary public hostnames. Full JavaScript replay with
isolation requires `safe-subdomains-fullreplay`, an explicit base URL, and ingress,
DNS, and TLS covering both the base hostname and its wildcard subdomains
(`admin.`, `web.`, `api.`, and `snap-*`). The chart does not create wildcard
infrastructure automatically. See the
[upstream security modes](https://github.com/ArchiveBox/ArchiveBox/blob/v0.9.77/docs/Configuration.md#server_security_mode).

`publicAddPage` maps to upstream `PUBLIC_ADD_VIEW` and defaults to `False`.
Enabling it allows anonymous visitors to submit URLs for capture. Snapshot
visibility is configured per snapshot through the ArchiveBox UI and `PERMISSIONS`;
`publicIndex` alone does not make all archived content private.

## Runtime Identity and Security

The upstream entrypoint starts as root to prepare writable paths and configure
the collection identity, then drops privileges before running ArchiveBox and
Chromium. It uses `archivebox.puid` / `archivebox.pgid` when supplied, otherwise
an existing non-root collection owner, with UID/GID 911 as the fallback for a
new root-owned data directory. No fixed 911 ownership init container is needed.

The chart drops other capabilities and retains only `CHOWN`, `DAC_OVERRIDE`,
`FOWNER`, `SETUID`, and `SETGID` for startup. Privilege escalation is disabled and
seccomp is `RuntimeDefault`. This startup model is not compatible with a strict
Pod Security Restricted policy without an operator-prepared non-root deployment.
Setting `runAsUser` bypasses entrypoint identity selection; `PUID`/`PGID` alone
cannot remap a process that already starts non-root. The selected identity also
needs writable runtime/config paths outside `/data`, including `/opt/archivebox`,
`/tmp/archivebox`, and `/home/archivebox`.

- Set explicit CPU and memory requests and limits for Chromium.
- Protect admin and database credentials with existing Secrets in production.
- Configure TLS, capture-egress policy, and namespace NetworkPolicy as needed.
- Review visibility and replay isolation before exposing the service publicly.

## Security Scan

Previous security-scan scores do not describe these changed startup settings.
Run the repository security checks against the values you intend to deploy.

## Limitations

- **Single instance only** - the chart keeps one archive/runtime owner with
  either database backend; PostgreSQL does not enable horizontal scaling
- **Storage-heavy** - each archived snapshot is commonly 2-50MB; plan PVC size
  accordingly
- **Chromium resources** - requires at least 2Gi RAM for Chromium headless
  rendering
- **`/dev/shm`** - automatically mounted as memory-backed tmpfs for Chromium

## Troubleshooting

- If startup remains incomplete, inspect application logs, verify the selected
  UID/GID can write to the data and runtime paths, and allow enough time for
  migrations on a large archive.
- If captures fail, check Chromium memory pressure, DNS and outbound network
  policy, the target site's behavior, and per-URL timeout settings.
- If links or logins use the wrong hostname or scheme, check `archivebox.baseUrl`,
  ingress TLS, proxy forwarding headers, and `archivebox.serverSecurityMode`.
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

