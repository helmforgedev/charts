# Production Guide

This chart can be used in development and production, but production requires explicit choices. The default values are intentionally small and convenient.

## Recommended Production Baseline

```yaml
wordpress:
  siteUrl: https://blog.example.com
  forceSSLAdmin: true
  disallowFileEdit: true
  disableWpCron: true
  memoryLimit: 256M
  maxMemoryLimit: 512M

wpCron:
  cronJob:
    enabled: true

bootstrap:
  enabled: true
  permalinkStructure: /%postname%/

resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: "1"
    memory: 1Gi

networkPolicy:
  enabled: true
  metrics:
    enabled: true
  egress:
    enabled: true
    allowDNS: true
    allowHTTPS: true

metrics:
  enabled: true

backup:
  enabled: true
```

## Storage

With `persistence.accessMode: ReadWriteOnce`, keep a single WordPress pod.
Use ReadWriteMany storage or an object-storage media strategy before enabling HPA or replicas greater than one.

## Database

For production, prefer one of these patterns:

- External managed MySQL/MariaDB with automated backups and failover.
- A separately operated database release with tested backup, restore, monitoring, and upgrade procedures.
- HelmForge MySQL subchart for smaller environments where the operational tradeoff is acceptable.

## Secrets

Use `admin.existingSecret`, `database.external.existingSecret`, and `backup.s3.existingSecret` for simple clusters.
Use `externalSecrets` when the cluster runs External Secrets Operator and credentials are managed in an external store.

## Bootstrap

Enable `bootstrap.enabled` when Helm should perform the initial `wp core install` through WP-CLI.
Always set `wordpress.siteUrl` to the final public URL before enabling bootstrap.
The bootstrap Job is idempotent by default and skips work when the database already contains an installed site.

## Plugins and PHP Extensions

For mutable PVC-based installations, `plugins.items` installs official WordPress.org slugs and `plugins.custom`
installs HTTPS ZIPs only after verifying a required SHA-256 checksum. Private download tokens must come from an
existing Secret. Prefer plugins baked into an immutable image for tightly controlled production environments.

WordPress plugins and PHP extensions are different artifacts. The official image includes `mysqli`; requirements such
as `pdo_mysql` or `memcached` need a derivative image built, scanned, and published before deployment. The chart never
compiles extensions during startup. Configure matching custom WP-CLI images for bootstrap and plugin operations that
also require the extension. The cron CronJob uses HTTP and its curl container does not load PHP extensions. See the
[custom PHP image pipeline](../examples/custom-php-image/README.md).

## Pod Annotations for Jobs and CronJobs

`podAnnotations` only applies to the WordPress Deployment pod. The bootstrap Job, plugin installer Job, wp-cron
CronJob, and backup CronJob have their own pod annotations, so a batch pod can differ from the Deployment:

- `bootstrap.podAnnotations`
- `plugins.installer.podAnnotations`
- `wpCron.cronJob.podAnnotations`
- `backup.podAnnotations`

A common use is Linkerd auto-injection. The `linkerd-proxy` sidecar does not exit when the main container finishes, so
the pod stays `NotReady` and its Job never completes. The bootstrap and plugin installer Jobs fail once their
`activeDeadlineSeconds` is reached, and tools such as Argo CD then report the sync as failed even though the
application is healthy. The CronJobs set no deadline, so a stuck run stays active, and with the default
`concurrencyPolicy: Forbid` every later scheduled run is skipped. Opt the batch pods out of injection while the
Deployment stays meshed:

```yaml
bootstrap:
  podAnnotations:
    linkerd.io/inject: disabled
plugins:
  installer:
    podAnnotations:
      linkerd.io/inject: disabled
wpCron:
  cronJob:
    podAnnotations:
      linkerd.io/inject: disabled
backup:
  podAnnotations:
    linkerd.io/inject: disabled
```

Other pod-level annotations, such as Vault Agent or Datadog settings, work the same way. Annotation values must be
strings, so quote values that YAML would read as a boolean or number, for example
`vault.hashicorp.com/agent-inject: "true"`. The chart schema rejects unquoted ones. Only annotations are supported: a
setting that must be a pod label, such as Istio's `sidecar.istio.io/inject`, cannot be set through these keys.

## Routing

Use either Ingress or Gateway API. Do not enable both for the same hostname unless you intentionally want two routing paths.
`containerPorts.http` configures the actual Apache listener, while `service.port` remains the client-facing Kubernetes
Service port. The Service targets the named `http` port, so the two values do not need to match. For a non-default port,
the official image receives a prepared Apache configuration without replacing its entrypoint. Custom repositories retain
their own startup contract; make them listen on the selected port or set `image.configureApachePort: true` only when they
retain the official `/etc/apache2` layout.

## NetworkPolicy

Enable `networkPolicy.enabled` to isolate inbound traffic.
Enable `networkPolicy.egress.enabled` only after listing required destinations such as DNS, database, HTTPS APIs,
object storage, and SMTP.
Use `networkPolicy.egress.extraEgress` for destinations that need complete custom `to` and `ports` rules.

Redis object cache is the recommended provider for the official WordPress image. Memcached can be used with the
HelmForge Memcached subchart only when the WordPress image includes the required PHP extension.

<!-- @AI-METADATA
type: chart-docs
title: WordPress Production Guide
description: Production deployment guidance for the WordPress Helm chart
keywords: wordpress, production, kubernetes, helm, plugins, php-extensions, gateway-api, external-secrets, networkpolicy
purpose: Production hardening guide for the wordpress Helm chart
scope: Chart
relations:
  - charts/wordpress/README.md
  - charts/wordpress/DESIGN.md
  - charts/wordpress/values.yaml
path: charts/wordpress/docs/production.md
version: 1.1
date: 2026-10-23
-->
