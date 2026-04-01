# Countly Helm Chart

Deploy [Countly](https://count.ly) on Kubernetes using the official [countly/countly-server](https://hub.docker.com/r/countly/countly-server) container image. Product analytics platform with event tracking, crash reporting, push notifications, A/B testing, and 41+ plugins.

## Features

- **MongoDB backend** — uses HelmForge MongoDB subchart or external MongoDB
- **Dual ports** — API (3001) and Dashboard (6001) on the same container
- **Plugin system** — configurable plugin list via values
- **Worker scaling** — configurable API worker count
- **Ingress support** — TLS with cert-manager

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install countly helmforge/countly -f values.yaml
```

**OCI registry:**

```bash
helm install countly oci://ghcr.io/helmforgedev/helm/countly -f values.yaml
```

## Basic Example

```yaml
# values.yaml — default values are sufficient
# Uses bundled MongoDB subchart
```

After deploying:

```bash
kubectl port-forward svc/<release>-countly 6001:80
# Open http://localhost:6001
```

## External MongoDB

```yaml
mongodb:
  enabled: false

externalMongodb:
  enabled: true
  uri: "mongodb://user:password@your-mongodb:27017/countly?authSource=admin"
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `countly.apiPort` | `3001` | API port |
| `countly.dashboardPort` | `6001` | Dashboard port |
| `countly.apiWorkers` | `4` | API worker processes |
| `countly.plugins` | `""` | Plugins to enable (comma-separated) |
| `mongodb.enabled` | `true` | Enable bundled MongoDB |
| `externalMongodb.enabled` | `false` | Use external MongoDB |
| `externalMongodb.uri` | `""` | External MongoDB URI |
| `service.port` | `80` | Dashboard service port |
| `service.apiPort` | `3001` | API service port |
| `ingress.enabled` | `false` | Enable ingress |

## Limitations

- **MongoDB only** — Countly does not support PostgreSQL or other databases
- **Single instance** — only one Countly deployment per MongoDB database

## More Information

- [Countly documentation](https://support.count.ly)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/countly)

<!-- @AI-METADATA
type: chart-readme
title: Countly Helm Chart
description: README for the Countly product analytics platform Helm chart

keywords: countly, analytics, product-analytics, event-tracking, mongodb

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/countly/values.yaml
path: charts/countly/README.md
version: 1.0
date: 2026-04-01
-->
