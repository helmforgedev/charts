# OAuth2 Proxy External Secrets

Enable `externalSecrets.enabled=true` when credentials are managed by External Secrets Operator.

Set `auth.existingSecret` to the target Secret name and provide either `externalSecrets.data` for individual mappings or `externalSecrets.dataFrom` for provider-side extraction.

The target Secret must provide the keys configured under `auth.keys`: `client-id`, `client-secret`, and `cookie-secret` by default.
