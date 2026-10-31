# Kibana Production Guide

## Upgrade preparation

Chart 1.2 upgrades the bundled Elasticsearch dependency to 2.x. Migrate custom
`bundled-elasticsearch.resources` values to
`bundled-elasticsearch.master.resources` before upgrading and review the
dependency's storage and security contracts. Retained `service.targetPort:
http` remains compatible, as does a retained integer or string target equal to
`containerPorts.http`. A divergent legacy target must be replaced by the real
Kibana listener.

Do not upgrade from chart 1.1.x with `--reuse-values` alone. With Helm 3.14 or
later, use
`helm upgrade RELEASE helmforge/kibana --reset-then-reuse-values --dry-run`
to preview the release with defaults for newly introduced parent maps such as
`networkPolicy`, then repeat the command without `--dry-run`. With Helm 3.13 or
earlier, export the release overrides with
`(umask 077 && helm get values RELEASE -o yaml > retained-values.yaml)` so the
file is created with owner-only permissions, then preview with
`helm upgrade RELEASE helmforge/kibana --reset-values -f retained-values.yaml --dry-run`,
then repeat that command without `--dry-run`. Dry-run output can contain
rendered Kubernetes Secrets; keep it in a trusted environment and out of logs.
Use an equivalent owner-only creation method on non-POSIX systems and remove
`retained-values.yaml` immediately after the upgrade.

Use production deployments with explicit Elasticsearch authentication, TLS, and
stable encryption keys.

```yaml
replicaCount: 2

elasticsearch:
  hosts:
    - https://elasticsearch:9200
  auth:
    type: serviceAccountToken
    existingSecret: kibana-elasticsearch-token
  tls:
    enabled: true
    certificateAuthoritiesSecret: elasticsearch-ca
    verificationMode: certificate

encryptionKeys:
  existingSecret: kibana-encryption-keys

networkPolicy:
  enabled: true
```

## Encryption Keys

Kibana uses encryption keys for sessions, reporting, and encrypted saved
objects. Multi-replica deployments must use stable keys through
`encryptionKeys.existingSecret` or static values.

## Authentication

Use `serviceAccountToken` for Elastic Stack service account authentication when
available. Basic auth is also supported for environments that still use the
`kibana_system` user.

## Operations

After deployment:

```bash
helm test kibana -n observability
kubectl get pods -n observability -l app.kubernetes.io/name=kibana
kubectl logs -n observability deploy/kibana
```
