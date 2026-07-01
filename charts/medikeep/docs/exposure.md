# Exposure

MediKeep serves HTTP on port `8000`. The chart exposes it through a ClusterIP Service by default.

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: medikeep.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: medikeep-tls
      hosts:
        - medikeep.example.com
```

## Gateway API

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - parentRefs:
        - name: public
          namespace: gateway-system
      hostnames:
        - medikeep.example.com
      rules:
        - matches:
            - path:
                type: PathPrefix
                value: /
```

Terminate TLS at the ingress controller or Gateway for normal Kubernetes deployments.
