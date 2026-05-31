# Jenkins Production Guide

Use explicit values for persistence, credentials, plugin pinning, resources,
and network boundaries.

```yaml
persistence:
  enabled: true
  size: 100Gi

admin:
  create: true
  existingSecret: jenkins-admin

resources:
  requests:
    cpu: 1
    memory: 2Gi
  limits:
    cpu: 4
    memory: 6Gi

networkPolicy:
  enabled: true
  egress:
    enabled: true
    allowDns: true
    allowInternet: true
```

## Credentials

Prefer `admin.existingSecret` or `externalSecrets.enabled=true` for production.
This avoids chart-generated credentials changing during GitOps reconciliation.

## Plugins

Pin plugin versions in `plugins.install.list`. Avoid `latest=true` in
production unless upgrades are intentionally tested in a staging environment.

## Operations

After deployment:

```bash
helm test jenkins -n jenkins
kubectl get pods -n jenkins -l app.kubernetes.io/name=jenkins
kubectl logs -n jenkins statefulset/jenkins
```
