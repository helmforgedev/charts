# Certimate Storage

Certimate stores durable PocketBase data under `/app/pb_data`.

This directory should be backed up as a single unit because it contains application users, provider credentials, ACME account state, workflow definitions, issued certificates, and audit-relevant history.

Use a chart-managed PVC for simple installs:

```yaml
persistence:
  enabled: true
  size: 10Gi
```

Use an existing claim when your platform owns backup, restore, encryption, or snapshot policy:

```yaml
persistence:
  existingClaim: certimate-data
```

Do not disable persistence outside ephemeral validation environments.

If you intentionally need disposable storage, opt in explicitly:

```yaml
persistence:
  enabled: false
  ephemeral: true
```

There is no PostgreSQL, MySQL, or Redis subchart for Certimate. The upstream
container persists application state through PocketBase under `/app/pb_data`, so
the PVC is the production data authority.
