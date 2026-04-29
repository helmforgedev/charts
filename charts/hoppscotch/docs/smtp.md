# SMTP / Email Guide

Hoppscotch uses email for magic link authentication and user invitations.

## Without SMTP

Without SMTP configured, magic links and invitation emails are printed to the container logs. Users can copy the links manually in development environments.

## Enabling SMTP

### URL Mode (simple)

```yaml
mailer:
  enabled: true
  from: noreply@example.com
  useCustomConfigs: false
  smtpUrl: "smtps://user@example.com:password@smtp.example.com"
```

### Custom Config Mode (field-by-field)

```yaml
mailer:
  enabled: true
  from: noreply@example.com
  useCustomConfigs: true
  host: smtp.example.com
  port: 587
  secure: true
  user: smtp-user
  password: smtp-password
  tlsRejectUnauthorized: true
```

## Using ExistingSecret (production)

```yaml
mailer:
  enabled: true
  from: noreply@example.com
  useCustomConfigs: false
  existingSecret: hoppscotch-smtp
  existingSecretSmtpUrlKey: smtp-url
```

Or for custom config mode:

```yaml
mailer:
  enabled: true
  from: noreply@example.com
  useCustomConfigs: true
  host: smtp.example.com
  port: 587
  existingSecret: hoppscotch-smtp
  existingSecretPasswordKey: smtp-password
```

## Tested Providers

| Provider | Notes |
|----------|-------|
| SendGrid | Use API key as password, user=`apikey` |
| AWS SES  | Use SMTP credentials from IAM |
| Mailcatcher | Dev only: `smtp://mailcatcher:1025` |

## Environment Variables

The chart sets these when `mailer.enabled=true`:

| Variable | Source |
|----------|--------|
| `MAILER_SMTP_ENABLE` | `"true"` |
| `MAILER_ADDRESS_FROM` | `mailer.from` |
| `MAILER_USE_CUSTOM_CONFIGS` | `mailer.useCustomConfigs` |
| `MAILER_SMTP_URL` | Secret (when `useCustomConfigs=false`) |
| `MAILER_SMTP_HOST` | ConfigMap (when `useCustomConfigs=true`) |
| `MAILER_SMTP_PORT` | ConfigMap |
| `MAILER_SMTP_SECURE` | ConfigMap |
| `MAILER_SMTP_USER` | ConfigMap |
| `MAILER_SMTP_PASSWORD` | Secret |
| `MAILER_TLS_REJECT_UNAUTHORIZED` | ConfigMap |
