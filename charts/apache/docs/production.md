# Apache Production Guide

Use this chart in production with explicit values for content, routing,
resources, and security boundaries.

## Recommended Settings

```yaml
replicaCount: 3

content:
  existingConfigMap: apache-site-content

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 1
    memory: 512Mi

pdb:
  enabled: true
  minAvailable: 1

networkPolicy:
  enabled: true
  egress:
    enabled: true
    allowDns: true
    allowInternet: false
```

## Authentication

Basic Auth is optional and expects an htpasswd file in a Secret:

```yaml
basicAuth:
  enabled: true
  existingSecret: apache-basicauth
  htpasswdKey: htpasswd
```

For GitOps, use `externalSecrets.enabled=true` to materialize that Secret from
your configured provider.

## Operational Checks

After deployment:

```bash
helm test apache -n apache
kubectl get pods -n apache -l app.kubernetes.io/name=apache
kubectl logs -n apache deploy/apache
```

The chart exposes `/healthz` for probes and Helm tests.
