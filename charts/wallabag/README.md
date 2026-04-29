# Wallabag Helm Chart

Deploy [Wallabag](https://wallabag.org) on Kubernetes using the official
[wallabag/wallabag](https://hub.docker.com/r/wallabag/wallabag) Docker image.
Self-hosted read-it-later application — save articles from the web, strip distractions,
read offline with mobile apps and browser extensions.

## Features

- **Save anything** — articles, web pages, RSS feeds with content extraction
- **Read offline** — mobile apps (iOS, Android) with full offline support
- **PostgreSQL backend** — bundled subchart or external database
- **Optional Redis** — subchart or external instance for cache and sessions
- **Auto-generated secrets** — Symfony secret created automatically
- **Browser extensions** — Firefox, Chrome, Opera
- **Ingress support** — TLS with cert-manager

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install wallabag helmforge/wallabag -f values.yaml
```

**OCI registry:**

```bash
helm install wallabag oci://ghcr.io/helmforgedev/helm/wallabag -f values.yaml
```

## Basic Example

```yaml
wallabag:
  domainName: "https://wallabag.example.com"
```

After deploying, access Wallabag:

```bash
kubectl port-forward svc/<release>-wallabag 8080:80
# Open http://localhost:8080
# Default login: wallabag / wallabag — change immediately
```

## With Redis

```yaml
redis:
  enabled: true
```

## External Database

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    name: wallabag
    username: wallabag
    existingSecret: wallabag-db-credentials
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `wallabag.domainName` | `https://wallabag.example.com` | Public domain (required) |
| `wallabag.secret` | `""` | Symfony secret (auto-generated) |
| `wallabag.registration` | `false` | Allow user registration |
| `postgresql.enabled` | `true` | Deploy PostgreSQL subchart |
| `redis.enabled` | `false` | Deploy Redis subchart |
| `persistence.enabled` | `true` | Enable persistence for /var/www/wallabag/data |
| `ingress.enabled` | `false` | Enable ingress |

## More Information

- [Wallabag documentation](https://doc.wallabag.org)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/wallabag)

<!-- @AI-METADATA
type: chart-readme
title: Wallabag Helm Chart
description: README for the Wallabag read-it-later Helm chart

keywords: wallabag, read-it-later, bookmarks, articles, postgresql, redis

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/wallabag/values.yaml
path: charts/wallabag/README.md
version: 1.0
date: 2026-04-01
-->
