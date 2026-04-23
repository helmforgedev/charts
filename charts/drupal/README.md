# Drupal

A Helm chart for deploying [Drupal](https://new.drupal.org/home) on Kubernetes using the Docker Official Drupal image and a seeded persistent `sites/` directory.

Important runtime note:

- This chart uses `docker.io/library/drupal`.
- Drupal upstream does not currently publish its own upstream-maintained runtime container image.
- The chart prepares the runtime, persistence, ingress, and database path, then guides the user through the Drupal web installer.

## Install

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install drupal helmforge/drupal
```

### OCI registry

```bash
helm install drupal oci://ghcr.io/helmforgedev/helm/drupal
```

## Quick Start

```bash
helm install drupal oci://ghcr.io/helmforgedev/helm/drupal \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=drupal.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix
```

Then:

1. Wait for the Drupal pod and the MySQL subchart to become ready.
2. Open the Drupal URL.
3. Follow the installer.
4. Use the database details printed in `NOTES.txt`.

## Features

- **Docker Official Drupal Image** — Pinned `drupal:11.3.8-apache-bookworm`
- **Seeded `sites/` Persistence** — Preserves installer output and uploaded files without hiding the Drupal core files from the image
- **MySQL Subchart Path** — Bundled MySQL for straightforward first installs
- **SQLite Install Path** — Disable MySQL and use SQLite for simple or disposable environments
- **External Database Path** — Bring your own MySQL-compatible database and use its installer values
- **Ingress Support** — `ingressClassName`, hosts, and TLS
- **Custom PHP INI** — Mount extra PHP settings through a ConfigMap

## Minimal Example

```yaml
replicaCount: 1

mysql:
  enabled: true
  auth:
    database: drupal
    username: drupal

persistence:
  enabled: true
  size: 8Gi
```

## SQLite Example

```yaml
database:
  mode: sqlite

mysql:
  enabled: false
```

In the Drupal installer, choose SQLite and use:

```text
sites/default/files/.ht.sqlite
```

## External Database Example

```yaml
database:
  mode: external
  external:
    host: db.example.com
    port: 3306
    name: drupal
    username: drupal

mysql:
  enabled: false
```

## Main Parameters

| Key | Default | Description |
|-----|---------|-------------|
| `replicaCount` | `1` | Number of Drupal replicas. |
| `image.repository` | `docker.io/library/drupal` | Drupal image repository. |
| `image.tag` | `11.3.8-apache-bookworm` | Drupal image tag. |
| `database.mode` | `auto` | Database mode: `auto`, `external`, `mysql`, or `sqlite`. |
| `mysql.enabled` | `true` | Deploy bundled MySQL. |
| `mysql.auth.database` | `drupal` | Database name created by the MySQL subchart. |
| `mysql.auth.username` | `drupal` | Database username created by the MySQL subchart. |
| `persistence.enabled` | `true` | Enable persistence for `/var/www/html/sites`. |
| `persistence.size` | `8Gi` | Sites PVC size. |
| `php.ini` | `""` via `php.ini` | Extra PHP configuration content. |
| `ingress.enabled` | `false` | Enable ingress. |
| `drupal.sqlitePath` | `sites/default/files/.ht.sqlite` | Suggested SQLite path for installer use. |

## Operational Notes

- The chart does not auto-run the Drupal installer.
- The chart does not yet implement built-in backup automation.
- Multi-replica Drupal requires shared writable storage for `sites/`; the default `ReadWriteOnce` PVC is intended for single-replica installs.

## Additional Reading

- [docs/database.md](docs/database.md)
- [docs/persistence.md](docs/persistence.md)
