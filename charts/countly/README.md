# Countly Helm Chart

Deploy [Countly](https://count.ly) on Kubernetes using the official
[countly/countly-server](https://hub.docker.com/r/countly/countly-server) container image. Countly is a product analytics
platform with event tracking, crash reporting, push notifications, A/B testing, and 41+ plugins.

This chart currently deploys `countly/countly-server:25.05.4`.

## Features

- **MongoDB backend** — uses HelmForge MongoDB subchart or external MongoDB
- **Bundled MongoDB** — uses HelmForge MongoDB `1.7.10` by default
- **Dual ports** — API (3001) and Dashboard (6001) on the same container
- **Plugin system** — configurable plugin list via values
- **Worker scaling** — configurable API worker count
- **Ingress support** — TLS with cert-manager
- **Gateway API and External Secrets** — optional HTTPRoute and secret integration
- **Dual-stack service controls** — optional `service.ipFamilyPolicy` and `service.ipFamilies`
- **S3 backups** — optional scheduled MongoDB dumps uploaded to S3-compatible storage

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

## Backup to S3

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://minio.example.internal
    bucket: countly-backups
    existingSecret: countly-backup-s3
```

## Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: shared-gateway
      namespace: gateway-system
  hostnames:
    - countly.example.com
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `docker.io/countly/countly-server` | Countly container image repository |
| `image.tag` | `25.05.4` | Countly container image tag |
| `countly.apiPort` | `3001` | API port |
| `countly.dashboardPort` | `6001` | Dashboard port |
| `countly.apiWorkers` | `4` | API worker processes |
| `countly.plugins` | `""` | Plugins to enable (comma-separated) |
| `mongodb.enabled` | `true` | Enable bundled MongoDB |
| `mongodb.auth.enabled` | `true` | Enable MongoDB authentication |
| `externalMongodb.enabled` | `false` | Use external MongoDB |
| `externalMongodb.uri` | `""` | External MongoDB URI |
| `backup.enabled` | `false` | Enable scheduled MongoDB backups |
| `backup.schedule` | `0 3 * * *` | Backup Cron schedule |
| `service.port` | `80` | Dashboard service port |
| `service.apiPort` | `3001` | API service port |
| `service.ipFamilyPolicy` | `""` | Kubernetes service IP family policy |
| `service.ipFamilies` | `[]` | Kubernetes service IP families |
| `ingress.enabled` | `false` | Enable ingress |
| `gateway.enabled` | `false` | Render a Gateway API HTTPRoute |
| `externalSecrets.enabled` | `false` | Render an ExternalSecret for MongoDB URI credentials |

## Operations

For production upgrades, take a MongoDB backup first and confirm that Countly plugins are compatible with the target version.
When using external MongoDB, prefer `externalMongodb.existingSecret` so credentials are not stored in values files.

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

keywords: countly, analytics, product-analytics, event-tracking, mongodb, gateway-api, external-secrets, backup

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/countly/values.yaml
path: charts/countly/README.md
version: 1.0
date: 2026-05-05
-->
