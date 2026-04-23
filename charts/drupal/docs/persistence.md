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

## Multi-Replica Warning

The default storage mode is:

- `ReadWriteOnce`
- single replica

If you scale `replicaCount` above 1, use shared writable storage or keep a single replica. Otherwise uploaded files and installer-generated state may not behave consistently across pods.
