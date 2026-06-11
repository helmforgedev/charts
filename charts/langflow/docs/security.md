# Langflow Security

## Secret Key

`LANGFLOW_SECRET_KEY` encrypts sensitive data and is also used for JWT signing in supported configurations.
If it changes between restarts, encrypted stored credentials can become unusable.
Use an existing Secret in production:

```yaml
auth:
  existingSecret: langflow-auth
```

## Superuser

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
