# Exposure

Poznote serves HTTP on port `80` by default (nginx). The chart supports Ingress and Gateway API for external access.

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: notes.example.com
  tls:
    - secretName: notes-tls
      hosts:
        - notes.example.com
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
        - notes.example.com
```

## Port Forwarding

For local access without Ingress or Gateway API:

```bash
kubectl port-forward svc/<release>-poznote 8080:80
```
