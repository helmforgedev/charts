# Existing-user single sign-on

The chart exposes the native custom OAuth2 provider with explicit HTTPS authorization,
token and userinfo endpoints. Register the exact callback
`https://YOUR_HOST/api/auth/callback/custom`, including any public port.
Reference the confidential client Secret through `oauth.existingSecret`.

The pinned image uses Better Auth 1.7.3: custom providers use the standard social API,
PKCE defaults to enabled, and the earlier `/oauth2/callback/custom` URL is obsolete.
The owned fixture requires S256 and client authentication. This manual endpoint contract
uses authenticated userinfo; it does not advertise OIDC discovery or ID-token validation.
The manual OAuth2 userinfo response must include a stable `id`; an OIDC-style
`sub` by itself does not establish the provider identity in this mode.

Sign in with the initial local account and explicitly link the provider using the native
account settings. Global signup remains disabled, including OAuth signup. Keep the local
credential as a recovery path and configure verified SMTP before depending on password reset.
The native application owns account linking and email verification rules; the chart does not
write provider accounts into PostgreSQL or grant administrator roles.
For this custom provider, verify the local account's email through native email
delivery before linking. The upstream profile mapper preserves the local account's
verification state, so a provider's verified-email claim alone does not verify that
existing local account. Configure SMTP for this enrollment step; do not bypass
the rule with direct database writes or a patched list of trusted providers.

An optional CA Secret augments trust for native Node TLS clients. Chain and hostname checks
remain enabled. Permit the provider's token and userinfo endpoints through NetworkPolicy;
the browser separately needs access to its authorization endpoint. Additional CAs are shared
by the native process's integrations, not isolated per provider.

Runtime acceptance verified native email confirmation through SMTP, authenticated
linking, stable subject login, S256, state and callback replay rejection, closed signup
for a new identity, and unknown-CA/wrong-host rejection. Native rate limiting remains enabled.
