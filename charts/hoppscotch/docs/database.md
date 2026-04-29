# Database Guide

Hoppscotch requires PostgreSQL. The chart supports two modes: bundled subchart (default) or external.

## PostgreSQL Subchart (Default)

By default, the chart deploys a PostgreSQL instance using the HelmForge PostgreSQL subchart.

```yaml
postgresql:
  enabled: true
  auth:
    database: hoppscotch
    username: hoppscotch
    password: ""        # auto-generated if empty
  primary:
    persistence:
      enabled: true
      size: 10Gi
```

The `DATABASE_URL` is constructed automatically as:
```
postgresql://<username>:<password>@<release-name>-postgresql:5432/<database>
```

### Sizing

| Environment | Storage | CPU | RAM |
|-------------|---------|-----|-----|
| Dev/Test    | 10Gi    | 200m | 256Mi |
| Production  | 20Gi+   | 500m+ | 512Mi+ |

## External PostgreSQL

Disable the subchart and point to your managed instance (RDS, Cloud SQL, Supabase, etc.):

```yaml
postgresql:
  enabled: false
database:
  external:
    enabled: true
    host: db.example.com
    port: 5432
    name: hoppscotch
    username: hoppscotch
    password: "your-password"   # or use existingSecret
```

### Using ExistingSecret (recommended for production)

```yaml
postgresql:
  enabled: false
database:
  external:
    enabled: true
    host: db.example.com
    existingSecret: hoppscotch-db-secret
    existingSecretPasswordKey: postgres-password
```

Or provide the full URL in a secret:

```yaml
database:
  external:
    enabled: true
    host: db.example.com
    existingSecret: hoppscotch-db-secret
    existingSecretUrlKey: database-url
```

## Migrations

Prisma migrations run automatically on every deploy via the `migrate` init container:

```
pnpm exec prisma migrate deploy
```

The container runs before the main Hoppscotch container, and after `wait-for-db` confirms the database is accessible.

### Manual Migration (major version upgrades)

For major version upgrades, run migrations manually:

```bash
kubectl exec -n <namespace> deploy/<release>-hoppscotch -- \
  sh -c "pnpm exec prisma migrate deploy"
```

### Hard Reset (emergency)

To reset Hoppscotch configuration (does NOT delete user data):

```sql
TRUNCATE "InfraConfig";
```

Connect to PostgreSQL and run the above. This resets all admin-configured settings (SMTP, OAuth, etc.) back to defaults.
