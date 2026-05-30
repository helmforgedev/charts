# Kibana Networking

The chart supports Service, Ingress, Gateway API, dual-stack Service fields,
and NetworkPolicy.

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: kibana.example.com
      paths:
        - path: /
          pathType: Prefix
```

## Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: shared-gateway
      namespace: gateway-system
  hostnames:
    - kibana.example.com
```

## Dual-Stack Service

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```
