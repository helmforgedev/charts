# changedetection.io Helm Chart

Deploy [changedetection.io](https://changedetection.io) on Kubernetes using the official [dgtlmoon/changedetection.io](https://github.com/dgtlmoon/changedetection.io) container image. Monitor websites for changes, get notified via email, Slack, Discord, Telegram, webhooks, and 90+ notification services.

## Features

- **Website monitoring** — detect content changes on any URL
- **90+ notification channels** — via built-in Apprise library
- **Optional JavaScript rendering** — Playwright browser sidecar for dynamic sites
- **SQLite storage** — zero external database dependencies
- **Persistent storage** — snapshots and history on PVC
- **Ingress support** — TLS with cert-manager

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install changedetection helmforge/changedetection -f values.yaml
```

**OCI registry:**

```bash
helm install changedetection oci://ghcr.io/helmforgedev/helm/changedetection -f values.yaml
```

## Basic Example

```yaml
# values.yaml — default values are sufficient for basic usage
changedetection:
  baseUrl: "https://cd.example.com"
```

After deploying:

```bash
kubectl port-forward svc/<release>-changedetection 5000:80
# Open http://localhost:5000
```

## JavaScript Rendering

Enable the Playwright browser sidecar for monitoring JavaScript-heavy sites:

```yaml
browser:
  enabled: true
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `changedetection.port` | `5000` | Application port |
| `changedetection.baseUrl` | `""` | Public base URL |
| `changedetection.fetchWorkers` | `10` | Concurrent fetch workers |
| `browser.enabled` | `false` | Enable Playwright browser sidecar |
| `persistence.enabled` | `true` | Enable persistence for /datastore |
| `persistence.size` | `10Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |

## Limitations

- **Single instance only** — SQLite does not support concurrent writers
- **Storage grows** — each snapshot consumes disk space; plan PVC size accordingly

## More Information

- [changedetection.io documentation](https://changedetection.io)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/changedetection)
