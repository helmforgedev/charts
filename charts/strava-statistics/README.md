# Statistics for Strava Helm Chart

Deploy [Statistics for Strava](https://github.com/robiningelbrecht/statistics-for-strava) on Kubernetes using the official
[robiningelbrecht/strava-statistics](https://hub.docker.com/r/robiningelbrecht/strava-statistics) container image.
Self-hosted fitness dashboard that visualizes your Strava activities with beautiful statistics, powered by SQLite.

## Features

- **Strava OAuth** — connects to your Strava account via OAuth credentials
- **SQLite embedded** — no external database needed
- **Persistent storage** — SQLite database and files on PVC
- **Timezone support** — configurable timezone for activity display
- **Ingress support** — TLS with cert-manager
- **Gateway API support** — optional HTTPRoute rendering for modern ingress controllers
- **External Secrets support** — optional ExternalSecret resources for Strava credentials
- **Dual-stack Service support** — optional `ipFamilyPolicy` and `ipFamilies`

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

## External Secrets

```yaml
externalSecrets:
  enabled: true
  items:
    - name: strava
      storeRef:
        name: platform-secrets
        kind: ClusterSecretStore
      targetName: strava-credentials
      data:
        - secretKey: client-id
          remoteRef:
            key: strava/oauth
            property: client-id
        - secretKey: client-secret
          remoteRef:
            key: strava/oauth
            property: client-secret
        - secretKey: refresh-token
          remoteRef:
            key: strava/oauth
            property: refresh-token

strava:
  existingSecret: strava-credentials
```

## Gateway API

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - name: web
      parentRefs:
        - name: public
          namespace: gateway-system
      hostnames:
        - strava.example.com
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.tag` | `v4.8.7` | Statistics for Strava image tag |
| `strava.port` | `8080` | Application port |
| `strava.clientId` | `""` | Strava OAuth Client ID |
| `strava.clientSecret` | `""` | Strava OAuth Client Secret |
| `strava.refreshToken` | `""` | Strava Refresh Token |
| `strava.existingSecret` | `""` | Use existing secret for credentials |
| `strava.timezone` | `UTC` | Timezone |
| `strava.config` | See `values.yaml` | Application `config.yaml` content mounted at `/var/www/config/app/config.yaml` |
| `persistence.enabled` | `true` | Enable persistence for /data |
| `persistence.size` | `2Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `service.port` | `80` | Service port |
| `service.ipFamilyPolicy` | omitted | Optional Service IP family policy for dual-stack clusters |
| `gatewayAPI.enabled` | `false` | Enable Gateway API HTTPRoute rendering |
| `gatewayApi.enabled` | `false` | Deprecated compatibility alias for `gatewayAPI.enabled` |
| `externalSecrets.enabled` | `false` | Enable ExternalSecret rendering for credential integrations |
| `externalSecrets.apiVersion` | `external-secrets.io/v1` | ExternalSecret API version |

## Limitations

- **Single instance only** — SQLite is single-writer, horizontal scaling is not supported
- **ReadWriteOnce** — PVC must be ReadWriteOnce due to SQLite limitations
- **Strava API** — requires valid Strava OAuth credentials to fetch activity data
- **OAuth callback** — `strava.config.general.appUrl` must match the public URL configured in the Strava app

## More Information

- [Statistics for Strava documentation](https://github.com/robiningelbrecht/statistics-for-strava)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/strava-statistics)

### Security Scan: `strava-statistics`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **72.72727%** |

> Security posture acceptable.

<!-- @AI-METADATA
type: chart-readme
title: Statistics for Strava Helm Chart
description: README for the Statistics for Strava fitness dashboard Helm chart

keywords: strava, fitness, statistics, dashboard, cycling, running, sqlite

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/strava-statistics/values.yaml
  - charts/strava-statistics/DESIGN.md
  - charts/strava-statistics/docs/configuration.md
path: charts/strava-statistics/README.md
version: 1.1
date: 2026-06-02
-->
