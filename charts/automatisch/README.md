# Automatisch Helm Chart

Deploy [Automatisch](https://automatisch.io) on Kubernetes using the official [automatischio/automatisch](https://hub.docker.com/r/automatischio/automatisch) container image. Open-source business automation platform — self-hosted Zapier alternative with visual workflow builder, PostgreSQL, and Redis.

## Features

- **Visual workflow builder** — connect apps and automate tasks without code
- **Self-hosted** — full control over your data and integrations
- **PostgreSQL backend** — bundled subchart or external database
- **Redis cache** — bundled subchart or external Redis
- **Auto-generated secrets** — ENCRYPTION_KEY and APP_SECRET_KEY created automatically and preserved across upgrades
- **Ingress support** — TLS with cert-manager, traefik or nginx

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install automatisch helmforge/automatisch -f values.yaml
```

**OCI registry:**

```bash
helm install automatisch oci://ghcr.io/helmforgedev/helm/automatisch -f values.yaml
```

## Basic Example

```yaml
# values.yaml — default values deploy with bundled PostgreSQL and Redis
automatisch:
  webAppUrl: "https://automatisch.example.com"
```

After deploying, access Automatisch:

```bash
kubectl port-forward svc/<release>-automatisch 3000:80
# Open http://localhost:3000
```

## External Database and Redis

```yaml
postgresql:
  enabled: false

redis:
  enabled: false

database:
  external:
    host: postgres.example.com
    name: automatisch
    username: automatisch
    existingSecret: automatisch-db-credentials

redis_config:
  external:
    host: redis.example.com
    port: "6379"
```

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik  # or nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    - host: automatisch.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - automatisch.example.com
      secretName: automatisch-tls
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `automatisch.webAppUrl` | `http://localhost:3000` | Public URL of the web application |
| `automatisch.appEnv` | `production` | Application environment |
| `automatisch.extraEnv` | `[]` | Extra environment variables |
| `postgresql.enabled` | `true` | Deploy PostgreSQL subchart |
| `redis.enabled` | `true` | Deploy Redis subchart |
| `database.external.host` | `""` | External PostgreSQL host |
| `redis_config.external.host` | `""` | External Redis host |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `traefik` | Ingress class (traefik, nginx) |
| `service.port` | `80` | Service port |

## More Information

- [Automatisch documentation](https://automatisch.io/docs)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/automatisch)

<!-- @AI-METADATA
type: chart-readme
title: Automatisch Helm Chart
description: README for the Automatisch open-source business automation Helm chart

keywords: automatisch, automation, workflow, zapier, postgresql, redis

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/automatisch/values.yaml
path: charts/automatisch/README.md
version: 1.0
date: 2026-04-03
-->
