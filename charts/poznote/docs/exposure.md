# Exposure

Poznote serves HTTP on port `80` by default through Nginx. The chart supports
Ingress and Gateway API for external access.

`containerPorts.http` controls the real Nginx listener through the upstream
`POZNOTE_LISTEN_PORT` environment variable. `service.port` controls the
client-facing Kubernetes Service and may be different because the Service
targets the named `http` container port.

```yaml
containerPorts:
  http: 8080
service:
  port: 80
```

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
