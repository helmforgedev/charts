# Plugins and Object Cache

The chart can install WordPress plugins through an idempotent post-install/post-upgrade Job.
This is useful for mutable PVC-based installs and labs.
For immutable production, prefer a custom WordPress image with plugins already packaged.

The installer defaults to a 60 second active deadline and one retry.
Slow official plugin downloads or network blocks fail quickly instead of leaving a Helm install pending for several minutes.
The installer requires `persistence.enabled=true` because it writes plugin files and drop-ins to the shared WordPress volume.

## Custom Plugins

Only official WordPress.org plugin slugs are supported. The chart does not install arbitrary ZIP URLs or plugins from GitHub.
The installer runs as UID/GID 33 (`www-data`) by default, matching the file ownership created by the official WordPress image on the shared PVC.

```yaml
plugins:
  enabled: true
  installer:
    enabled: true
    image:
      repository: example.com/custom-wordpress-cli
      tag: cli-php8.3-memcached
  items:
    - slug: classic-editor
      activate: true
      skipIfInstalled: true
```

## Object Cache

### Redis

```yaml
plugins:
  enabled: true
  installer:
    enabled: true

objectCache:
  enabled: true
  provider: redis
  redis:
    mode: subchart
    subchart:
      enabled: true
```

The chart installs the official `redis-cache` plugin, configures `WP_REDIS_*`, and creates `wp-content/object-cache.php`.
If WordPress core is not installed yet, plugin files are downloaded directly from WordPress.org and activation is retried
on a future upgrade, but the drop-in can still be created from plugin files.

### Memcached

Memcached is supported as an advanced provider for custom WordPress images that include the PHP `memcached`
extension. The official WordPress image does not include that extension, so the chart fails fast unless you use a
custom image or explicitly acknowledge the limitation.

```yaml
image:
  repository: example.com/custom-wordpress
  tag: 7.0.0-apache-memcached

plugins:
  enabled: true
  installer:
    enabled: true

objectCache:
  enabled: true
  provider: memcached
  memcached:
    mode: subchart
    subchart:
      enabled: true

memcached:
  architecture: standalone
```

Prefer Redis when using the upstream official image unchanged.

## Validation

Functional Redis validation requires:

- WordPress pod Ready.
- Redis pod Ready.
- Plugin installer Job completed.
- `wp-content/object-cache.php` present.
- Requests made to WordPress.
- Redis contains keys with the configured prefix.

<!-- @AI-METADATA
type: chart-docs
title: WordPress Plugins and Object Cache
description: Plugin installer and object cache guide for the WordPress Helm chart
keywords: wordpress, plugins, redis, memcached, object-cache, wp-cli, helm
purpose: Documents mutable plugin installation and object cache integration
scope: Chart
relations:
  - charts/wordpress/README.md
  - charts/wordpress/values.yaml
path: charts/wordpress/docs/plugins.md
version: 1.0
date: 2026-05-06
-->
