<!-- SPDX-License-Identifier: Apache-2.0 -->

# Drupal

A production-ready Helm chart for deploying [Drupal](https://new.drupal.org/home) on Kubernetes with seeded `sites/` persistence, scheduled S3 backups, and safe horizontal scaling guardrails.

Important runtime note:

- This chart uses `docker.io/library/drupal`.
- Drupal upstream does not currently publish its own upstream-maintained runtime container image.
- HelmForge pins the Docker Official Apache image explicitly to `11.4.10-php8.5-apache-bookworm`, which is published by the Docker Official Drupal image repository.
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

## Features

- **Pinned production image** — uses `drupal:11.4.10-php8.5-apache-bookworm`, keeping the Drupal release, PHP runtime, and Debian base explicit
- **Seeded `sites/` persistence** — preserves installer output and uploads without masking Drupal core files from the image
- **Built-in backup automation** — archives `sites/` and backs up either MySQL or SQLite to S3-compatible storage
- **Safe scaling model** — single replica by default, with fail-fast guardrails for multi-replica or HPA use
- **Installer-aware database paths** — bundled MySQL, external MySQL-compatible database, or SQLite
- **Production knobs included** — default resource requests/limits, optional HPA, optional PDB, ingress, and custom PHP configuration
- **Real listener configuration** — `containerPorts.http` updates both the Pod
  declaration and the official image's Apache configuration
- **Secure Kubernetes defaults** — API token automount disabled, privilege
  escalation blocked, `RuntimeDefault` seccomp, and optional NetworkPolicy

## Architecture

Users reach Drupal through an optional Ingress and a Service whose named
`targetPort` selects the configurable Apache listener. The Deployment mounts
only `/var/www/html/sites` from persistent storage, preserving mutable site
state without shadowing Drupal core from the pinned image. The default MySQL
2.1.1 subchart can be replaced with an external MySQL-compatible service or,
for a single replica, SQLite within the sites volume. An optional CronJob
archives the sites volume and database to S3-compatible storage.

See [DESIGN.md](DESIGN.md) for the Mermaid topology, trust boundaries,
observability boundary, and known limitations.

## Upstream Version Notes

Drupal `11.4.10` fixes SA-CORE-2026-014, SA-CORE-2026-015, and
SA-CORE-2026-016; no other fixes are included. Review the
[official release notes](https://www.drupal.org/project/drupal/releases/11.4.10).

Before upgrading production workloads, test the site in staging with the same
PHP extensions, Composer dependency set, storage class, and database mode used
in production. Review the Drupal 11.4.10 release notes before running database
updates.

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
| `image.tag` | `11.4.10-php8.5-apache-bookworm` | Drupal image tag. |
| `image.configureApachePort` | `null` | Auto-configure Apache for a non-default port on the official image; custom compatible images must opt in. |
| `containerPorts.http` | `80` | Actual Apache listener and Pod container port. |
| `service.port` | `80` | Service-facing port; its named target resolves to `containerPorts.http`. |
| `database.mode` | `auto` | Database mode: `auto`, `external`, `mysql`, or `sqlite`. |
| `mysql.enabled` | `true` | Deploy bundled MySQL. |
| `mysql` dependency | `2.1.1` | Pinned HelmForge MySQL subchart version. |
| `mysql.auth.database` | `drupal` | Database name created by the MySQL subchart. |
| `mysql.auth.username` | `drupal` | Database username created by the MySQL subchart. |
| `mysql.standalone.persistence.enabled` | `true` | Enable persistence for the bundled standalone MySQL subchart. |
| `mysql.standalone.persistence.size` | `8Gi` | Bundled standalone MySQL PVC size. |
| `persistence.enabled` | `true` | Enable persistence for `/var/www/html/sites`. |
| `persistence.accessMode` | `ReadWriteOnce` | Use `ReadWriteMany` for safe multi-replica Drupal. |
| `persistence.size` | `8Gi` | Sites PVC size. |
| `autoscaling.enabled` | `false` | Enable HPA when using RWX storage and a MySQL-compatible database. |
| `pdb.enabled` | `false` | Enable a PodDisruptionBudget for higher-availability deployments. |
| `backup.enabled` | `false` | Enable scheduled `sites/` + database backups to S3-compatible storage. |
| `php.ini` | `""` via `php.ini` | Extra PHP configuration content. |
| `ingress.enabled` | `false` | Enable ingress. |
| `networkPolicy.enabled` | `false` | Restrict Drupal ingress with a Kubernetes NetworkPolicy. |
| `networkPolicy.egress.enabled` | `false` | Add explicit DNS, database, HTTPS, SMTP, or custom egress rules. |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount a Kubernetes API token in Drupal pods. |
| `drupal.sqlitePath` | `sites/default/files/.ht.sqlite` | Suggested SQLite path for installer use. |

## Configuration

### Application and service ports

`containerPorts.http` controls the real Apache listener. `service.port` is the
independent client-facing Service port and targets the named `http` container
port. With the official Drupal image, the chart automatically prepares Apache
configuration when the listener differs from 80:

```yaml
containerPorts:
  http: 8080

service:
  port: 80
```

Custom images retain their own entrypoint contract. A custom image using the
official `/etc/apache2` layout must set `image.configureApachePort=true`; the
chart rejects an ambiguous non-default port otherwise.

### Network isolation

NetworkPolicy is opt-in because Drupal commonly reaches update services, SMTP,
external databases, and integrations. Start with ingress isolation, then enable
egress only after enumerating every required destination:

```yaml
networkPolicy:
  enabled: true
  ingress:
    allowSameNamespace: false
    extraFrom:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: ingress-nginx
        podSelector:
          matchLabels:
            app.kubernetes.io/name: ingress-nginx
            app.kubernetes.io/component: controller
  egress:
    enabled: true
    allowDNS: true
    allowSameNamespaceDatabase: true
    allowHTTPS: true
```

The cluster CNI must enforce NetworkPolicy. Adjust namespace and pod selectors
to match the ingress controller and database placement in your cluster.

## Operational Notes

- The chart does not auto-run the Drupal installer.
- Backup automation requires S3-compatible storage credentials and `persistence.enabled=true`.
- Multi-replica Drupal requires `ReadWriteMany` storage and a MySQL-compatible database; the chart blocks unsafe combinations.
- SQLite is supported for single-replica installs, including automated backups, but it is still not the preferred production path for most Drupal sites.

## Troubleshooting

Inspect the workload, application logs, and the persistent sites directory:

```bash
kubectl get pods -l app.kubernetes.io/name=drupal
kubectl logs deploy/<release>-drupal -c drupal --tail=100
kubectl exec deploy/<release>-drupal -- ls -la /var/www/html/sites
```

For a non-default listener, confirm the init container completed and Apache is
listening on the configured port:

```bash
kubectl logs deploy/<release>-drupal -c configure-apache-port
kubectl exec deploy/<release>-drupal -c drupal -- apache2ctl -S
```

If a NetworkPolicy blocks traffic, verify the ingress controller namespace and
database selectors, then inspect the rendered policy with `kubectl describe
networkpolicy <release>-drupal`.

## Additional Reading

- [docs/database.md](docs/database.md)
- [docs/backup.md](docs/backup.md)
- [docs/persistence.md](docs/persistence.md)
- [docs/scaling.md](docs/scaling.md)

### Security Scan: `drupal`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **83.33%** |

Rendered-manifest scan using Kubescape 4.0.13. Review application and database security settings, filesystem permissions and network isolation for the production deployment.
