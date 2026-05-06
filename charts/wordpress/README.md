# WordPress

A Helm chart for deploying [WordPress](https://wordpress.org/) on Kubernetes with the official `wordpress` Apache image,
HelmForge MySQL, external database support, backups, metrics, Gateway API, dual-stack Services, NetworkPolicy,
and External Secrets Operator integration.

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install wordpress helmforge/wordpress
```

```bash
helm install wordpress oci://ghcr.io/helmforgedev/helm/wordpress
```

## Quick Start

The default path is intentionally convenient for development and evaluation: one WordPress Deployment,
a bundled MySQL subchart, a persistent volume for `/var/www/html`, and generated credentials.

```bash
helm install wordpress oci://ghcr.io/helmforgedev/helm/wordpress \
  --set wordpress.adminPassword=change-me \
  --set mysql.auth.password=db-password
```

## Dev vs Production

Defaults are not intended to be a complete production baseline. They provide a fast working install.
For production, enable explicit credentials, TLS at the edge, resource requests and limits, backups, metrics,
restricted network flow, and a storage/database strategy that matches your availability target.

Production-ready options are available through values:

- External or bundled MySQL with existing Secrets or External Secrets Operator.
- Gateway API `HTTPRoute` or classic Ingress.
- Service dual-stack fields (`ipFamilyPolicy`, `ipFamilies`).
- NetworkPolicy ingress and optional egress allow lists.
- PodDisruptionBudget and HorizontalPodAutoscaler.
- Kubernetes CronJob for deterministic `wp-cron.php` execution.
- S3-compatible scheduled backups for database and `wp-content`.
- Structured `wp-config.php` settings for SSL admin, file editor lockout, cron, and memory limits.

## Features

- Official WordPress Apache image.
- HelmForge MySQL subchart or external MySQL/MariaDB.
- External Secrets Operator support with `external-secrets.io/v1`.
- Secret preservation across upgrades with `lookup` for chart-managed Secrets.
- Persistent storage for themes, plugins, uploads, and core files.
- Ingress and Gateway API exposure patterns.
- Dual-stack Service support.
- Optional NetworkPolicy for ingress and egress control.
- Optional HPA and PDB for production availability.
- Optional Prometheus metrics through Apache exporter and ServiceMonitor.
- Optional scheduled backups to S3-compatible storage.
- Extensibility through `extraEnv`, `extraEnvFrom`, extra volumes, extra init containers, extra containers, and extra manifests.
- Idempotent post-install/post-upgrade plugin installer Job.
- Redis Object Cache integration with HelmForge Redis subchart or external Redis.

## Production Example

```yaml
wordpress:
  siteUrl: https://blog.example.com
  adminEmail: admin@example.com
  forceSSLAdmin: true
  disallowFileEdit: true
  disableWpCron: true
  memoryLimit: 256M
  maxMemoryLimit: 512M

admin:
  existingSecret: wordpress-admin

mysql:
  enabled: false

database:
  external:
    host: mysql.example.com
    port: 3306
    name: wordpress
    username: wordpress
    existingSecret: wordpress-db
    existingSecretPasswordKey: password

persistence:
  enabled: true
  accessMode: ReadWriteMany
  storageClass: nfs-rwx
  size: 20Gi

service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6

gatewayAPI:
  enabled: true
  parentRefs:
    - name: public
      namespace: gateway-system
  hostnames:
    - blog.example.com

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5

pdb:
  enabled: true
  minAvailable: 1

wpCron:
  cronJob:
    enabled: true

networkPolicy:
  enabled: true
  ingress:
    extraFrom:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: gateway-system
  egress:
    enabled: true
    allowDNS: true
    allowSameNamespaceDatabase: false
    allowHTTPS: true

backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: wordpress-backups
    existingSecret: wordpress-s3

resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: "1"
    memory: 1Gi
```

## External Secrets Operator

External Secrets is optional. When enabled, the chart renders `ExternalSecret` resources and stops rendering the matching native Secret.

```yaml
externalSecrets:
  enabled: true
  secretStoreRef:
    name: vault
    kind: ClusterSecretStore
  admin:
    enabled: true
    passwordRemoteRef:
      key: prod/wordpress
      property: admin-password
  database:
    enabled: true
    passwordRemoteRef:
      key: prod/wordpress
      property: database-password

mysql:
  enabled: false

database:
  external:
    host: mysql.example.com
    existingSecretPasswordKey: database-password
```

The chart validates that `externalSecrets.apiVersion` is `external-secrets.io/v1`, a SecretStore is configured,
and ExternalSecret-managed credentials are not combined with `existingSecret` for the same credential.

## Plugins

The chart can run an idempotent plugin installer Job after install and upgrade.
The Job mounts the WordPress PVC and skips plugins that already exist, so upgrades do not reinstall the same plugin repeatedly.

```yaml
plugins:
  enabled: true
  installer:
    enabled: true
  items:
    - slug: classic-editor
      activate: true
      skipIfInstalled: true
    - slug: contact-form-7
      activate: true
      skipIfInstalled: true
```

The installer uses a `post-install,post-upgrade` Helm hook and pod affinity to run on the same node as the WordPress pod
when persistence is enabled. This improves compatibility with `ReadWriteOnce` PVCs.
The default installer deadline is 60 seconds with one retry, so failed official plugin downloads fail quickly during Helm installs.
Because the Job writes plugin files to the WordPress volume, `plugins.installer.enabled` requires `persistence.enabled=true`.

Only official WordPress.org plugin slugs are supported. When WordPress core is not installed yet,
the Job downloads the official plugin archive from `downloads.wordpress.org`, extracts it into `wp-content/plugins`,
and defers activation until a later upgrade.
The installer runs as `www-data` by default so it can write to the same PVC paths initialized by the official WordPress image.

## Redis Object Cache

Enable Redis Object Cache with the HelmForge Redis subchart:

```yaml
plugins:
  enabled: true
  installer:
    enabled: true

objectCache:
  enabled: true
  redis:
    mode: subchart
    subchart:
      enabled: true

redis:
  architecture: standalone
```

Or connect to external Redis:

```yaml
plugins:
  enabled: true
  installer:
    enabled: true

objectCache:
  enabled: true
  redis:
    mode: external
    external:
      host: redis.example.com
    auth:
      existingSecret: wordpress-redis
      existingSecretPasswordKey: redis-password
```

The chart configures `WP_CACHE`, `WP_REDIS_HOST`, `WP_REDIS_PORT`, `WP_REDIS_DATABASE`, `WP_REDIS_PREFIX`,
`WP_REDIS_CLIENT`, and optional `WP_REDIS_PASSWORD`.
It also installs `redis-cache` and creates `wp-content/object-cache.php`.

For immutable production deployments, prefer a custom WordPress image with required plugins and drop-ins already packaged.
The installer Job is a practical operational convenience for development, labs, and mutable PVC-based installs.

## Gateway API

Use Gateway API when your cluster exposes applications through Gateway controllers instead of Ingress.

```yaml
gatewayAPI:
  enabled: true
  parentRefs:
    - name: public
      namespace: gateway-system
      sectionName: https
  hostnames:
    - blog.example.com
```

The chart creates an `HTTPRoute` that sends traffic to the WordPress Service.

## Parameters

### Core

| Key | Default | Description |
|-----|---------|-------------|
| `replicaCount` | `1` | WordPress replicas when HPA is disabled |
| `wordpress.siteUrl` | `""` | Full site URL |
| `wordpress.siteTitle` | `WordPress` | Site title |
| `wordpress.adminUser` | `admin` | Initial admin username |
| `wordpress.adminPassword` | `""` | Initial admin password, generated when empty |
| `wordpress.adminEmail` | `admin@example.com` | Admin email |
| `wordpress.tablePrefix` | `wp_` | Database table prefix |
| `wordpress.debug` | `false` | Enables `WP_DEBUG` |
| `wordpress.forceSSLAdmin` | `false` | Sets `FORCE_SSL_ADMIN` |
| `wordpress.disallowFileEdit` | `false` | Sets `DISALLOW_FILE_EDIT` |
| `wordpress.disableWpCron` | `false` | Sets `DISABLE_WP_CRON` |
| `wordpress.memoryLimit` | `""` | Sets `WP_MEMORY_LIMIT` |
| `wordpress.maxMemoryLimit` | `""` | Sets `WP_MAX_MEMORY_LIMIT` |
| `wordpress.configExtra` | `""` | Extra PHP appended to `wp-config.php` |
| `wordpress.extraEnv` | `[]` | Extra environment variables |
| `wordpress.extraEnvFrom` | `[]` | Extra `envFrom` references |

### Database

| Key | Default | Description |
|-----|---------|-------------|
| `database.mode` | `auto` | `auto`, `external`, or `mysql` |
| `database.external.host` | `""` | External MySQL/MariaDB host |
| `database.external.port` | `3306` | External database port |
| `database.external.name` | `wordpress` | Database name |
| `database.external.username` | `wordpress` | Database username |
| `database.external.password` | `""` | Inline password for chart-managed Secret |
| `database.external.existingSecret` | `""` | Existing database Secret |
| `database.external.existingSecretPasswordKey` | `database-password` | Password key |
| `mysql.enabled` | `true` | Deploy HelmForge MySQL subchart |
| `mysql.auth.database` | `wordpress` | Subchart database name |
| `mysql.auth.username` | `wordpress` | Subchart database user |

### Exposure

| Key | Default | Description |
|-----|---------|-------------|
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `80` | HTTP Service port |
| `service.ipFamilyPolicy` | `""` | `SingleStack`, `PreferDualStack`, or `RequireDualStack` |
| `service.ipFamilies` | `[]` | Ordered IP families, for example `["IPv4", "IPv6"]` |
| `ingress.enabled` | `false` | Create an Ingress |
| `gatewayAPI.enabled` | `false` | Create an HTTPRoute |
| `gatewayAPI.parentRefs` | `[]` | Gateway parent references |
| `gatewayAPI.hostnames` | `[]` | HTTPRoute hostnames |

### Production Controls

| Key | Default | Description |
|-----|---------|-------------|
| `serviceAccount.create` | `false` | Create a dedicated ServiceAccount |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount Kubernetes API token |
| `autoscaling.enabled` | `false` | Create HPA |
| `pdb.enabled` | `false` | Create PodDisruptionBudget |
| `wpCron.cronJob.enabled` | `false` | Create deterministic WordPress cron CronJob |
| `networkPolicy.enabled` | `false` | Create NetworkPolicy |
| `networkPolicy.egress.enabled` | `false` | Manage egress allow list |
| `metrics.enabled` | `false` | Enable Apache exporter sidecar |
| `metrics.serviceMonitor.enabled` | `false` | Create ServiceMonitor |
| `plugins.enabled` | `false` | Enable plugin installer support |
| `plugins.installer.enabled` | `false` | Create plugin installer Job |
| `objectCache.enabled` | `false` | Enable Redis Object Cache integration |
| `objectCache.redis.mode` | `subchart` | Redis source: `subchart` or `external` |

### Storage and Backup

| Key | Default | Description |
|-----|---------|-------------|
| `persistence.enabled` | `true` | Create PVC for `/var/www/html` |
| `persistence.accessMode` | `ReadWriteOnce` | PVC access mode |
| `persistence.size` | `5Gi` | WordPress PVC size |
| `backup.enabled` | `false` | Create backup CronJob |
| `backup.schedule` | `0 3 * * *` | Backup schedule |
| `backup.s3.endpoint` | `""` | S3-compatible endpoint |
| `backup.s3.bucket` | `""` | Backup bucket |
| `backup.s3.existingSecret` | `""` | Existing S3 credentials Secret |

## Resources Generated

| Resource | Condition | Purpose |
|----------|-----------|---------|
| Deployment | Always | WordPress workload |
| Service | Always | Internal HTTP endpoint |
| PersistentVolumeClaim | `persistence.enabled` | WordPress files |
| Secret | Native credentials enabled | Admin, database, or backup credentials |
| ExternalSecret | `externalSecrets.*.enabled` | Sync credentials from external stores |
| Ingress | `ingress.enabled` | Classic HTTP routing |
| HTTPRoute | `gatewayAPI.enabled` | Gateway API routing |
| NetworkPolicy | `networkPolicy.enabled` | Network isolation |
| HorizontalPodAutoscaler | `autoscaling.enabled` | Replica scaling |
| PodDisruptionBudget | `pdb.enabled` | Disruption protection |
| CronJob | `wpCron.cronJob.enabled` | WordPress cron trigger |
| CronJob | `backup.enabled` | Database and content backup |
| Job | `plugins.installer.enabled` | Idempotent plugin installation and activation |
| ServiceMonitor | `metrics.serviceMonitor.enabled` | Prometheus scrape configuration |

## Examples

- [Simple](examples/simple.yaml)
- [External database](examples/external-db.yaml)
- [Production](examples/production.yaml)
- [External Secrets](examples/external-secrets.yaml)
- [Gateway API](examples/gateway-api.yaml)
- [Dual stack](examples/dual-stack.yaml)
- [Redis Object Cache](examples/redis-object-cache.yaml)
- [Custom plugins](examples/custom-plugins.yaml)

## Architecture Guides

- [Design](DESIGN.md)
- [Database Modes](docs/database.md)
- [Backup & Restore](docs/backup.md)
- [Production Guide](docs/production.md)

## Production Notes

Horizontal scaling requires shared writable storage for uploads/plugins/themes, or an operational model that moves media
to object storage and deploys code/plugins immutably.
With the default `ReadWriteOnce` PVC, keep `replicaCount: 1` and leave autoscaling disabled.

For high-traffic production, prefer an external managed MySQL/MariaDB service or a separately operated database chart
with backup, monitoring, and failover validated for your environment.

<!-- @AI-METADATA
type: chart-readme
title: WordPress Helm Chart
description: Deploy WordPress on Kubernetes with MySQL, External Secrets, Gateway API, backups, metrics, and production controls
keywords: wordpress, cms, blog, php, mysql, helm, kubernetes, gateway-api, external-secrets, dual-stack, backup, metrics
purpose: Installation guide, configuration reference, and operational documentation for the wordpress Helm chart
scope: Chart
relations:
  - charts/wordpress/DESIGN.md
  - charts/wordpress/docs/database.md
  - charts/wordpress/docs/backup.md
  - charts/wordpress/docs/production.md
  - charts/wordpress/values.yaml
path: charts/wordpress/README.md
version: 2.0
date: 2026-05-06
-->
