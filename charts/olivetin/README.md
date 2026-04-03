# OliveTin Helm Chart

Deploy [OliveTin](https://www.olivetin.app) on Kubernetes using the official [jamesread/olivetin](https://hub.docker.com/r/jamesread/olivetin) container image. OliveTin gives safe and simple access to predefined shell commands from a web interface.

## Features

- **Web UI for shell commands** — define actions in YAML, run them from the browser
- **Zero dependencies** — stateless, no database required
- **Configuration via ConfigMap** — YAML config mounted at /config/config.yaml
- **Prometheus metrics** — optional /metrics endpoint with ServiceMonitor support
- **Ingress support** — TLS with cert-manager
- **Lightweight** — minimal resource usage

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install olivetin helmforge/olivetin -f values.yaml
```

**OCI registry:**

```bash
helm install olivetin oci://ghcr.io/helmforgedev/helm/olivetin -f values.yaml
```

## Basic Example

```yaml
# values.yaml
config: |
  actions:
    - title: "Ping Google"
      shell: "ping -c 1 google.com"
    - title: "Check Disk Usage"
      shell: "df -h"
```

After deploying:

```bash
kubectl port-forward svc/<release>-olivetin 1337:80
# Open http://localhost:1337
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `olivetin.port` | `1337` | Application port |
| `config` | sample action | OliveTin YAML configuration |
| `persistence.enabled` | `false` | Enable optional PVC for data |
| `persistence.size` | `1Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `service.port` | `80` | Service port |
| `metrics.enabled` | `false` | Enable Prometheus metrics |
| `metrics.serviceMonitor.enabled` | `false` | Create ServiceMonitor |

## Prometheus Metrics

OliveTin exposes metrics at `/metrics`. To enable scraping with Prometheus Operator:

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
```

## Configuration

The `config` value is mounted as `/config/config.yaml` inside the container. See the [OliveTin documentation](https://docs.olivetin.app) for all available options.

## Ingress Example

```yaml
ingress:
  enabled: true
  ingressClassName: traefik  # or nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    - host: olivetin.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - olivetin.example.com
      secretName: olivetin-tls
```

## More Information

- [OliveTin documentation](https://docs.olivetin.app)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/olivetin)

<!-- @AI-METADATA
type: chart-readme
title: OliveTin Helm Chart
description: README for the OliveTin web interface for shell commands Helm chart

keywords: olivetin, shell, commands, automation, web-ui, self-hosted

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/olivetin/values.yaml
path: charts/olivetin/README.md
version: 1.0
date: 2026-04-03
-->
