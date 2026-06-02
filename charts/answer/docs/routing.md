# Routing

Apache Answer can be exposed with Kubernetes Ingress or Gateway API.

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: qa.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: answer-tls
      hosts:
        - qa.example.com
```

Set `answer.siteUrl` to the final public URL when the route is exposed through a proxy or load balancer.

## Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public-gateway
      namespace: gateway-system
  hostnames:
    - qa.example.com
```

The chart renders an `HTTPRoute` only when Gateway API is enabled. It does not install Gateway API CRDs or create Gateway resources.

## Dual-Stack Services

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

Leave these values empty to use the cluster default.

<!-- @AI-METADATA
type: chart-docs
title: Routing
description: Ingress, Gateway API, and service dual-stack configuration for Apache Answer

keywords: answer, routing, ingress, gateway-api, dual-stack

purpose: Help operators expose Apache Answer through Kubernetes routing primitives
scope: Chart

relations:
  - charts/answer/README.md
  - charts/answer/values.yaml
path: charts/answer/docs/routing.md
version: 1.0
date: 2026-06-02
-->
