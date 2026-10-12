# Credentials and External Secrets

## Existing Secret contract

Set `auth.existingSecret` to a Secret in the release namespace. By default it
must contain `username` and `password`. Mode `both` also requires
`paper-username` and `paper-password`. Override the four `auth.*Key` values when
your secret manager uses different key names.

The live credential keys are also used for `paper` mode. This matches upstream's
single-account workflow. Mode `both` starts a separate paper session and needs
the additional paper keys.

Create a mode-`0600` password file outside the repository, then run:

```bash
kubectl -n ib-gateway create secret generic ib-gateway-credentials \
  --from-literal=username='live-or-paper-user' \
  --from-file=password=/secure/path/ibkr-password
```

Protect the file and remove it securely after confirming the Secret exists. This
keeps the password out of shell history.

Never commit credentials to values files. Inline `auth.username` and
`auth.password` exist for evaluation and are stored in Helm release history.

## External Secrets Operator

Enable `externalSecrets.enabled` and define one item whose target name matches
`auth.existingSecret`. Each item accepts the ExternalSecret `spec`, plus chart
metadata fields. The chart defaults an omitted target name to the rendered
ExternalSecret name.

```yaml
auth:
  existingSecret: ib-gateway-credentials
externalSecrets:
  enabled: true
  items:
    - fullnameOverride: ib-gateway-credentials
      spec:
        secretStoreRef:
          name: production
          kind: ClusterSecretStore
        data:
          - secretKey: username
            remoteRef:
              key: trading/ibkr/username
          - secretKey: password
            remoteRef:
              key: trading/ibkr/password
```

The operator must be installed separately. Restrict access to the source secret,
target Secret, Helm values, and release history.

## VNC password

When VNC is enabled, set `vnc.existingSecret`, reuse `auth.existingSecret`, or
provide `vnc.password` only for evaluation. The default key is `vnc-password`.
The password is mounted through `VNC_SERVER_PASSWORD_FILE`.

## Rotation

Update the source Secret and restart the Deployment after synchronization:

```bash
kubectl -n ib-gateway rollout restart deployment/ib-gateway
kubectl -n ib-gateway rollout status deployment/ib-gateway
```

Credential rotation terminates the current session and normally requires fresh
two-factor approval. Schedule it with trading operations rather than treating it
as a transparent rolling change.
