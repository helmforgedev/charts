# Production

The default values are suitable for local and preview environments. Production
deployments should use an explicit values file with stable credentials, storage,
network boundaries, and public URL settings.

Use [examples/production.yaml](../examples/production.yaml) as a starting point.

## Required Decisions

- Set `opencut.siteUrl` to the public HTTPS URL.
- Set `opencut.betterAuthSecret` from a secret generator and keep it stable.
- Decide whether the release owns PostgreSQL and Redis or consumes platform
  services.
- Set persistence sizes and storage classes for bundled dependencies.
- Set CPU and memory resources for OpenCut and the Redis HTTP bridge.
- Enable `networkPolicy.enabled=true` once namespace traffic requirements are
  known.

## Secrets

Prefer existing Kubernetes Secrets or External Secrets over inline passwords:

```yaml
postgresql:
  auth:
    existingSecret: opencut-postgresql-auth
    existingSecretUserPasswordKey: user-password

redis:
  auth:
    enabled: true
    existingSecret: opencut-redis-auth
    existingSecretPasswordKey: redis-password
```

For external PostgreSQL, set `database.external.existingSecret`. The chart can
also render an `ExternalSecret` when External Secrets Operator is already
installed in the cluster.

## Networking

Expose OpenCut with either Ingress or Gateway API, not both for the same host.
The chart does not install controllers or CRDs.

Ingress example:

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: opencut.example.com
      paths:
        - path: /
          pathType: Prefix
```

Gateway API example:

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public
      namespace: gateway-system
  hostnames:
    - opencut.example.com
```

## Validation

After install or upgrade:

```bash
helm test opencut -n opencut
kubectl get events -n opencut --sort-by=.lastTimestamp
kubectl logs -n opencut deploy/opencut --since=10m
```

<!-- @AI-METADATA
type: chart-docs
title: OpenCut Production
description: Production deployment guidance for the OpenCut Helm chart
keywords: opencut, production, secrets, ingress, gateway-api
purpose: Production hardening guide for OpenCut
scope: Chart Operations
relations:
  - charts/opencut/README.md
  - charts/opencut/examples/production.yaml
path: charts/opencut/docs/production.md
version: 1.0
date: 2026-05-29
-->
