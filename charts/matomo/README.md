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

- Official Matomo Apache image pinned to `5.14.2-apache`.
- Bundled HelmForge MySQL `2.1.1` subchart for simple deployments.
- External MySQL/MariaDB mode for production.
- CronJob-based `core:archive` execution.
- Persistent Matomo application volume.
- Automatic synchronization of image code into the persistent application volume.
- Ingress and Gateway API HTTPRoute support.
- NetworkPolicy, ServiceMonitor, dual-stack Service fields.
- External Secrets integration for database passwords.

Matomo 5.14.2 is the current stable production release. Review the
[5.14.1](https://matomo.org/changelog/matomo-5-14-1/) and
[5.14.2](https://matomo.org/changelog/matomo-5-14-2/) changelogs, and back up
the database and persistent application volume before production rollout so
the native updater can be rolled back together with its data. Neither patch
contains a major database upgrade.

Matomo 5.14.2 also carries an upstream security notice for two critical PHP
vulnerabilities. The pinned image contains PHP 8.4.27, which includes the
upstream fixes. Deploy the new tag instead of relying on a mutable rebuild of
an older Matomo tag that a Kubernetes node may already have cached.

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

Before upgrading from chart 2.4.x or earlier, move every retained value under
`mysql.primary` to the equivalent `mysql.standalone` path. The bundled
HelmForge MySQL dependency no longer reads `mysql.primary`; the chart now fails
with an explicit migration message instead of silently ignoring those values.
For example, migrate `mysql.primary.persistence.size` to
`mysql.standalone.persistence.size`.

Do not upgrade from chart 2.4.x with `--reuse-values` alone. It can omit the
newer `networkPolicy` parent map and make template rendering fail at
`.Values.networkPolicy.enabled`. With Helm 3.14 or later, use
`helm upgrade RELEASE helmforge/matomo --reset-then-reuse-values --dry-run`
to preview the rendered release, then repeat the command without `--dry-run`.
With Helm 3.13 or earlier, export the release overrides with
`helm get values RELEASE -o yaml > retained-values.yaml`, preview with
`helm upgrade RELEASE helmforge/matomo --reset-values -f retained-values.yaml --dry-run`,
then repeat that command without `--dry-run`. The preview can contain rendered
Kubernetes Secrets. Run it only in a trusted environment and keep its output
out of logs. Create `retained-values.yaml` with permissions restricted to its
owner and remove it immediately after the upgrade.

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

The Apache image listens on `containerPorts.http`. For a custom port, the chart
copies the packaged Apache configuration to a writable temporary directory and
changes the real listener before startup. FPM images require an HTTP sidecar;
set `webServer.mode=external` and make that sidecar listen on the named target
port. See `ci/fpm-sidecar-values.yaml` for the maintained nginx example.

## Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `replicaCount` | Matomo web replicas | `1` |
| `image.repository` | Official Matomo image repository | `docker.io/library/matomo` |
| `image.tag` | Official Matomo image tag | `5.14.2-apache` |
| `webServer.mode` | HTTP runtime owner: `apache` or `external` | `apache` |
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
| `containerPorts.http` | Web container port | `80` |

## Examples

- [Simple](examples/simple.yaml)
- [External database](examples/external-database.yaml)
- [Production](examples/production.yaml)
- [Gateway API](examples/gateway-api.yaml)

## Architecture Guides

- [Production](docs/production.md)
- [Networking](docs/networking.md)
- [External Secrets](docs/external-secrets.md)

## Troubleshooting

| Symptom | Check | Resolution |
| --- | --- | --- |
| Web Pod is not Ready after a port override | Compare listener, target port, and serving mode | Use `apache` for the Apache image; use `external` only with an HTTP sidecar. |
| Installer cannot connect to the database | Inspect database mode, Secret, and endpoints | Provide `database-password` and verify host/port reachability. |
| Upgrade still reports an old Matomo version | Inspect the effective Pod image and files on the application PVC | Deploy the new immutable image tag and keep `persistence.codeSync.enabled=true`. |
| Reports are slow or stale | Inspect the archiver CronJob and recent Jobs | Keep `archiver.enabled=true`, validate job completion, and tune the schedule. |
| Multiple replicas cannot mount storage | Inspect PVC access mode and Pod scheduling events | Use storage that supports the topology or keep one web replica with ReadWriteOnce. |

Operational procedures are documented in the [production](docs/production.md),
[networking](docs/networking.md), and
[External Secrets](docs/external-secrets.md) guides.

## Security Scan

### Security Scan: `matomo`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **84.783554%** |

Security posture acceptable.

Local details:

- Tool: Kubescape v4.0.9
- Command: `kubescape scan framework mitre,nsa,soc2 .tmp/matomo-render.yaml`
- Result: 0 critical failed resources, resource summary score 84.783554%.

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
