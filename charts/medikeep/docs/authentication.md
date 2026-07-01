# Authentication and Secrets

MediKeep creates a default `admin` user on fresh installs. Upstream defaults the first password to `admin123` unless `ADMIN_DEFAULT_PASSWORD` is set before the first startup.

For production, create a runtime Secret and reference it with `secrets.existingSecret`:

```yaml
secrets:
  existingSecret: medikeep-runtime
  secretKeyKey: secret-key
  adminDefaultPasswordKey: admin-password
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: medikeep-runtime
type: Opaque
stringData:
  secret-key: replace-with-a-long-random-secret
  admin-password: replace-with-a-strong-initial-password
```

SSO can be configured with regular values plus a Secret-backed client secret:

```yaml
medikeep:
  sso:
    enabled: true
    providerType: oidc
    clientId: medikeep
    issuerUrl: https://idp.example.com/realms/home
    redirectUri: https://medikeep.example.com/auth/sso/callback

secrets:
  existingSecret: medikeep-runtime
  ssoClientSecretKey: sso-client-secret
```

External Secrets Operator can materialize the same Secret:

```yaml
secrets:
  existingSecret: medikeep-runtime

externalSecrets:
  enabled: true
  items:
    - fullnameOverride: medikeep-runtime
      spec:
        secretStoreRef:
          kind: ClusterSecretStore
          name: production
        target:
          name: medikeep-runtime
          creationPolicy: Owner
        data:
          - secretKey: secret-key
            remoteRef:
              key: medikeep/app
              property: secret-key
          - secretKey: admin-password
            remoteRef:
              key: medikeep/app
              property: admin-password
```
