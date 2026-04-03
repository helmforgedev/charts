# ChiefOnboarding Helm Chart

Deploy [ChiefOnboarding](https://chiefonboarding.com) on Kubernetes using the official [chiefonboarding/chiefonboarding](https://hub.docker.com/r/chiefonboarding/chiefonboarding) container image. Employee onboarding automation platform — automate preboarding, onboarding tasks, and new hire workflows.

## Features

- **Employee onboarding automation** — preboarding, task management, integrations
- **Django-based** — single container, stateless application
- **PostgreSQL backend** — bundled subchart or external database
- **Auto-generated secrets** — Django SECRET_KEY created automatically (50-char alphanumeric)
- **TCP health checks** — startup, liveness, and readiness probes on port 8000
- **Ingress support** — TLS with cert-manager, traefik or nginx

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install chiefonboarding helmforge/chiefonboarding -f values.yaml
```

**OCI registry:**

```bash
helm install chiefonboarding oci://ghcr.io/helmforgedev/helm/chiefonboarding -f values.yaml
```

## Basic Example

```yaml
# values.yaml — default values deploy with bundled PostgreSQL
# No configuration needed for a basic setup
```

After deploying, access ChiefOnboarding:

```bash
kubectl port-forward svc/<release>-chiefonboarding 8000:80
# Open http://localhost:8000
```

## External Database

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    name: chiefonboarding
    username: chiefonboarding
    existingSecret: chiefonboarding-db-credentials
```

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    - host: onboarding.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - onboarding.example.com
      secretName: chiefonboarding-tls
```

The `ingressClassName` defaults to `traefik` but `nginx` or any other supported ingress class can also be used.

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `chiefonboarding.port` | `8000` | Application port (Django) |
| `chiefonboarding.baseUrl` | `""` | Public base URL of the instance |
| `chiefonboarding.secretKey` | `""` | Django secret key (auto-generated) |
| `postgresql.enabled` | `true` | Deploy PostgreSQL subchart |
| `ingress.enabled` | `false` | Enable ingress |
| `service.port` | `80` | Service port |

## More Information

- [ChiefOnboarding documentation](https://docs.chiefonboarding.com)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/chiefonboarding)

<!-- @AI-METADATA
type: chart-readme
title: ChiefOnboarding Helm Chart
description: README for the ChiefOnboarding employee onboarding automation Helm chart

keywords: chiefonboarding, onboarding, hr, employee, automation, postgresql

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/chiefonboarding/values.yaml
path: charts/chiefonboarding/README.md
version: 1.0
date: 2026-04-03
-->
