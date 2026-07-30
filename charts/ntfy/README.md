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
- **Abuse ban-feed** — opt-in weighted offender feed for fail2ban or equivalent tooling
- **Ingress support** — TLS with cert-manager
- **Dual-stack** — `ipFamilyPolicy`/`ipFamilies` on the Service for IPv4/IPv6 clusters
- **Gateway API** — opt-in `HTTPRoute` (alternative to Ingress; requires Gateway API CRDs)

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
| `ntfy.banFeed.enabled` | `false` | Append confirmed abusive visitors to a ban-feed file |
| `ntfy.banFeed.file` | `/var/cache/ntfy/ban.log` | Writable ban-feed file on the data volume |
| `persistence.enabled` | `true` | Enable persistence for cache and auth |
| `persistence.size` | `2Gi` | PVC size |
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `80` | Service port |
| `service.ipFamilyPolicy` | `~` | Dual-stack policy (`SingleStack`, `PreferDualStack`, `RequireDualStack`) |
| `service.ipFamilies` | `[]` | IP families (`IPv4`, `IPv6`) |
| `ingress.enabled` | `false` | Enable ingress |
| `gateway.enabled` | `false` | Render an `HTTPRoute` (requires Gateway API CRDs) |
| `gateway.parentRefs` | `[]` | Gateway parent refs — **required** when `gateway.enabled=true`; each entry must have `name` |
| `gateway.hostnames` | `[]` | Hostnames the `HTTPRoute` matches |

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

## Abuse Ban-Feed

ntfy 2.26.3 can append confirmed abusive visitor IPs to a weighted ban-feed for
an external fail2ban or equivalent consumer. The chart keeps this disabled by
default. When enabled, the default file is stored on the writable data volume:

```yaml
ntfy:
  banFeed:
    enabled: true
    file: /var/cache/ntfy/ban.log
    window: 10m
    threshold: 100
    weights:
      - "42909:10"
```

The chart configures the feed only; it does not install fail2ban or modify node
firewall rules. The external consumer must be able to read the file, and the
operator must rotate it with a copy-truncate strategy so it cannot grow without
bound.

## Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: envoy
      namespace: envoy-gateway
  hostnames:
    - ntfy.example.com
  path: /
  pathType: PathPrefix
```

## Dual-Stack

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

## Limitations

- **Single instance** — SQLite does not support concurrent writers
- **No clustering** — designed as a single-node service

## More Information

- [Chart design](DESIGN.md)
- [Configuration guide](docs/configuration.md)
- [ntfy documentation](https://docs.ntfy.sh)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/ntfy)

### Security Scan: `ntfy`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **72.72727%** |

> Security posture acceptable.
