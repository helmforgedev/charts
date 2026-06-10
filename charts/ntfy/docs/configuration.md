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
