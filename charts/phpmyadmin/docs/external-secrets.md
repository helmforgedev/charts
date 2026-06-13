# External Secrets

phpMyAdmin can consume credentials projected by External Secrets Operator. The
chart renders an `ExternalSecret` only when both `externalSecrets.enabled` and
`externalSecrets.auth.enabled` are true.

## Local Validation

The HelmForge local lab provides `ClusterSecretStore` `helmforge-fake-store` with
test keys:

- `test/username`
- `test/password`
- `test/token`

The CI values file uses that fake store so `make validate-chart CHART=phpmyadmin`
can verify reconciliation without external infrastructure.

## Production Pattern

Production deployments should point `externalSecrets.secretStoreRef` at a
platform-managed `SecretStore` or `ClusterSecretStore`, then map username,
password, and optional blowfish secret remote references into the auth Secret
consumed by the pod.

```yaml
externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  auth:
    enabled: true
    usernameRemoteRef:
      key: prod/phpmyadmin
      property: username
    passwordRemoteRef:
      key: prod/phpmyadmin
      property: password
```

Do not enable `auth.existingSecret` and `externalSecrets.auth.enabled` at the
same time. The chart fails fast because both features manage the same target
Secret contract.
