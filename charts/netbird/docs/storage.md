# NetBird storage

The chart persists NetBird server data under `/var/lib/netbird` by default.

The v1 chart defaults to PostgreSQL through the HelmForge PostgreSQL subchart.
This gives new production installs a network database by default while keeping a
self-contained Helm install experience.

Use the bundled PostgreSQL store:

```yaml
database:
  mode: postgresql
postgresql:
  enabled: true
```

Use an external PostgreSQL or MySQL database when your platform owns database
backups, HA, TLS, and maintenance:

```yaml
postgresql:
  enabled: false
database:
  mode: external
  external:
    engine: postgres
    host: postgres.example.com
    name: netbird
    username: netbird
    existingSecret: netbird-database
    existingSecretPasswordKey: database-password
```

Use SQLite only for disposable or small single-replica installs:

```yaml
database:
  mode: sqlite
postgresql:
  enabled: false
```

Keep `server.replicaCount: 1` in sqlite mode. Even with PostgreSQL or MySQL,
scaling the combined NetBird server requires protocol-aware routing and HA
planning for management, signal, relay, and STUN traffic.

Back up the PersistentVolumeClaim before chart upgrades. If you use an external database, include the database backup and the mounted NetBird data directory in the same recovery plan.
