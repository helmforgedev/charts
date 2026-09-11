# Memos Security

## Container Identity

The official image runs as non-root UID/GID `10001`. The chart sets:

```yaml
podSecurityContext:
  fsGroup: 10001
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
```

The data PVC must be writable by this identity.

The image filesystem is read-only. A dedicated temporary volume supports runtime operations. The initial administrator
is created by the unchanged Memos binary listening only on loopback inside the init container; the public process never
mounts the initial password. Existing accounts and passwords are preserved during adoption and upgrade.

## ServiceAccount

The chart does not create or mount a ServiceAccount token by default:

```yaml
serviceAccount:
  create: false
  automountServiceAccountToken: false
```

Memos does not need Kubernetes API access for normal operation.

## Database Secrets

Prefer `database.existingSecret` for production so credentials are managed outside Helm release values.

External components can instead use `database.passwordSecret`. Their runtime-built DSN is stored in a memory volume with
mode `0600`, not in ConfigMaps or container arguments. Certificate verification is enabled for external component
connections by default. Existing full DSNs retain the TLS policy chosen by their owner.

```yaml
database:
  driver: postgres
  existingSecret: memos-postgres
  existingSecretKey: dsn
```

## Webhooks

`memos.allowPrivateWebhooks` defaults to false. Enabling it allows webhook URLs that resolve to private or reserved IP
ranges. Only use it when the targets are trusted internal services and egress is controlled.

## Deployment Configuration Secrets

Use `provisioning.existingSecret` for OAuth2 client secrets, SMTP credentials, S3 credentials, and AI provider keys that
Memos 0.30 loads from `/etc/secrets`. The chart mounts the Secret read-only with group-readable mode `0440` for the
non-root container.

Treat every matching JSON file as sensitive plaintext. Do not place provisioning JSON directly in Helm values, logs, or
ConfigMaps. Memos rejects invalid files before serving traffic, redacts secret fields from APIs, and keeps file-backed
resources immutable until the file is removed and the pod restarts.

## NetworkPolicy

NetworkPolicy is enabled by default and requires a compatible CNI. Add your ingress-controller peers:

```yaml
networkPolicy:
  enabled: true
  ingressFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-system
```
