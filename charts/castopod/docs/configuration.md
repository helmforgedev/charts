<!-- SPDX-License-Identifier: Apache-2.0 -->
# Castopod: Configuration

This guide covers the settings that need more context than the README tables.
Every key is listed in `values.yaml`.

## Base URL and HTTPS

Castopod embeds the base URL in feeds, the web player, and federation
messages. Set it to the public URL before publishing:

```yaml
castopod:
  baseURL: https://podcast.example.com
```

When `castopod.baseURL` is empty, the chart uses the first Ingress host
(`https://` when `ingress.tls` is set), then the first HTTPRoute hostname
(`https://`), then `http://localhost:8080`. For `http://` URLs the chart sets
`CP_DISABLE_HTTPS=1`, because Castopod otherwise redirects every request to
HTTPS. Federation requires HTTPS, so use `http://` only for local checks.

## Superadmin

The setup init container creates the superadmin once, when no owner exists:

```yaml
castopod:
  admin:
    username: owner
    email: owner@example.com
    existingSecret: castopod-admin   # key admin-password
```

Without `existingSecret`, the chart stores `castopod.admin.password` or a
generated 32-character password in `<release>-castopod-admin`. Changing the
value later does not change the existing account; use the admin area. Set
`castopod.admin.create=false` to complete `/cp-install` in the browser instead.

## External MariaDB

```yaml
mariadb:
  enabled: false
database:
  external:
    host: mariadb.example.com
    port: "3307"
    name: castopod
    username: castopod
    existingSecret: castopod-db
    existingSecretPasswordKey: password
```

The user needs full privileges on the database: migrations run on every pod
start. The upstream bootstrap writes only the host to `.env`, so the setup
container adds `database.default.port` to it.

## Redis cache

```yaml
redis:
  enabled: true
```

The chart connects to `<release>-redis-client` with the password from
`<release>-redis-auth` and Castopod switches its cache handler to Redis.
Castopod refuses to start with Redis and no password, so
`redis.auth.enabled=false` fails the render.

## SMTP, S3 media, and other Castopod settings

Castopod reads `CP_*` variables when the setup container renders `.env`. Pass
them through `castopod.extraEnv`, using Secrets for credentials:

```yaml
castopod:
  extraEnv:
    - name: CP_EMAIL_SMTP_HOST
      value: smtp.example.com
    - name: CP_EMAIL_SMTP_USERNAME
      value: castopod
    - name: CP_EMAIL_SMTP_PASSWORD
      valueFrom:
        secretKeyRef:
          name: castopod-smtp
          key: password
    - name: CP_EMAIL_FROM
      value: podcast@example.com
```

S3 media storage uses `CP_MEDIA_FILE_MANAGER=s3` with `CP_MEDIA_S3_ENDPOINT`,
`CP_MEDIA_S3_KEY`, `CP_MEDIA_S3_SECRET`, `CP_MEDIA_S3_REGION`, and
`CP_MEDIA_S3_BUCKET`. See the
[Castopod documentation](https://docs.castopod.org)
for the full list.

## Listener port

`castopod.port` sets `CADDY_HTTP_PORT`, the port FrankenPHP listens on, and
the container port. The Service always targets the named `http` port, so
`service.port` can differ. Ports below 1024 are rejected because the pod runs
without privilege escalation.

## Storage and backups

One volume holds two paths:

| Mount | Source | Content |
|-------|--------|---------|
| `/var/www/html/writable` | volume root | cache, logs, sessions, temporary files |
| `/var/www/html/public/media` | subPath `public-media` | uploaded audio, artwork, and site images |

`backup.enabled=true` archives the whole volume to S3 on `backup.schedule`.
The archive does not contain the database; back up MariaDB with the MariaDB
chart or the managed provider, and restore both together.
