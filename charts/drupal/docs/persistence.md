# Persistence

Drupal stores critical mutable state under `sites/`, including:

- `sites/default/settings.php`
- `sites/default/files/`
- installer-generated configuration files

## Why Not Mount `/var/www/html`

Mounting a PVC over `/var/www/html` hides the Drupal core files shipped in the image and breaks the runtime layout.

## HelmForge Strategy

This chart:

1. creates a PVC or `emptyDir` for `sites/`
2. seeds the initial `sites/` content through an init container
3. mounts only `/var/www/html/sites` into the main container

This preserves installer output and uploaded files while keeping the core application files in the image layer.

## Multi-Replica Behavior

The default storage mode is:

- `ReadWriteOnce`
- single replica

If you scale Drupal above one replica, the chart requires:

- `persistence.enabled=true`
- `persistence.accessMode=ReadWriteMany`
- a MySQL-compatible database

This is enforced directly in the chart so unsafe multi-replica combinations fail during render time instead of breaking later in production.
