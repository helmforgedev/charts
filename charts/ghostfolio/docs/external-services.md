# External PostgreSQL and Redis

Disable the bundled dependencies and reference existing credentials:

```yaml
postgresql:
  enabled: false
database:
  external:
    enabled: true
    host: postgres.database.svc.cluster.local
    existingSecret: ghostfolio-database
    directUrlEnabled: true

redis:
  enabled: false
  external:
    enabled: true
    host: redis.cache.svc.cluster.local
    existingSecret: ghostfolio-redis
```

`ghostfolio-database` must contain `database-url` and, when
`directUrlEnabled=true`, `direct-url`. Store complete URL-encoded PostgreSQL
URLs. Use `DATABASE_URL` for a pooler and `DIRECT_URL` for direct migration
traffic. The Redis Secret contains `redis-password` by default.

The `host` fields are used by dependency waits. When NetworkPolicy isolation is
enabled, add label-selectable peers or explicit `networkPolicy.extraEgress`
rules for private destinations. Kubernetes NetworkPolicy cannot select a DNS
name.

For production, configure TLS in the URLs and provider, test connection limits,
monitor saturation, and prove a PostgreSQL restore. Ghostfolio migrations run
automatically on every application start; take a backup before image upgrades.
