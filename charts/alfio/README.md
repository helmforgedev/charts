# alf.io Helm Chart

Deploy [alf.io](https://alf.io) on Kubernetes using the official [alfio/alf.io](https://hub.docker.com/r/alfio/alf.io) container image. Open-source event management and ticketing platform for conferences, meetups, and exhibitions.

## Features

- **Event ticketing** — full-featured ticketing with check-in, invoicing, and attendee management
- **PostgreSQL backend** — bundled subchart or external database
- **Spring Boot** — configurable Spring profiles and environment variables
- **Wait-for-db** — init container ensures database is ready before app starts
- **Health checks** — HTTP probes on `/healthz` endpoint
- **Ingress support** — TLS with cert-manager, traefik or nginx

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install alfio helmforge/alfio -f values.yaml
```

**OCI registry:**

```bash
helm install alfio oci://ghcr.io/helmforgedev/helm/alfio -f values.yaml
```

## Basic Example

```yaml
# values.yaml — default values deploy with bundled PostgreSQL
alfio:
  baseUrl: "https://tickets.example.com"
```

After deploying, access alf.io:

```bash
kubectl port-forward svc/<release>-alfio 8080:80
# Open http://localhost:8080
# Default admin credentials are created on first boot
```

## External PostgreSQL

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    name: alfio
    username: alfio
    existingSecret: alfio-db-credentials
```

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik  # or nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    - host: tickets.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - tickets.example.com
      secretName: alfio-tls
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `alfio.baseUrl` | `""` | Public URL of the alf.io instance |
| `alfio.profiles` | `"dev"` | Spring profiles (`dev` or `spring-boot` for production) |
| `postgresql.enabled` | `true` | Deploy PostgreSQL subchart |
| `ingress.enabled` | `false` | Enable ingress |
| `service.port` | `80` | Service port |
| `probes.startup.initialDelaySeconds` | `15` | Startup probe initial delay (JVM warm-up) |

## Limitations

- **Single instance** — alf.io does not support horizontal scaling out of the box
- **PostgreSQL only** — alf.io requires PostgreSQL as the database backend

## More Information

- [alf.io documentation](https://alf.io/docs)
- [alf.io GitHub](https://github.com/alfio-event/alf.io)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/alfio)

<!-- @AI-METADATA
type: chart-readme
title: alf.io Helm Chart
description: README for the alf.io event management and ticketing platform Helm chart

keywords: alfio, ticketing, events, conference, postgresql

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/alfio/values.yaml
path: charts/alfio/README.md
version: 1.0
date: 2026-04-03
-->
