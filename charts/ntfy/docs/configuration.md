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
