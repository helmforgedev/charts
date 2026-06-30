# NoteDiscovery Exposure

The chart exposes NoteDiscovery through a Kubernetes Service and optionally through Ingress or Gateway API.

## Service

```yaml
service:
  type: ClusterIP
  port: 8000
```

Dual-stack settings are available through `service.ipFamilyPolicy` and `service.ipFamilies`.

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: notes.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: notediscovery-tls
      hosts:
        - notes.example.com
```

Set `notediscovery.allowedOrigins` to the public HTTPS origin:

```yaml
notediscovery:
  allowedOrigins:
    - https://notes.example.com
```

## Gateway API

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - hostnames:
        - notes.example.com
      parentRefs:
        - name: public
          namespace: gateway-system
      path: /
      pathType: PathPrefix
```

Each `httpRoutes` item renders one HTTPRoute. Set `rules` for advanced Gateway API routing when the default path-to-service route is not enough.
