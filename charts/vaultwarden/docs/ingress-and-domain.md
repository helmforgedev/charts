# Ingress and Domain

## Why it matters

Vaultwarden relies on a correct public domain for features such as attachment links and client-facing URLs.

## Recommended pattern

- set `domain` to the external HTTPS URL
- enable ingress with the same hostname
- terminate TLS at ingress or reverse proxy

## Example

```yaml
domain: https://vaultwarden.example.com

ingress:
  enabled: true
  ingressClassName: traefik
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    - host: vaultwarden.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - vaultwarden.example.com
      secretName: vaultwarden-tls
```

## WebSocket note

WebSocket notifications use the same HTTP service and ingress path in this chart. No separate websocket service is required in v1.
