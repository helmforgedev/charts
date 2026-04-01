# Statistics for Strava Helm Chart

Deploy [Statistics for Strava](https://github.com/robiningelbrecht/strava-statistics) on Kubernetes using the official [robiningelbrecht/strava-statistics](https://hub.docker.com/r/robiningelbrecht/strava-statistics) container image. Self-hosted fitness dashboard that visualizes your Strava activities with beautiful statistics, powered by SQLite.

## Features

- **Strava OAuth** — connects to your Strava account via OAuth credentials
- **SQLite embedded** — no external database needed
- **Persistent storage** — SQLite database and files on PVC
- **Timezone support** — configurable timezone for activity display
- **Ingress support** — TLS with cert-manager

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install strava-statistics helmforge/strava-statistics -f values.yaml
```

**OCI registry:**

```bash
helm install strava-statistics oci://ghcr.io/helmforgedev/helm/strava-statistics -f values.yaml
```

## Basic Example

```yaml
# values.yaml
strava:
  clientId: "YOUR_STRAVA_CLIENT_ID"
  clientSecret: "YOUR_STRAVA_CLIENT_SECRET"
  refreshToken: "YOUR_STRAVA_REFRESH_TOKEN"
```

After deploying:

```bash
kubectl port-forward svc/<release>-strava-statistics 8080:80
# Open http://localhost:8080
```

## Using an Existing Secret

```yaml
strava:
  existingSecret: my-strava-secret
  existingSecretClientIdKey: client-id
  existingSecretClientSecretKey: client-secret
  existingSecretRefreshTokenKey: refresh-token
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `strava.port` | `8080` | Application port |
| `strava.clientId` | `""` | Strava OAuth Client ID |
| `strava.clientSecret` | `""` | Strava OAuth Client Secret |
| `strava.refreshToken` | `""` | Strava Refresh Token |
| `strava.existingSecret` | `""` | Use existing secret for credentials |
| `strava.timezone` | `UTC` | Timezone |
| `persistence.enabled` | `true` | Enable persistence for /data |
| `persistence.size` | `2Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `service.port` | `80` | Service port |

## Limitations

- **Single instance only** — SQLite is single-writer, horizontal scaling is not supported
- **ReadWriteOnce** — PVC must be ReadWriteOnce due to SQLite limitations
- **Strava API** — requires valid Strava OAuth credentials to fetch activity data

## More Information

- [Statistics for Strava documentation](https://github.com/robiningelbrecht/strava-statistics)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/strava-statistics)

<!-- @AI-METADATA
type: chart-readme
title: Statistics for Strava Helm Chart
description: README for the Statistics for Strava fitness dashboard Helm chart

keywords: strava, fitness, statistics, dashboard, cycling, running, sqlite

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/strava-statistics/values.yaml
path: charts/strava-statistics/README.md
version: 1.0
date: 2026-04-01
-->
