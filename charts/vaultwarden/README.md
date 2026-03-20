# Vaultwarden

Vaultwarden for Kubernetes with explicit storage-mode selection, ingress-oriented deployment, and clear modeling for admin token and SMTP.

## Install

```bash
helm install vaultwarden oci://ghcr.io/mberlofa/helm/vaultwarden -f values.yaml
```

## What this chart covers

- single-instance Vaultwarden deployment
- persistent `/data` storage through PVC
- storage modes for `sqlite`, external database, local PostgreSQL chart, or local MySQL chart
- optional ingress with `ingressClassName`
- optional SMTP configuration
- optional admin token through inline value or `existingSecret`
- websocket notifications on the same HTTP service

## Architecture guides

- [SQLite Mode](docs/sqlite.md)
- [Database Modes and Migrations](docs/database-modes-and-migrations.md)
- [External Database Backup](docs/external-database-backup.md)
- [Ingress and Domain](docs/ingress-and-domain.md)
- [SMTP and Email](docs/smtp-and-email.md)
- [Backup and Restore](docs/backup-and-restore.md)
- [Data Restore Patterns](docs/data-restore-patterns.md)
- [Admin Access and Hardening](docs/admin-access-and-hardening.md)
- [SSO and OIDC Guidance](docs/sso-and-oidc.md)
- [Runtime Configuration and config.json](docs/runtime-configuration-and-config-json.md)

## Operational direction

- this chart is intentionally single-instance in v1
- persistent `/data` is the normal path
- production should prefer an external database or one of the optional database subcharts
- SQLite is the fallback mode when no external database or subchart is configured
- ingress and `domain` should be aligned for attachment links and client behavior
- websocket traffic uses the same HTTP service and ingress path as the web vault

## Official product references

- Vaultwarden repository: https://github.com/dani-garcia/vaultwarden
- Vaultwarden configuration template: https://raw.githubusercontent.com/dani-garcia/vaultwarden/main/.env.template

## Best practices

### Persistence

- keep `data.persistence.enabled=true` for real environments
- back up `/data` regularly
- do not treat SQLite plus one PVC as HA
- use `data.persistence.existingClaim` or `selectorLabels` deliberately during restore workflows, not casually during normal install paths
- review [Backup and Restore](docs/backup-and-restore.md) before declaring the deployment production-ready
- review [Data Restore Patterns](docs/data-restore-patterns.md) before binding restored storage into a live release
- if you use PostgreSQL or MySQL, also review [External Database Backup](docs/external-database-backup.md)

### Database selection

- for production, prefer `database.external` or one of the optional subcharts
- `database.mode=auto` uses this precedence:
- `database.external.host` or `database.external.existingSecret`
- `postgresql.enabled=true`
- `mysql.enabled=true`
- fallback to SQLite
- if you use `database.external.existingSecret`, store a complete `DATABASE_URL` value in that secret
- if you use `postgresql.enabled=true` or `mysql.enabled=true`, define the application password explicitly so Vaultwarden can build the connection URL
- review [Database Modes and Migrations](docs/database-modes-and-migrations.md) before changing storage mode in a live environment

### Ingress and domain

- configure `domain` for real deployments
- terminate TLS at ingress or reverse proxy
- keep ingress hosts and `domain` aligned
- if Vaultwarden is exposed behind a path or non-default HTTPS port, keep that full external URL in `domain`
- keep `vaultwarden.proxy.ipHeader` aligned with your ingress controller or reverse proxy behavior
- review ingress/controller timeouts if websocket notifications are important for your users

### SQLite and runtime database settings

- keep `database.sqlite.enableWal=true` unless you have a specific reason to change it and understand the tradeoff
- review `database.connection.*` before applying very small or very large resource profiles
- remember that SQLite and `/data` persistence remain part of the same operational boundary in this chart

### Security

- keep signups disabled unless the instance is intended for self-service use
- prefer a hashed `ADMIN_TOKEN` value
- expose the admin panel carefully and only behind trusted access patterns
- enable `networkPolicy` in clusters where traffic should be explicitly restricted
- keep `runAsNonRoot`, dropped capabilities, and `RuntimeDefault` seccomp unless the platform proves a concrete incompatibility
- keep `showPasswordHint=false` on publicly reachable deployments
- review `orgCreationUsers`, `orgEventsEnabled`, and `emergencyAccessAllowed` instead of relying on product defaults you did not document
- review [Admin Access and Hardening](docs/admin-access-and-hardening.md) before enabling the admin page in production

### Important mapped settings

This chart intentionally maps the most important operational settings from the official Vaultwarden environment model:

- `DOMAIN`
- `SIGNUPS_ALLOWED`
- `SIGNUPS_VERIFY`
- `SIGNUPS_VERIFY_RESEND_TIME`
- `SIGNUPS_VERIFY_RESEND_LIMIT`
- `SIGNUPS_DOMAINS_WHITELIST`
- `INVITATIONS_ALLOWED`
- `INVITATION_ORG_NAME`
- `INVITATION_EXPIRATION_HOURS`
- `SENDS_ALLOWED`
- `EMERGENCY_ACCESS_ALLOWED`
- `EMAIL_CHANGE_ALLOWED`
- `ORG_EVENTS_ENABLED`
- `ORG_CREATION_USERS`
- `PASSWORD_ITERATIONS`
- `PASSWORD_HINTS_ALLOWED`
- `SHOW_PASSWORD_HINT`
- `ENABLE_WEBSOCKET`
- `IP_HEADER`
- `ENABLE_DB_WAL`
- `DB_CONNECTION_RETRIES`
- `DATABASE_TIMEOUT`
- `DATABASE_IDLE_TIMEOUT`
- `DATABASE_MIN_CONNS`
- `DATABASE_MAX_CONNS`
- `DATABASE_CONN_INIT`
- `ADMIN_TOKEN`
- `SMTP_*`

For advanced settings that are not first-class values in this chart yet, use `extraEnv` and keep the official template nearby:

- https://raw.githubusercontent.com/dani-garcia/vaultwarden/main/.env.template

### Admin token guidance

The admin page should not use a plain-text `ADMIN_TOKEN` in real environments. Prefer an Argon2 PHC string.

Simple generation options:

```bash
docker run --rm -it vaultwarden/server:1.35.4 /vaultwarden hash
```

```bash
echo -n 'change-me' | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4
```

Use the resulting PHC string directly in `admin.token` or store it in `admin.existingSecret`.

When using Helm values, quote the PHC string exactly as generated. Unlike `.env`-style Docker Compose examples, you do not need to escape `$` characters for YAML itself.

Official reference:

- https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page#secure-the-admin_token

## Production notes

- v1 does not support multiple replicas
- v1 does not claim HA
- this chart now supports `sqlite`, external database configuration, and optional local PostgreSQL or MySQL subcharts
- production should normally prefer `database.external`
- PostgreSQL or MySQL modes still require `/data` backup in addition to database backup
- SSO and OIDC remain advanced integration topics; this chart documents them but does not model them as first-class values in v2
- SMTP in production should use explicit timeout, security mode, and certificate validation choices instead of relying on provider defaults you did not document
- if you disable persistence, the deployment becomes disposable and data loss is expected
- part of the effective runtime configuration can be persisted in `/data/config.json`
- backup and restore must treat `/data` as a full state boundary, not only a SQLite file
- for detached backup automation, validate your PVC access pattern before assuming a separate backup pod can mount the same claim safely
- the best fit in this repository is a companion backup release with the `generic` chart when your storage semantics allow it
- if a restore uses pre-provisioned storage, validate `existingClaim` or PVC selector behavior before starting traffic

## Main values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Vaultwarden image repository | `vaultwarden/server` |
| `image.tag` | Vaultwarden image tag | `1.35.4` |
| `domain` | Public Vaultwarden domain | `""` |
| `database.mode` | `auto`, `sqlite`, `external`, `postgresql`, or `mysql` | `auto` |
| `database.external.vendor` | External database vendor | `postgres` |
| `database.external.host` | External database host | `""` |
| `database.external.name` | External database name | `vaultwarden` |
| `database.external.username` | External database username | `vaultwarden` |
| `database.external.existingSecret` | Existing secret containing a complete `DATABASE_URL` | `""` |
| `database.external.existingSecretUrlKey` | Secret key containing the `DATABASE_URL` value | `database-url` |
| `postgresql.enabled` | Enable the local PostgreSQL subchart | `false` |
| `mysql.enabled` | Enable the local MySQL subchart | `false` |
| `vaultwarden.signupsAllowed` | Allow new user signups | `false` |
| `vaultwarden.signupsVerify` | Require email verification for new signups | `false` |
| `vaultwarden.signupsVerifyResendTime` | Seconds before another verification email can be sent | `3600` |
| `vaultwarden.signupsVerifyResendLimit` | Maximum number of verification re-sends triggered by login attempts | `6` |
| `vaultwarden.signupsDomainsWhitelist` | Signup allowlist when signups are generally disabled | `[]` |
| `vaultwarden.invitationsAllowed` | Allow invitation flows | `true` |
| `vaultwarden.invitationOrgName` | Fallback invitation organization name | `Vaultwarden` |
| `vaultwarden.invitationExpirationHours` | Hours before invitation and verification tokens expire | `120` |
| `vaultwarden.sendsAllowed` | Allow Bitwarden Send | `true` |
| `vaultwarden.emergencyAccessAllowed` | Allow emergency access features | `true` |
| `vaultwarden.emailChangeAllowed` | Allow users to change their email | `true` |
| `vaultwarden.orgEventsEnabled` | Enable organization event logging | `false` |
| `vaultwarden.orgCreationUsers` | Which users may create organizations | `""` |
| `vaultwarden.passwordIterations` | Default number of password hashing iterations | `600000` |
| `vaultwarden.passwordHintsAllowed` | Allow password hints | `true` |
| `vaultwarden.showPasswordHint` | Show password hints directly in the web UI | `false` |
| `vaultwarden.websocket.enabled` | Enable websocket notifications | `true` |
| `vaultwarden.proxy.ipHeader` | Header used to detect the client IP behind a reverse proxy | `X-Real-IP` |
| `admin.token` | Inline admin token | `""` |
| `admin.existingSecret` | Existing secret containing the admin token | `""` |
| `smtp.enabled` | Enable SMTP configuration | `false` |
| `smtp.host` | SMTP host | `""` |
| `smtp.from` | SMTP sender address | `""` |
| `smtp.timeout` | SMTP timeout in seconds | `15` |
| `smtp.authMechanism` | Comma-separated SMTP auth mechanisms | `""` |
| `smtp.heloName` | HELO name sent to the SMTP server | `""` |
| `smtp.embedImages` | Embed images in email messages | `true` |
| `smtp.existingSecret` | Existing secret containing the SMTP password | `""` |
| `data.persistence.enabled` | Persist `/data` | `true` |
| `data.persistence.existingClaim` | Existing PVC for `/data` | `""` |
| `data.persistence.selectorLabels` | PVC selector labels for restore or pre-bound PV flows | `{}` |
| `data.persistence.size` | PVC size | `5Gi` |
| `database.sqlite.enableWal` | Enable SQLite WAL mode on startup | `true` |
| `database.connection.retries` | Number of startup retries while connecting to the database | `15` |
| `database.connection.timeout` | Database acquisition timeout in seconds | `30` |
| `database.connection.idleTimeout` | Idle database connection timeout in seconds | `600` |
| `database.connection.minConnections` | Minimum database connection pool size | `2` |
| `database.connection.maxConnections` | Maximum database connection pool size | `10` |
| `database.connection.init` | Optional SQL run for each new connection | `""` |
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.ingressClassName` | Ingress class name | `traefik` |
| `networkPolicy.enabled` | Enable NetworkPolicy rendering | `false` |
| `resources` | Pod resources | `{}` |

## CI scenarios

The `ci/` scenarios validate the main chart behaviors:

- `minimal.yaml`
- `persistent.yaml`
- `smtp.yaml`
- `smtp-complete.yaml`
- `existing-secret.yaml`
- `existing-claim.yaml`
- `restore-selector.yaml`
- `ingress.yaml`
- `ingress-tls.yaml`
- `database-external.yaml`
- `database-external-secret.yaml`
- `database-postgresql.yaml`
- `database-mysql.yaml`
- `hardening.yaml`

## Examples

See `examples/`:

- `minimal.yaml`
- `persistent.yaml`
- `existing-claim.yaml`
- `restore-selector.yaml`
- `smtp.yaml`
- `smtp-complete.yaml`
- `ingress-tls.yaml`
- `domain-with-path.yaml`
- `database-external.yaml`
- `database-external-secret.yaml`
- `database-postgresql.yaml`
- `database-mysql.yaml`
- `hardening.yaml`
