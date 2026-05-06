# WordPress Chart Design

This chart packages WordPress for Kubernetes using the official Apache image and HelmForge platform conventions.
The default install optimizes for a fast working environment, while production controls are opt-in and explicit.

## Goals

- Keep development installs simple.
- Provide a production path without forcing production defaults.
- Avoid raw overrides for common operational needs.
- Support both modern Kubernetes Gateway API and classic Ingress.
- Support native Kubernetes Secrets and External Secrets Operator.
- Make database, storage, cron, backup, and network choices visible.

## Default Architecture

```text
User
  |
  | port-forward or Service
  v
+-------------------+        +----------------------+
| WordPress Service | -----> | WordPress Deployment |
+-------------------+        | official apache img  |
                             | /var/www/html PVC    |
                             +----------+-----------+
                                        |
                                        | TCP 3306
                                        v
                             +----------------------+
                             | HelmForge MySQL      |
                             | StatefulSet + PVC    |
                             +----------------------+
```

This mode is useful for development, previews, and small internal installs. Credentials can be generated or supplied through values.

## Production Architecture With External Database

```text
Internet
  |
  v
+-------------------+       +-------------------+
| Gateway / Ingress | ----> | WordPress Service |
+-------------------+       +---------+---------+
                                      |
                                      v
                           +----------------------+
                           | WordPress Deployment |
                           | HPA optional         |
                           | PDB optional         |
                           | wp-cron CronJob      |
                           +----------+-----------+
                                      |
               +----------------------+------------------+
               |                                         |
               v                                         v
    +----------------------+                 +----------------------+
    | RWX shared storage   |                 | External MySQL or    |
    | or object media flow |                 | managed MariaDB      |
    +----------------------+                 +----------------------+
```

For more than one WordPress replica, the content strategy must be explicit.
Use ReadWriteMany storage for shared files, or operate plugins/themes/media through a deployment and object-storage strategy.

## Secrets Architecture

```text
External secret store
  |
  | External Secrets Operator
  v
+----------------+       +----------------------+
| ExternalSecret | ----> | Kubernetes Secret    |
+----------------+       | admin/database/S3    |
                         +----------+-----------+
                                    |
                                    v
                         +----------------------+
                         | WordPress / Backup   |
                         +----------------------+
```

External Secrets is optional. Native Secrets remain available for development and simple clusters.
The chart prevents using an existing Secret and an ExternalSecret for the same credential at the same time.

## Plugin Installer Architecture

```text
Helm post-install/post-upgrade
  |
  v
+----------------------+
| Plugin Installer Job |
| wordpress:cli        |
+----------+-----------+
           |
           | mounts same PVC
           v
+----------------------+
| WordPress files      |
| wp-content/plugins   |
| object-cache.php     |
+----------------------+
```

The installer is idempotent. It checks whether each plugin exists before installing it and activates plugins only after
WordPress core has completed installation.
Before `wp core install`, it downloads official WordPress.org plugin archives and extracts them without using
database-backed WP-CLI plugin operations.
It runs as UID/GID 33 (`www-data`) by default to match the official WordPress image file ownership on the shared PVC.
When persistence uses `ReadWriteOnce`, the Job uses pod affinity to schedule on the same node as the WordPress pod.
The Job is intentionally fail-fast with a 60 second active deadline and one retry by default.

## Redis Object Cache Architecture

```text
WordPress Deployment
  |
  | WP_REDIS_* constants
  | object-cache.php drop-in
  v
+-------------------------+
| Redis Object Cache      |
| plugin/drop-in          |
+------------+------------+
             |
             | TCP 6379
             v
+-------------------------+
| HelmForge Redis subchart|
| or external Redis       |
+-------------------------+
```

Redis integration is considered functional only when the drop-in exists and Redis receives cache keys after WordPress requests. A running Redis pod alone is not enough.

## Routing Architecture

```text
Gateway API path
Client -> Gateway -> HTTPRoute -> Service -> WordPress Pod

Ingress path
Client -> Ingress Controller -> Ingress -> Service -> WordPress Pod
```

Gateway API is preferred for clusters that already standardize on Gateway resources. Ingress remains supported for broad compatibility.

## Security Model

- ServiceAccount token automount is disabled by default.
- NetworkPolicy is optional and starts with ingress isolation when enabled.
- Egress can be explicitly allowed for DNS, database, HTTPS, SMTP, and custom destinations.
- WordPress file editing can be disabled with `wordpress.disallowFileEdit`.
- Admin SSL can be enforced with `wordpress.forceSSLAdmin`.
- Secrets can be sourced from External Secrets Operator using `external-secrets.io/v1`.

## Availability Model

The chart exposes HPA and PDB, but it does not assume WordPress is safely horizontally scalable by default. Autoscaling is valid only when content writes are safe across replicas.

Use this order for production decisions:

1. Choose database mode and backup ownership.
2. Choose content storage/media strategy.
3. Enable TLS routing.
4. Enable explicit resources, NetworkPolicy, metrics, and backups.
5. Add HPA/PDB only after storage and plugin behavior are safe for multiple pods.

## Backup Model

```text
Backup CronJob
  |
  +-- mysqldump database -> sql.gz
  +-- archive wp-content -> tar.gz
  +-- upload both artifacts -> S3-compatible bucket
```

The backup CronJob is designed as a practical baseline, not a full disaster recovery program.
Production users should test restores, retention, object lock, and database consistency in their own environment.

## Dependency Policy

The chart depends on HelmForge MySQL through `Chart.yaml`.
The repository workflow does not commit `Chart.lock` for this chart, so dependency resolution is performed during validation and packaging.
