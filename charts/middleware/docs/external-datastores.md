<!-- SPDX-License-Identifier: Apache-2.0 -->
# Middleware with external PostgreSQL

Middleware 0.3.1 supports a separate PostgreSQL connection through `DB_*`
environment variables. The chart applies upstream migrations before starting
the application.

## Prepare PostgreSQL

Create a database and application role according to your provider's security
model. A minimal SQL outline is:

```sql
CREATE ROLE middleware LOGIN PASSWORD '<operator-supplied-password>';
CREATE DATABASE "mhq-oss" OWNER middleware;
```

Use your provider's supported administrative workflow instead when direct role
creation is restricted.

## Store the password

Create a Kubernetes Secret without placing a password in a values file:

```bash
read -r -s -p 'External PostgreSQL password: ' MIDDLEWARE_DB_PASSWORD
printf '\n'
kubectl create secret generic middleware-database \
  --namespace middleware \
  --from-literal=password="$MIDDLEWARE_DB_PASSWORD"
unset MIDDLEWARE_DB_PASSWORD
```

An ExternalSecret, SealedSecret, or another secret controller may create the
same target Secret.

## Configure the chart

```yaml
postgresql:
  enabled: false

externalDatabase:
  enabled: true
  host: postgres.database.svc.cluster.local
  port: 5432
  name: mhq-oss
  user: middleware
  existingSecret: middleware-database
  existingSecretPasswordKey: password
  sslMode: require
```

Use `verify-ca` or `verify-full` only after mounting the provider CA and setting
the standard PostgreSQL certificate environment through `middleware.extraEnv`.
The chart passes both `middleware.extraEnv` and `extraVolumeMounts` to the
migration init container and the application container so both clients use the
same certificate configuration.

## Redis boundary

Do not enable `externalRedis` or the legacy `redis` subchart. Middleware 0.3.1
hard-codes an empty Redis password and enables TLS whenever the host is not
`localhost`. The chart therefore uses the Redis process bundled by the official
image on loopback and rejects unsupported remote settings.

## Recovery

Back up external PostgreSQL with the provider's native tools. Separately back up
the chart's key PVC. Restore both from a consistent recovery point; database
records encrypted with a different `config.ini` key pair cannot be decrypted.

See [operations.md](operations.md) for verification and restore steps.
