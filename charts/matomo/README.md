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

- Official Matomo Apache image pinned to `5.14.0-apache`.
- Bundled HelmForge MySQL subchart for simple deployments.
- External MySQL/MariaDB mode for production.
- CronJob-based `core:archive` execution.
- Persistent Matomo application volume.
- Automatic synchronization of image code into the persistent application volume.
- Ingress and Gateway API HTTPRoute support.
- NetworkPolicy, ServiceMonitor, dual-stack Service fields.
- External Secrets integration for database passwords.

Matomo 5.14.0 is the current stable production release. Review the
[official changelog](https://matomo.org/changelog/matomo-5-14-0/), and back up
the database and persistent application volume before production rollout so
the native updater can be rolled back together with its data.

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

## Upgrades

The official image keeps its release code under `/usr/src/matomo`, while this
chart persists `/var/www/html`. The `sync-matomo-code` init container copies the
release files into the persistent volume on every web pod start, so changing
`image.tag` also changes the code Matomo executes. The copy is additive: it
overwrites files shipped by the image but retains PVC-only files such as
`config/config.ini.php`, installed plugins, and `misc/user` content.

The sync archives the entries inside `/usr/src/matomo` rather than the source
directory itself, and preserves metadata on directories that already exist in
the volume. This allows the init container to run as a non-root UID when the
volume is writable through `podSecurityContext.fsGroup`; it does not need to
change the ownership, mode, or timestamps of the volume root.

The Deployment defaults to `updateStrategy.type=Recreate`, ensuring the old web
pod is stopped before the new init container changes application files. Plan a
brief maintenance window for image upgrades. Override this only when application
code is not shared with a serving pod during rollout.

Back up the database and PVC before changing `image.tag`. After the pod is
running with the new code, apply any required database migrations during the
planned maintenance window:

```bash
kubectl exec -n matomo deploy/matomo -- php /var/www/html/console core:update --yes --no-interaction
```

Set `persistence.codeSync.enabled=false` only when application files are managed
outside the image lifecycle.

## Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `replicaCount` | Matomo web replicas | `1` |
| `image.repository` | Official Matomo image repository | `docker.io/library/matomo` |
| `image.tag` | Official Matomo image tag | `5.14.0-apache` |
| `database.mode` | `auto`, `external`, or `mysql` | `auto` |
| `mysql.enabled` | Deploy HelmForge MySQL subchart | `true` |
| `persistence.enabled` | Persist `/var/www/html` | `true` |
| `persistence.codeSync.enabled` | Synchronize image code into `/var/www/html` on pod start | `true` |
| `persistence.codeSync.resources` | Resources for the code synchronization init container | `{}` |
| `archiver.enabled` | Create archive CronJob | `true` |
| `archiver.sameNodeAsMatomo` | Schedule the archiver with a web pod for RWO storage | `true` |
| `archiver.nodeSelector` | Node selector for archiver pods | `{}` |
| `archiver.tolerations` | Tolerations for archiver pods | `[]` |
| `archiver.affinity` | Custom affinity that replaces generated same-node affinity | `{}` |
| `updateStrategy.type` | Deployment rollout strategy | `Recreate` |
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
