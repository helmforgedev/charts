# Apache Networking

The chart supports Kubernetes Service, Ingress, Gateway API, and NetworkPolicy.

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: apache.example.com
      paths:
        - path: /
          pathType: Prefix
```

## Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public-gateway
      namespace: gateway-system
  hostnames:
    - apache.example.com
```

## Dual-Stack Service

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

## NetworkPolicy

Enable NetworkPolicy when the cluster CNI enforces it:

```yaml
networkPolicy:
  enabled: true
  ingress:
    enabled: true
  egress:
    enabled: true
    allowDns: true
    allowInternet: false
```

When `allowInternet=true`, the chart allows both `0.0.0.0/0` and `::/0` so IPv4, IPv6, and dual-stack clusters behave consistently.
