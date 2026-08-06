# ntfy Configuration

ntfy needs a stable public URL when clients connect through Ingress or Gateway API.

## Public URL

```yaml
ntfy:
  baseUrl: "https://ntfy.example.com"
```

This value should match the URL used by browsers, mobile apps, and scripts.

## Authentication

For private deployments, deny unauthenticated access and create users with the ntfy CLI:

```yaml
ntfy:
  authDefaultAccess: "deny-all"
```

After deployment:

```bash
kubectl exec -it deploy/<release>-ntfy -- ntfy user add --role=admin admin
```

## Metrics

```yaml
ntfy:
  enableMetrics: true

metrics:
  serviceMonitor:
    enabled: true
```

`ServiceMonitor` requires Prometheus Operator CRDs to exist in the cluster.

## PostgreSQL

ntfy can use PostgreSQL for its message cache, access control, and web push
subscriptions. The connection URL is read from an existing Kubernetes Secret
and is never stored in the ConfigMap:

```yaml
ntfy:
  database:
    enabled: true
    existingSecret: ntfy-database
    existingSecretKey: database-url

persistence:
  enabled: false
```

The Secret must contain a `database-url` key with a PostgreSQL connection URL.
When PostgreSQL is enabled, the chart omits `cache-file`, `auth-file`, and
`web-push-file`, as required by ntfy.

Disabling persistence is appropriate only when no local file-backed features
need durable storage. Keep it enabled for filesystem attachments, the ban-feed,
or custom configuration that writes beneath `/var/cache/ntfy`.

PostgreSQL does not by itself make the chart highly available. The chart keeps
one replica, and local filesystem attachments are not shared.

## External Secrets

Use External Secrets Operator to reconcile the database Secret from a provider:

```yaml
ntfy:
  database:
    enabled: true
    existingSecret: ntfy-database

externalSecrets:
  enabled: true
  refreshInterval: 1h
  items:
    - fullnameOverride: ntfy-database
      spec:
        secretStoreRef:
          name: production-secrets
          kind: ClusterSecretStore
        target:
          name: ntfy-database
        data:
          - secretKey: database-url
            remoteRef:
              key: ntfy/database
              property: url
```

See the [External Secrets Operator documentation](https://external-secrets.io/latest/)
for provider setup.

Secret rotation does not update `NTFY_DATABASE_URL` inside a running pod because
Kubernetes injects environment variables only when containers start. Trigger a
Deployment rollout after rotation, or use a compatible restart controller that
restarts the workload when the target Secret changes.

## Abuse Ban-Feed

ntfy 2.26.3 can emit confirmed abusive visitors to a file consumed by fail2ban
or equivalent enforcement:

```yaml
ntfy:
  banFeed:
    enabled: true
    file: /var/cache/ntfy/ban.log
    window: 10m
    threshold: 100
    weights:
      - "42909:10"
```

The default path is on the chart's writable data volume. Configure an external
consumer and rotate the file with copy-truncate semantics. The chart does not
install fail2ban or modify node firewall rules.

## Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public
      namespace: gateway-system
  hostnames:
    - ntfy.example.com
```

## Dual Stack Service

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```
