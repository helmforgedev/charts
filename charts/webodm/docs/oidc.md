# OpenID Connect

Register `https://YOUR_HOST/oidc/callback/` as the provider callback. Create a
Secret containing `client-secret`, then configure `oidc.clientId`, the three
provider endpoints, and `oidc.existingSecret`.

The chart writes non-secret provider configuration to `settings_override.py`
and injects the client secret through an environment variable. WebODM always
requests `openid email`; `customScopes` adds claims such as `groups`.

`allowedEmails` accepts exact addresses and `@domain` suffixes. `groupClaims`
maps claim values to WebODM groups; enable `createGroups` only when the identity
provider is authoritative for those group names.
