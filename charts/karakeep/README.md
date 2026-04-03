# Karakeep Helm Chart

Deploy [Karakeep](https://karakeep.app) (formerly Hoarder) on Kubernetes using the official [karakeep-app/karakeep](https://github.com/karakeep-app/karakeep) container image. An AI-powered bookmark manager with full-text search, web archiving, and automatic tagging.

## Features

- **AI-powered tagging** — automatic categorization of bookmarks using AI
- **Full-text search** — optional Meilisearch sidecar for fast search across all bookmarks
- **Web archiving** — optional Chromium sidecar for page screenshots and content preservation
- **SQLite storage** — no external database required, data stored on PVC
- **Auto-generated secrets** — NEXTAUTH_SECRET and MEILI_MASTER_KEY are generated automatically and preserved across upgrades
- **Ingress support** — TLS with cert-manager, supports traefik and nginx

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install karakeep helmforge/karakeep -f values.yaml
```

**OCI registry:**

```bash
helm install karakeep oci://ghcr.io/helmforgedev/helm/karakeep -f values.yaml
```

## Basic Example

```yaml
# values.yaml
karakeep:
  nextAuthUrl: "https://karakeep.example.com"
```

After deploying:

```bash
# Port-forward to test
kubectl port-forward svc/<release>-karakeep 8080:80

# Access the web UI at http://localhost:8080
```

## Sidecars

### Meilisearch (Full-Text Search)

Enabled by default. Provides fast full-text search across all bookmarks.

```yaml
meilisearch:
  enabled: true  # default
  image:
    repository: docker.io/getmeili/meilisearch
    tag: "v1.13.3"
  resources:
    requests:
      memory: 256Mi
```

To disable:

```yaml
meilisearch:
  enabled: false
```

### Chromium (Screenshots)

Enabled by default. Takes screenshots and archives web pages.

```yaml
chromium:
  enabled: true  # default
  image:
    repository: ghcr.io/browserless/chromium
    tag: "v2.18.0"
  resources:
    requests:
      memory: 512Mi
```

To disable:

```yaml
chromium:
  enabled: false
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `karakeep.nextAuthUrl` | `""` | Public URL of the Karakeep instance |
| `meilisearch.enabled` | `true` | Enable Meilisearch sidecar for full-text search |
| `chromium.enabled` | `true` | Enable Chromium sidecar for web page screenshots |
| `persistence.enabled` | `true` | Enable persistence for application data |
| `persistence.size` | `10Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `traefik` | Ingress class (traefik, nginx, etc.) |
| `service.port` | `80` | Service port |

## Ingress Example

```yaml
karakeep:
  nextAuthUrl: "https://karakeep.example.com"

ingress:
  enabled: true
  ingressClassName: traefik  # or nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    - host: karakeep.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - karakeep.example.com
      secretName: karakeep-tls
```

## Persistence

SQLite database and uploaded content are stored under `/data`. A PVC is created by default.

To use an existing PVC:

```yaml
persistence:
  existingClaim: my-karakeep-pvc
```

## Limitations

- **Single instance** — SQLite does not support concurrent writers
- **No clustering** — designed as a single-node deployment

## More Information

- [Karakeep documentation](https://docs.karakeep.app)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/karakeep)

<!-- @AI-METADATA
type: chart-readme
path: charts/karakeep/README.md
date: 2026-04-03
relations:
  - charts/karakeep/values.yaml
  - charts/karakeep/Chart.yaml
-->
