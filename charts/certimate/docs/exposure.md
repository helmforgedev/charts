# Certimate Exposure

Certimate serves HTTP on port `8090`. Terminate TLS at your Ingress controller or Gateway.

Ingress example:

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: certs.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: certimate-tls
      hosts:
        - certs.example.com
```

Gateway API example:

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - parentRefs:
        - name: public
          namespace: gateway-system
      hostnames:
        - certs.example.com
```

After exposing the service, rotate the upstream default administrator credentials and restrict access to trusted operators.
