# Metabase Production Guide

## Recommended Values

```yaml
metabase:
  siteUrl: https://metabase.example.com
  existingSecret: metabase-secrets
  existingSecretKey: encryption-secret-key
  javaOpts: "-Xmx2g -Xms1g"

ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: metabase.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: metabase-tls
      hosts:
        - metabase.example.com

resources:
  requests:
    cpu: 500m
    memory: 2Gi
  limits:
    cpu: "2"
    memory: 3Gi
```

## Health Checks

Metabase exposes `/api/health`. After rollout:

```bash
kubectl port-forward -n <namespace> svc/<release>-metabase 3000:80
curl -f http://127.0.0.1:3000/api/health
```

## JVM Sizing

Use `metabase.javaOpts` with memory requests/limits that leave headroom for JVM overhead. Keep `-Xmx` lower than the
container memory limit.

## External Secrets

For production, prefer an existing Secret or ExternalSecret for `MB_ENCRYPTION_SECRET_KEY` and external database
credentials:

```yaml
metabase:
  existingSecret: metabase-secrets

externalSecrets:
  enabled: true
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  data:
    - secretKey: encryption-secret-key
      remoteRef:
        key: metabase/credentials
        property: encryption-secret-key
```

## Operational Checks

- Confirm pods are Ready with zero restarts.
- Check Metabase and PostgreSQL logs after upgrades.
- Confirm there are no non-normal Kubernetes events.
- Verify `/api/health` returns HTTP 200.
- Run and restore a database backup in a non-production namespace.

<!-- @AI-METADATA
type: chart-doc
title: Metabase Production Guide
description: Production operations guide for the Metabase Helm chart

keywords: metabase, production, ingress, health, jvm, external-secrets, helm, kubernetes

purpose: Document production values, health checks, JVM sizing, secret handling, and operational validation
scope: Chart Documentation

relations:
  - charts/metabase/README.md
  - charts/metabase/DESIGN.md
  - charts/metabase/docs/database.md
path: charts/metabase/docs/production.md
version: 1.0
date: 2026-06-02
-->
