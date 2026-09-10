# Langflow Security

## Secret Key

New generated keys are URL-safe base64 encodings of 32 random bytes (Fernet).
Existing keys are preserved. Older generated 64-character alphanumeric keys are
not valid Fernet keys; audit them and plan recovery before upgrading. Never rotate
a persisted encryption key without accounting for stored credentials.

`LANGFLOW_SECRET_KEY` encrypts sensitive data and is also used for JWT signing in supported configurations.
If it changes between restarts, encrypted stored credentials can become unusable.
Use an existing Secret in production:

```yaml
auth:
  existingSecret: langflow-auth
```

## Superuser

The chart explicitly sets `LANGFLOW_AUTO_LOGIN=false`. Users must sign in with
the configured or retained generated superuser credentials. `auth.autoLogin=true`
is an opt-in for isolated development only.

Set a superuser password when exposing Langflow beyond a trusted local lab:

```yaml
auth:
  existingSecret: langflow-auth
  superuserKey: superuser
  superuserPasswordKey: superuser-password
```

## Provider Credentials

Do not store provider keys directly inside exported flow JSON. Put them in Kubernetes Secrets and expose them through `app.env` or `app.envFrom`.

## Network Policy

Enable NetworkPolicy to limit inbound traffic:

```yaml
networkPolicy:
  enabled: true
  ingressFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: apps
```
