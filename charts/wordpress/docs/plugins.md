# Plugins and Object Cache

The chart can install WordPress plugins through an idempotent post-install/post-upgrade Job.
This is useful for mutable PVC-based installs and labs.
For immutable production, prefer a custom WordPress image with plugins already packaged.

The installer defaults to a 60 second active deadline and one retry.
Slow official plugin downloads or network blocks fail quickly instead of leaving a Helm install pending for several minutes.
The installer requires `persistence.enabled=true` because it writes plugin files and drop-ins to the shared WordPress volume.

## Official and Custom Plugins

Use `plugins.items` for official WordPress.org slugs. Use `plugins.custom` for a private or custom plugin ZIP whose
content and digest you control. Both paths are idempotent when `skipIfInstalled` is enabled.

The installer runs as UID/GID 33 (`www-data`) by default, matching the file ownership created by the official WordPress
image on the shared PVC. With `ReadWriteOnce` storage, pod affinity places the installer on the WordPress node.

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
  custom:
    - name: company-plugin
      url: https://plugins.example.com/company-plugin-1.4.2.zip
      sha256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
      activate: true
      skipIfInstalled: true
      authentication:
        existingSecret: wordpress-plugin-download
        tokenKey: token
```

The custom plugin contract enforces these controls:

- HTTPS is required. Plain HTTP is available only through an explicit test-fixture override and cannot be combined
  with authentication.
- A 64-character SHA-256 checksum is mandatory and is verified before extraction.
- Credentials are read only from `authentication.existingSecret`; inline credentials, URL userinfo, and query or
  fragment tokens are rejected.
- The bearer token is passed to the downloader through an environment variable, never through process arguments or
  rendered values. Download errors never print it.
- ZIP entries with absolute paths, traversal, backslashes, symlinks, or the wrong top-level directory are rejected.
- Download, checksum, archive, and activation failures are reported separately.
- An already installed plugin is not downloaded again when `skipIfInstalled: true`.
- `skipIfInstalled` defaults to `true`. Changing `url` or `sha256` does not trigger a download while the plugin
  directory exists; set `skipIfInstalled: false` or remove that directory to install the new version.
- Custom ZIP URLs must return the archive directly with an HTTP 2xx response. The downloader does not follow redirects.
- The default 60-second `activeDeadlineSeconds` applies to the entire installer Job and all configured plugins. Increase
  it when processing several or large archives.

Provision the referenced Secret independently before installing the release. The values file contains only the Secret
name and key, not the token. See [custom-plugins.yaml](../examples/custom-plugins.yaml) for a complete values example.

## WordPress Plugin or PHP Extension

A WordPress plugin is application code stored under `wp-content/plugins`. A PHP extension is a native runtime module
loaded by PHP. A plugin ZIP cannot install an extension.

The official WordPress image includes `mysqli`. Applications that require modules such as `pdo_mysql` or `memcached`
need a derivative image built before deployment. Build from the exact official WordPress tag used by the chart, pin the
result by immutable tag or digest, scan it, and produce an SBOM and provenance. If WP-CLI jobs need the extension too,
build a matching CLI target and configure the bootstrap and plugin installer images. The WordPress cron CronJob invokes
the application over HTTP and therefore does not load PHP extensions in its curl container.

The chart does not compile PHP extensions during startup and HelmForge does not publish application-specific extension
images. The reusable [custom PHP image example](../examples/custom-php-image/README.md) includes a multi-target
Dockerfile and GitHub Actions pipeline.

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
description: Verified custom plugin, PHP extension image, and object cache guide for the WordPress Helm chart
keywords: wordpress, plugins, php-extensions, redis, memcached, object-cache, wp-cli, helm
purpose: Documents verified plugin installation, PHP extension images, and object cache integration
scope: Chart
relations:
  - charts/wordpress/README.md
  - charts/wordpress/values.yaml
path: charts/wordpress/docs/plugins.md
version: 2.0
date: 2026-10-23
-->
