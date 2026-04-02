# ArchiveBox Helm Chart

Deploy [ArchiveBox](https://archivebox.io) on Kubernetes using the official [archivebox/archivebox](https://hub.docker.com/r/archivebox/archivebox) container image. Self-hosted web archiving platform that captures websites in multiple formats (HTML, PDF, PNG, WARC, media) using Chromium headless.

## Features

- **Multi-format archiving** — HTML, PDF, screenshot, WARC, media extraction
- **Chromium headless** — full page rendering with `/dev/shm` memory-backed tmpfs
- **SQLite embedded** — no external database needed
- **Persistent storage** — archived content and SQLite database on PVC
- **Admin credentials** — managed via Kubernetes Secret
- **Ingress support** — TLS with cert-manager

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
kubectl port-forward svc/<release>-archivebox 8000:80
# Open http://localhost:8000
```

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
| `archivebox.port` | `8000` | Application port |
| `archivebox.adminUsername` | `admin` | Admin username |
| `archivebox.adminPassword` | `""` | Admin password (auto-generated if empty) |
| `archivebox.allowedHosts` | `*` | Allowed hostnames |
| `archivebox.publicIndex` | `True` | Public index page |
| `archivebox.publicSnapshots` | `True` | Public snapshot access |
| `archivebox.searchBackendEngine` | `ripgrep` | Search engine (ripgrep, sqlite, sonic) |
| `archivebox.mediaMaxSize` | `750m` | Max media download size |
| `archivebox.timeout` | `60` | URL archiving timeout (seconds) |
| `persistence.enabled` | `true` | Enable persistence for /data |
| `persistence.size` | `50Gi` | PVC size (plan for large archives) |
| `ingress.enabled` | `false` | Enable ingress |
| `service.port` | `80` | Service port |

## Limitations

- **Single instance only** — SQLite is single-writer, horizontal scaling is not supported
- **Storage-heavy** — each archived snapshot is 2-50MB; plan PVC size accordingly (50-100GB+)
- **Chromium resources** — requires at least 2Gi RAM for Chromium headless rendering
- **`/dev/shm`** — automatically mounted as memory-backed tmpfs (1Gi) for Chromium

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
