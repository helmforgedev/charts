# Exposure

BookLore can be exposed externally using either Kubernetes Ingress or Gateway API.

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: books.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: booklore-tls
      hosts:
        - books.example.com
```

## Gateway API

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - parentRefs:
        - name: main-gateway
          namespace: gateway-system
      hostnames:
        - books.example.com
```
