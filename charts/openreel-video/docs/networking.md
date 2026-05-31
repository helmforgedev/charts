# Networking

The chart exposes OpenReel Video through a ClusterIP Service by default.

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: openreel.example.com
      paths:
        - path: /
          pathType: Prefix
```

## Gateway API

`gateway.enabled` renders one HTTPRoute. `gateway.parentRefs` is required.

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public
      namespace: gateway-system
  hostnames:
    - openreel.example.com
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
title: OpenReel Video Networking
description: Service, Ingress, Gateway API, and dual-stack configuration for OpenReel Video
keywords: openreel-video, networking, ingress, gateway-api, dual-stack
purpose: Explain networking options
scope: Chart Operations
relations:
  - charts/openreel-video/README.md
  - charts/openreel-video/examples/gateway.yaml
path: charts/openreel-video/docs/networking.md
version: 1.0
date: 2026-05-29
-->
