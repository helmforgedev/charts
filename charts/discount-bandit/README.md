# Discount Bandit Helm Chart

Deploy [Discount Bandit](https://github.com/Joffcom/discount-bandit) on Kubernetes using the official [joffcom/discount-bandit](https://hub.docker.com/r/joffcom/discount-bandit) container image. A self-hosted deal aggregator and price tracker for finding the best deals across multiple retailers.

## Features

- **Deal aggregation** — track prices and deals from multiple sources
- **Web UI** — browser-based interface on port 3000
- **SQLite storage** — no external database required, data persisted on PVC
- **Ingress support** — TLS with cert-manager, supports traefik and nginx

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install discount-bandit helmforge/discount-bandit -f values.yaml
```

**OCI registry:**

```bash
helm install discount-bandit oci://ghcr.io/helmforgedev/helm/discount-bandit -f values.yaml
```

## Basic Example

```yaml
# values.yaml — minimal install with defaults
persistence:
  enabled: true
  size: 5Gi
```

After deploying:

```bash
# Port-forward to access the UI
kubectl port-forward svc/<release>-discount-bandit 8080:80

# Open http://localhost:8080 in your browser
```

## Ingress Example

```yaml
ingress:
  enabled: true
  ingressClassName: traefik  # or nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    - host: deals.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - deals.example.com
      secretName: discount-bandit-tls
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `docker.io/joffcom/discount-bandit` | Container image |
| `image.tag` | `""` (appVersion) | Image tag |
| `discountBandit.extraEnv` | `[]` | Extra environment variables |
| `persistence.enabled` | `true` | Enable persistence for SQLite |
| `persistence.size` | `5Gi` | PVC size |
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `80` | Service port |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `traefik` | Ingress class (traefik, nginx) |

## Limitations

- **Single instance** — SQLite does not support concurrent writers
- **No clustering** — designed as a single-node deployment with Recreate strategy

## More Information

- [Discount Bandit source](https://github.com/Joffcom/discount-bandit)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/discount-bandit)

<!-- @AI-METADATA
type: chart-readme
path: charts/discount-bandit/README.md
date: 2026-04-03
relations:
  - charts/discount-bandit/values.yaml
  - charts/discount-bandit/Chart.yaml
-->
