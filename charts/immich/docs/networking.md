# Networking

The chart exposes the Immich server through a ClusterIP Service by default.

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: immich.example.com
      paths:
        - path: /
          pathType: Prefix
```

## Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public
      namespace: gateway-system
  hostnames:
    - immich.example.com
```

## Dual Stack

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

<!-- @AI-METADATA
type: chart-docs
title: Immich Networking
description: Service, Ingress, Gateway API, and dual-stack configuration for Immich
keywords: immich, networking, ingress, gateway-api, dual-stack
purpose: Explain networking options
scope: Chart Operations
relations:
  - charts/immich/README.md
  - charts/immich/examples/gateway.yaml
path: charts/immich/docs/networking.md
version: 1.0
date: 2026-05-29
-->
