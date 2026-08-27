# NetBox

Deploy [NetBox](https://github.com/netbox-community/netbox), the infrastructure
resource modeling and source-of-truth platform for DCIM and IPAM, using its
official container image.

## Architecture

The chart models NetBox as three independent Kubernetes workloads:

- a web Deployment running the official Granian WSGI entrypoint;
- an RQ worker Deployment for asynchronous jobs;
- a nightly CronJob for the upstream `housekeeping` command.

PostgreSQL stores authoritative application data. Redis database 0 carries
trusted background jobs and database 1 is used for cache. User-uploaded media
is kept on a separate PVC. The default installation deploys HelmForge
PostgreSQL and Redis subcharts. Authentication is mandatory, matching the
NetBox 4.6 security model.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install netbox helmforge/netbox --namespace netbox --create-namespace
```

Retrieve the generated initial password:

```bash
kubectl get secret -n netbox netbox-superuser \
  -o jsonpath='{.data.password}' | base64 -d
```

Then forward the Service and open `http://127.0.0.1:8080/`:

```bash
kubectl port-forward -n netbox svc/netbox 8080:80
```

## Production decisions

Use existing Secrets or External Secrets for the Django secret, API-token
pepper, database password, Redis password, and bootstrap credentials. Disable
the bootstrap superuser after provisioning. Restrict `allowedHosts`, terminate
TLS at an Ingress or Gateway, and enable network policy and metrics.

Web replicas share media. More than one web replica is rejected unless the PVC
declares `ReadWriteMany`; object-storage configuration can instead be supplied
through `netbox.extraConfiguration`. Back up PostgreSQL and media as two
coordinated domains. Redis cache is rebuildable, while the task database can
contain pending jobs and must not be exposed to untrusted writers.

See [production operations](docs/production.md),
[secrets](docs/secrets.md), and [networking and observability](docs/networking.md).

## External services

Disable the bundled dependencies and reference existing credentials:

```yaml
postgresql:
  enabled: false
redis:
  enabled: false
database:
  mode: external
  external:
    host: postgresql.database.svc
    existingSecret: netbox-postgresql
cache:
  mode: external
  external:
    host: redis.cache.svc
    existingSecret: netbox-redis
```

The PostgreSQL Secret key defaults to `password`; the Redis Secret key also
defaults to `password`.

## Custom configuration and plugins

The official image loads Python files from `/etc/netbox/config`. Add settings
that are not represented by upstream environment variables through
`netbox.extraConfiguration`. Plugins must be installed in a derived image; the
chart never downloads executable packages at pod startup.

```yaml
image:
  repository: registry.example.com/platform/netbox
  tag: "4.6.5-company.1"
netbox:
  extraConfiguration:
    plugins.py: |
      PLUGINS = ["netbox_topology_views"]
```

## Routing

Ingress uses `ingress.ingressClassName`. Gateway API uses the canonical
`gatewayAPI.httpRoutes[]` contract and defaults each route to the NetBox
Service when no backend is supplied.

## Observability

Set both `netbox.metricsEnabled=true` and
`metrics.serviceMonitor.enabled=true`. The ServiceMonitor scrapes `/metrics`.
Web and worker logs remain on standard output. Probes call `/login/`, which
also verifies database-backed Django startup.

## Security Scan

### Security Scan: `netbox`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **85.42568%** |

Security posture acceptable.

Local details:

- Tool: Kubescape v4.0.9
- Command: `kubescape scan framework mitre,nsa,soc2 .tmp/netbox-render.yaml`
- Result: 0 critical failed resources, resource summary score 85.42568%.

## Examples

- [Simple](examples/simple.yaml)
- [External services](examples/external-services.yaml)
- [Production](examples/production.yaml)

## Scope boundaries

This chart deploys NetBox and its standard operational processes. It does not
install arbitrary plugins at runtime, create external databases, provision
object-storage buckets, or claim database-level high availability when the
standalone dependency defaults are used.

<!-- @AI-METADATA
type: chart-readme
title: NetBox Chart
description: Production-ready NetBox chart
keywords: netbox, dcim, ipam, kubernetes
purpose: NetBox chart usage and operations
scope: Chart
relations:
  - charts/netbox/Chart.yaml
  - charts/netbox/values.yaml
path: charts/netbox/README.md
version: 1.0
date: 2026-07-31
-->
