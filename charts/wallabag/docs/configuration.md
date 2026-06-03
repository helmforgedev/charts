<!-- SPDX-License-Identifier: Apache-2.0 -->
# Wallabag — Configuration

Wallabag is a self-hosted read-it-later app. This chart runs the upstream
`wallabag/wallabag` image on PostgreSQL, with optional Redis and backups.

## Key values

| Value | Default | Purpose |
|---|---|---|
| `wallabag.port` | `80` | App HTTP port. |
| `postgresql.enabled` | `true` | Bundle the HelmForge PostgreSQL subchart (db `wallabag`). |
| `database.external.*` | — | Managed PostgreSQL (when `postgresql.enabled=false`). |
| `redis.enabled` | `false` | Async import/annotation queues (opt-in). |
| `persistence.enabled` / `persistence.size` | `true` | PVC for downloaded article assets. |
| `backup.enabled` / `backup.schedule` | `false` / `0 3 * * *` | Scheduled `pg_dump` to S3. |
| `ingress.*` | disabled | Expose the Web UI via Ingress/TLS. |

## Access and credentials

With `ingress.enabled=false` (default), port-forward the Service:

```bash
kubectl port-forward svc/<release>-wallabag 8080:80
# open http://localhost:8080/
```

Retrieve the admin password:

```bash
kubectl get secret <release>-wallabag -o jsonpath='{.data.wallabag-password}' | base64 -d
```

## Database

PostgreSQL is the source of truth. Use the bundled subchart for small installs,
or point at managed PostgreSQL via `database.external.*` (see
[external-database.md](external-database.md)). Back it up via the CronJob
([backup-restore.md](backup-restore.md)).

## Redis

Enable `redis.enabled=true` to process article imports and annotations
asynchronously. Leave it off for light usage (synchronous processing).

## Persistence

The PVC stores downloaded article images/assets; it is `ReadWriteOnce`, so the
app runs a single replica (see [../DESIGN.md](../DESIGN.md)).
