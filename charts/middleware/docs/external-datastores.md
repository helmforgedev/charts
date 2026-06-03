<!-- SPDX-License-Identifier: Apache-2.0 -->
# Middleware — Using managed PostgreSQL and Redis

For anything beyond a small team, run Middleware against managed datastores
instead of the bundled subcharts. PostgreSQL holds all DORA data (the source of
truth); Redis is the cache/queue.

## PostgreSQL

1. Create the database and a user on your managed PostgreSQL:

   ```sql
   CREATE DATABASE "mhq-oss";
   CREATE USER middleware WITH PASSWORD '<password>';
   GRANT ALL PRIVILEGES ON DATABASE "mhq-oss" TO middleware;
   ```

2. Store the password in a secret:

   ```bash
   kubectl create secret generic middleware-db --from-literal=user-password='<password>'
   ```

3. Configure the chart:

   ```yaml
   postgresql:
     enabled: false
   externalDatabase:
     enabled: true
     host: pg.internal.example.com
     port: 5432
     name: mhq-oss
     user: middleware
     existingSecret: middleware-db
     existingSecretPasswordKey: user-password
   ```

## Redis

```yaml
redis:
  enabled: false
externalRedis:
  enabled: true
  host: redis.internal.example.com
  port: 6379
```

## Notes

- Keep `persistence.enabled=true` even with external datastores — `/app/keys`
  (encryption keys) is local to the app pod and must persist.
- A full example is in [`../examples/external-datastores.yaml`](../examples/external-datastores.yaml).
- Back up the PostgreSQL `mhq-oss` database — it is the DORA data store.
