# Jenkins External Secrets

The chart can render an ExternalSecret for the Jenkins initial admin Secret.
Set `admin.existingSecret` so the workload and ExternalSecret agree on the
same target Secret.

```yaml
admin:
  existingSecret: jenkins-admin

externalSecrets:
  enabled: true
  secretStoreRef:
    name: cluster-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: jenkins-admin-user
      remoteRef:
        key: jenkins/admin
        property: username
    - secretKey: jenkins-admin-password
      remoteRef:
        key: jenkins/admin
        property: password
```

Use `dataFrom` when your provider can extract all keys from a single remote
object:

```yaml
externalSecrets:
  enabled: true
  dataFrom:
    - extract:
        key: jenkins/admin
```
