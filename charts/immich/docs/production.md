# Production

Immich is stateful. Treat uploads, PostgreSQL, and cache persistence as data
services with explicit backup and restore runbooks.

Use [examples/production.yaml](../examples/production.yaml) as a starting point.

## Baseline

- Keep `server.persistence.enabled=true` with durable storage.
- Use `ReadWriteMany` before enabling server autoscaling or replicas greater
  than one.
- Provide PostgreSQL and cache credentials through existing Secrets or External
  Secrets.
- Configure HTTPS through Ingress or Gateway API.
- Size machine-learning resources for the selected model workload.
- Validate backup and restore for uploads and PostgreSQL outside the chart.

## Scaling

The chart fails rendering when upload persistence is enabled and server replicas
or autoscaling are used without `ReadWriteMany` access modes. This prevents
multiple server pods from writing to a single `ReadWriteOnce` volume.

## Validation

```bash
helm test immich -n immich
kubectl get events -n immich --sort-by=.lastTimestamp
kubectl logs -n immich deploy/immich --since=10m
```

<!-- @AI-METADATA
type: chart-docs
title: Immich Production
description: Production deployment guidance for the Immich Helm chart
keywords: immich, production, persistence, postgresql, valkey
purpose: Production hardening guide for Immich
scope: Chart Operations
relations:
  - charts/immich/README.md
  - charts/immich/examples/production.yaml
path: charts/immich/docs/production.md
version: 1.0
date: 2026-05-29
-->
