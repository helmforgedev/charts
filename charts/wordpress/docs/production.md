# Production Guide

This chart can be used in development and production, but production requires explicit choices. The default values are intentionally small and convenient.

## Recommended Production Baseline

```yaml
wordpress:
  siteUrl: https://blog.example.com
  forceSSLAdmin: true
  disallowFileEdit: true
  disableWpCron: true
  memoryLimit: 256M
  maxMemoryLimit: 512M

wpCron:
  cronJob:
    enabled: true

resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: "1"
    memory: 1Gi

networkPolicy:
  enabled: true
  metrics:
    enabled: true
  egress:
    enabled: true
    allowDNS: true
    allowHTTPS: true

metrics:
  enabled: true

backup:
  enabled: true
```

## Storage

With `persistence.accessMode: ReadWriteOnce`, keep a single WordPress pod.
Use ReadWriteMany storage or an object-storage media strategy before enabling HPA or replicas greater than one.

## Database

For production, prefer one of these patterns:

- External managed MySQL/MariaDB with automated backups and failover.
- A separately operated database release with tested backup, restore, monitoring, and upgrade procedures.
- HelmForge MySQL subchart for smaller environments where the operational tradeoff is acceptable.

## Secrets

Use `admin.existingSecret`, `database.external.existingSecret`, and `backup.s3.existingSecret` for simple clusters.
Use `externalSecrets` when the cluster runs External Secrets Operator and credentials are managed in an external store.

## Routing

Use either Ingress or Gateway API. Do not enable both for the same hostname unless you intentionally want two routing paths.

## NetworkPolicy

Enable `networkPolicy.enabled` to isolate inbound traffic.
Enable `networkPolicy.egress.enabled` only after listing required destinations such as DNS, database, HTTPS APIs,
object storage, and SMTP.

<!-- @AI-METADATA
type: chart-docs
title: WordPress Production Guide
description: Production deployment guidance for the WordPress Helm chart
keywords: wordpress, production, kubernetes, helm, gateway-api, external-secrets, networkpolicy
purpose: Production hardening guide for the wordpress Helm chart
scope: Chart
relations:
  - charts/wordpress/README.md
  - charts/wordpress/DESIGN.md
  - charts/wordpress/values.yaml
path: charts/wordpress/docs/production.md
version: 1.0
date: 2026-05-06
-->
