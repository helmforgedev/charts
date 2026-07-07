# Matomo

Privacy-focused web analytics platform with MySQL and production archiving
support.

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install matomo helmforge/matomo
```

```bash
helm install matomo oci://ghcr.io/helmforgedev/helm/matomo
```

## Features

- Official Matomo Apache image pinned to `5.11.2-apache`.
- Bundled HelmForge MySQL subchart for simple deployments.
- External MySQL/MariaDB mode for production.
- CronJob-based `core:archive` execution.
- Persistent Matomo application volume.
- Ingress and Gateway API HTTPRoute support.
- NetworkPolicy, ServiceMonitor, dual-stack Service fields.
- External Secrets integration for database passwords.

## Quick Start

```yaml
matomo:
  siteUrl: http://matomo.local
mysql:
  enabled: true
```

## Production Example

```yaml
mysql:
  enabled: false
database:
  mode: external
  external:
    host: mysql.prod.svc.cluster.local
    name: matomo
    username: matomo
    existingSecret: matomo-database
matomo:
  siteUrl: https://analytics.example.com
archiver:
  enabled: true
  schedule: "5 * * * *"
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: analytics.example.com
```

## Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `replicaCount` | Matomo web replicas | `1` |
| `image.repository` | Official Matomo image repository | `docker.io/library/matomo` |
| `image.tag` | Official Matomo image tag | `5.11.2-apache` |
| `database.mode` | `auto`, `external`, or `mysql` | `auto` |
| `mysql.enabled` | Deploy HelmForge MySQL subchart | `true` |
| `persistence.enabled` | Persist `/var/www/html` | `true` |
| `archiver.enabled` | Create archive CronJob | `true` |
| `ingress.enabled` | Render Ingress | `false` |
| `gatewayAPI.enabled` | Render HTTPRoute resources | `false` |
| `externalSecrets.enabled` | Render ExternalSecret resources | `false` |
| `networkPolicy.enabled` | Render NetworkPolicy | `false` |
| `service.ipFamilyPolicy` | Service dual-stack policy | `""` |

## Examples

- [Simple](examples/simple.yaml)
- [External database](examples/external-database.yaml)
- [Production](examples/production.yaml)
- [Gateway API](examples/gateway-api.yaml)

## Architecture Guides

- [Production](docs/production.md)
- [Networking](docs/networking.md)
- [External Secrets](docs/external-secrets.md)

## Security Scan

### Security Scan: `matomo`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **84.78%** |

Security posture acceptable.

Local details:

- Tool: Kubescape v4.0.9
- Command: `kubescape scan framework mitre,nsa,soc2 .tmp/matomo-render.yaml`
- Result: 0 critical failed resources, resource summary score 84.78%.

## Research Notes

Matomo production guidance requires MySQL or MariaDB, persistent application
files, scheduled report archiving, and careful reverse proxy handling. The chart
keeps these operational concerns explicit rather than hiding them behind a
minimal deployment.

<!-- @AI-METADATA
type: chart-readme
title: Matomo Chart
description: Production-ready Matomo Helm chart
keywords: matomo, analytics, mysql, archiver
purpose: Chart usage documentation
scope: Chart
relations:
  - charts/matomo/values.yaml
path: charts/matomo/README.md
version: 1.0
date: 2026-07-06
-->
