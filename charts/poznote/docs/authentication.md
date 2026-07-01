# Authentication

Poznote supports local accounts and OIDC/SSO authentication.

## Default Credentials

On fresh install, Poznote creates one administrator account:

- Username: `admin_change_me`
- Password: `admin`

Change the default credentials immediately after first login.

## OIDC / SSO

Most OIDC settings are configured from the Poznote admin UI (Settings > Admin Tools > OIDC / SSO).

The chart manages the sensitive credentials via Kubernetes Secrets:

### Inline Values

```yaml
secrets:
  oidcClientId: "your-client-id"
  oidcClientSecret: "your-client-secret"

poznote:
  oidc:
    disableNormalLogin: false
```

### Existing Secret

```yaml
secrets:
  existingSecret: my-poznote-oidc
  oidcClientIdKey: oidc-client-id
  oidcClientSecretKey: oidc-client-secret
```

The Secret must contain keys matching `oidcClientIdKey` and `oidcClientSecretKey`.

### SSO-Only Mode

To hide the local login form and force SSO:

```yaml
poznote:
  oidc:
    disableNormalLogin: true
```

## External Secrets Operator

For enterprise environments, use ESO to sync OIDC credentials from a vault:

```yaml
externalSecrets:
  enabled: true
  items:
    - name: oidc
      spec:
        secretStoreRef:
          name: vault-backend
          kind: ClusterSecretStore
        data:
          - secretKey: oidc-client-id
            remoteRef:
              key: secret/data/poznote
              property: oidc_client_id
          - secretKey: oidc-client-secret
            remoteRef:
              key: secret/data/poznote
              property: oidc_client_secret
```
