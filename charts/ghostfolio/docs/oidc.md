# OpenID Connect

Ghostfolio marks OIDC as experimental. Keep token authentication enabled until
the complete provider flow and account association are verified.

```yaml
ghostfolio:
  rootUrl: https://wealth.example.com
  trustProxy: "1"
oidc:
  enabled: true
  issuer: https://idp.example.com
  clientId: ghostfolio
  existingSecret: ghostfolio-oidc
  scopes: [openid, email, profile]
```

The Secret must contain `client-secret`. Register
`https://wealth.example.com/api/auth/oidc/callback` at the provider. Prefer
issuer discovery; endpoint overrides exist only for providers that require
them. Use one canonical HTTPS origin and ensure ingress forwarded headers match
the configured `trustProxy` boundary.

Changing the issuer or identity claims can create a different account mapping.
Test with a disposable user and retain an administrator token before applying
OIDC changes to a production installation.
