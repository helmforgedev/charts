# ntfy Helm Chart

Deploy [ntfy](https://ntfy.sh) on Kubernetes using the official
[binwiederhier/ntfy](https://hub.docker.com/r/binwiederhier/ntfy) container image.
A simple HTTP-based pub-sub notification service that lets you send push notifications
to phones and desktops via scripts — no signup, no fees.

## Features

- **HTTP pub-sub** — send notifications via simple HTTP PUT/POST requests
- **Cross-platform** — native Android, iOS apps and web push support
- **Persistent storage** — SQLite cache and auth databases on PVC
- **Prometheus metrics** — opt-in `/metrics` endpoint with ServiceMonitor
- **Behind proxy** — trusts X-Forwarded-For headers by default
- **Attachment support** — configurable file size and expiry limits
- **Ingress support** — TLS with cert-manager

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install ntfy helmforge/ntfy -f values.yaml
```

**OCI registry:**

```bash
helm install ntfy oci://ghcr.io/helmforgedev/helm/ntfy -f values.yaml
```

## Basic Example

```yaml
# values.yaml
ntfy:
  baseUrl: "https://ntfy.example.com"
```

After deploying:

```bash
# Port-forward to test
kubectl port-forward svc/<release>-ntfy 8080:80

# Send a notification
curl -d "Hello from k8s!" http://localhost:8080/test

# Subscribe
curl -s http://localhost:8080/test/json
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `ntfy.baseUrl` | `""` | Public base URL of the instance |
| `ntfy.authDefaultAccess` | `"read-write"` | Default access for unauthenticated users |
| `ntfy.behindProxy` | `true` | Trust X-Forwarded-For headers |
| `ntfy.enableMetrics` | `false` | Enable Prometheus `/metrics` endpoint |
| `persistence.enabled` | `true` | Enable persistence for cache and auth |
| `persistence.size` | `2Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `service.port` | `80` | Service port |

## Authentication

ntfy supports user authentication. After deploying, create users via exec:

```bash
kubectl exec -it deploy/<release>-ntfy -- ntfy user add --role=admin admin
```

Then restrict default access:

```yaml
ntfy:
  authDefaultAccess: "deny-all"
```

## Prometheus Metrics

Enable the built-in Prometheus metrics endpoint:

```yaml
ntfy:
  enableMetrics: true

metrics:
  serviceMonitor:
    enabled: true
```

## Limitations

- **Single instance** — SQLite does not support concurrent writers
- **No clustering** — designed as a single-node service

## More Information

- [ntfy documentation](https://docs.ntfy.sh)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/ntfy)
