# Vaultwarden

Vaultwarden for Kubernetes with explicit persistent SQLite storage, ingress-oriented deployment, and clear modeling for admin token and SMTP.

## Install

```bash
helm install vaultwarden oci://ghcr.io/mberlofa/helm/vaultwarden -f values.yaml
```

## What this chart covers

- single-instance Vaultwarden deployment
- persistent `/data` storage through PVC
- SQLite as the v1 storage model
- optional ingress with `ingressClassName`
- optional SMTP configuration
- optional admin token through inline value or `existingSecret`
- websocket notifications on the same HTTP service

## Architecture guides

- [SQLite Mode](docs/sqlite.md)
- [Ingress and Domain](docs/ingress-and-domain.md)

## Operational direction

- this chart is intentionally single-instance in v1
- persistent `/data` is the normal path
- SQLite is the default and recommended mode for the current chart scope
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

### Ingress and domain

- configure `domain` for real deployments
- terminate TLS at ingress or reverse proxy
- keep ingress hosts and `domain` aligned
- keep `vaultwarden.proxy.ipHeader` aligned with your ingress controller or reverse proxy behavior

### SQLite and runtime database settings

- keep `data.sqlite.enableWal=true` unless you have a specific reason to change it and understand the tradeoff
- review `data.database.*` before applying very small or very large resource profiles
- remember that SQLite and `/data` persistence remain part of the same operational boundary in this chart

### Security

- keep signups disabled unless the instance is intended for self-service use
- prefer a hashed `ADMIN_TOKEN` value
- expose the admin panel carefully and only behind trusted access patterns
- keep `showPasswordHint=false` on publicly reachable deployments
- review `orgCreationUsers`, `orgEventsEnabled`, and `emergencyAccessAllowed` instead of relying on product defaults you did not document

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
- v1 does not try to abstract external databases
- if you disable persistence, the deployment becomes disposable and data loss is expected

## Main values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Vaultwarden image repository | `vaultwarden/server` |
| `image.tag` | Vaultwarden image tag | `1.35.4` |
| `domain` | Public Vaultwarden domain | `""` |
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
| `smtp.existingSecret` | Existing secret containing the SMTP password | `""` |
| `data.persistence.enabled` | Persist `/data` | `true` |
| `data.persistence.existingClaim` | Existing PVC for `/data` | `""` |
| `data.persistence.size` | PVC size | `5Gi` |
| `data.sqlite.enableWal` | Enable SQLite WAL mode on startup | `true` |
| `data.database.connectionRetries` | Number of startup retries while connecting to the database | `15` |
| `data.database.timeout` | Database acquisition timeout in seconds | `30` |
| `data.database.idleTimeout` | Idle database connection timeout in seconds | `600` |
| `data.database.minConnections` | Minimum database connection pool size | `2` |
| `data.database.maxConnections` | Maximum database connection pool size | `10` |
| `data.database.connectionInit` | Optional SQL run for each new connection | `""` |
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.ingressClassName` | Ingress class name | `traefik` |
| `resources` | Pod resources | `{}` |

## CI scenarios

The `ci/` scenarios validate the main chart behaviors:

- `minimal.yaml`
- `persistent.yaml`
- `smtp.yaml`
- `existing-secret.yaml`
- `ingress.yaml`

## Examples

See `examples/`:

- `minimal.yaml`
- `persistent.yaml`
- `smtp.yaml`
- `ingress-tls.yaml`
