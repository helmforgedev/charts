# Drupal

A production-ready Helm chart for deploying [Drupal](https://new.drupal.org/home) on Kubernetes with seeded `sites/` persistence, scheduled S3 backups, and safe horizontal scaling guardrails.

Important runtime note:

- This chart uses `docker.io/library/drupal`.
- Drupal upstream does not currently publish its own upstream-maintained runtime container image.
- HelmForge pins the Docker Official image explicitly to `11.3.8-php8.5-apache-bookworm`, which includes PHP 8.5 and the Drupal-required database extensions.
- The chart prepares runtime, persistence, ingress, backup automation, and database connectivity, then guides the final site installation through Drupal's web installer.

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

## Why This Chart Is Different

- **Pinned production image** — uses `drupal:11.3.8-php8.5-apache-bookworm`, which matches current Drupal 11.3 support for PHP 8.5 and keeps the Debian base explicit
- **Seeded `sites/` persistence** — preserves installer output and uploads without masking Drupal core files from the image
- **Built-in backup automation** — archives `sites/` and backs up either MySQL or SQLite to S3-compatible storage
- **Safe scaling model** — single replica by default, with fail-fast guardrails for multi-replica or HPA use
- **Installer-aware database paths** — bundled MySQL, external MySQL-compatible database, or SQLite
- **Production knobs included** — default resource requests/limits, optional HPA, optional PDB, ingress, and custom PHP configuration

## Production Example

```yaml
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: drupal.example.com
      paths:
        - path: /
          pathType: Prefix

persistence:
  accessMode: ReadWriteMany
  size: 20Gi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 6

pdb:
  enabled: true
  minAvailable: 1

backup:
  enabled: true
  s3:
    endpoint: https://minio.example.com
    bucket: drupal-backups
    existingSecret: drupal-backup-s3
```

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
| `image.tag` | `11.3.8-php8.5-apache-bookworm` | Drupal image tag. |
| `database.mode` | `auto` | Database mode: `auto`, `external`, `mysql`, or `sqlite`. |
| `mysql.enabled` | `true` | Deploy bundled MySQL. |
| `mysql.auth.database` | `drupal` | Database name created by the MySQL subchart. |
| `mysql.auth.username` | `drupal` | Database username created by the MySQL subchart. |
| `persistence.enabled` | `true` | Enable persistence for `/var/www/html/sites`. |
| `persistence.accessMode` | `ReadWriteOnce` | Use `ReadWriteMany` for safe multi-replica Drupal. |
| `persistence.size` | `8Gi` | Sites PVC size. |
| `autoscaling.enabled` | `false` | Enable HPA when using RWX storage and a MySQL-compatible database. |
| `pdb.enabled` | `false` | Enable a PodDisruptionBudget for higher-availability deployments. |
| `backup.enabled` | `false` | Enable scheduled `sites/` + database backups to S3-compatible storage. |
| `php.ini` | `""` via `php.ini` | Extra PHP configuration content. |
| `ingress.enabled` | `false` | Enable ingress. |
| `drupal.sqlitePath` | `sites/default/files/.ht.sqlite` | Suggested SQLite path for installer use. |

## Operational Notes

- The chart does not auto-run the Drupal installer.
- Backup automation requires S3-compatible storage credentials and `persistence.enabled=true`.
- Multi-replica Drupal requires `ReadWriteMany` storage and a MySQL-compatible database; the chart blocks unsafe combinations.
- SQLite is supported for single-replica installs, including automated backups, but it is still not the preferred production path for most Drupal sites.

## Additional Reading

- [docs/database.md](docs/database.md)
- [docs/backup.md](docs/backup.md)
- [docs/persistence.md](docs/persistence.md)
- [docs/scaling.md](docs/scaling.md)
