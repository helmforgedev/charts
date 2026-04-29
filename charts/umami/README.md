# Umami Helm Chart

Deploy [Umami](https://umami.is) on Kubernetes using the official
[ghcr.io/umami-software/umami](https://github.com/umami-software/umami/pkgs/container/umami) container image.
Privacy-first web analytics — no cookies, GDPR-compliant, lightweight alternative to Google Analytics.

## Features

- **Privacy-first** — no cookies, no personal data collection, GDPR/CCPA compliant
- **Lightweight** — single Node.js container, minimal resource usage
- **PostgreSQL backend** — bundled subchart or external database
- **Auto-generated secrets** — APP_SECRET created automatically
- **Custom tracker** — configurable tracker script name for ad-blocker bypass
- **Ingress support** — TLS with cert-manager

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install umami helmforge/umami -f values.yaml
```

**OCI registry:**

```bash
helm install umami oci://ghcr.io/helmforgedev/helm/umami -f values.yaml
```

## Basic Example

```yaml
# values.yaml — default values deploy with bundled PostgreSQL
# No configuration needed for a basic setup
```

After deploying, access Umami:

```bash
kubectl port-forward svc/<release>-umami 3000:80
# Open http://localhost:3000
# Default login: admin / umami
```

## External Database

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    name: umami
    username: umami
    existingSecret: umami-db-credentials
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `umami.port` | `3000` | Application port |
| `umami.appSecret` | `""` | Hash secret (auto-generated) |
| `umami.disableTelemetry` | `true` | Disable telemetry |
| `umami.trackerScriptName` | `""` | Custom tracker script name |
| `postgresql.enabled` | `true` | Deploy PostgreSQL subchart |
| `ingress.enabled` | `false` | Enable ingress |
| `service.port` | `80` | Service port |

## More Information

- [Umami documentation](https://umami.is/docs)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/umami)

<!-- @AI-METADATA
type: chart-readme
title: Umami Helm Chart
description: README for the Umami privacy-first web analytics Helm chart

keywords: umami, analytics, privacy, web-analytics, postgresql

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/umami/values.yaml
path: charts/umami/README.md
version: 1.0
date: 2026-04-01
-->
