# Authentication Guide

Hoppscotch supports four authentication providers: EMAIL, GITHUB, GOOGLE, MICROSOFT.

## Configuration

```yaml
auth:
  providers: "EMAIL"          # comma-separated list of enabled providers
  github:
    enabled: false
  google:
    enabled: false
  microsoft:
    enabled: false
```

## EMAIL Provider (Magic Links)

Always available. Users enter their email and receive a magic link. Requires SMTP to be configured for link delivery; without SMTP, links appear in server logs only.

## GitHub OAuth

1. Create a GitHub OAuth App at <https://github.com/settings/applications/new>
2. Set Authorization callback URL to `<backendApiUrl>/auth/github/callback`

```yaml
auth:
  providers: "EMAIL,GITHUB"
  github:
    enabled: true
    clientId: "your-client-id"
    clientSecret: "your-client-secret"
    scope: "user:email"
```

Auto-derived callback URL: `https://<ingress.host>/backend/v1/auth/github/callback`

### Using ExistingSecret

```yaml
auth:
  github:
    enabled: true
    existingSecret: hoppscotch-oauth
    existingSecretClientIdKey: github-client-id
    existingSecretClientSecretKey: github-client-secret
```

## Google OAuth

1. Create credentials at <https://console.developers.google.com/>
2. Add callback URL: `<backendApiUrl>/auth/google/callback`

```yaml
auth:
  providers: "EMAIL,GOOGLE"
  google:
    enabled: true
    clientId: "your-client-id"
    clientSecret: "your-client-secret"
    scope: "email,profile"
```

## Microsoft OAuth

1. Register app at <https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps>
2. Add redirect URI: `<backendApiUrl>/auth/microsoft/callback`

```yaml
auth:
  providers: "EMAIL,MICROSOFT"
  microsoft:
    enabled: true
    clientId: "your-client-id"
    clientSecret: "your-client-secret"
    scope: "user.read"
```

## Callback URL Pattern

All OAuth callback URLs follow:

```text
<VITE_BACKEND_API_URL>/auth/<provider>/callback
```

When `ingress.host` is set and TLS is configured, this resolves to:

```text
https://<ingress.host>/backend/v1/auth/<provider>/callback
```

## First Admin User

The **first user to log in** via the Admin Dashboard becomes the administrator automatically. No seeding or manual configuration required.

Admin Dashboard URL: `<ingress.host>/admin` (subpath mode)

After becoming admin:

- Configure allowed auth providers via Admin Dashboard > Settings
- Generate InfraTokens for API/CI access: Admin > InfraTokens
- Manage user invitations: Admin > User Invitations

## VITE_ALLOWED_AUTH_PROVIDERS

This variable controls which providers appear on the login page. It must match the providers you have configured. Example:

```yaml
auth:
  providers: "EMAIL,GITHUB,GOOGLE"
  github:
    enabled: true
    # ...
  google:
    enabled: true
    # ...
```
