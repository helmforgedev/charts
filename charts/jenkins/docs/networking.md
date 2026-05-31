# Jenkins Networking

The chart exposes the controller HTTP port and, optionally, the inbound agent
TCP port on the same Service.

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: jenkins.example.com
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
    - jenkins.example.com
```

## Agents

Disable the inbound agent listener when all builds use web socket agents or
Kubernetes plugin agents:

```yaml
agent:
  enabled: false
```

## Dual-Stack Service

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```
