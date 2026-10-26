<!-- SPDX-License-Identifier: Apache-2.0 -->

# NetBox

Deploy [NetBox](https://github.com/netbox-community/netbox), the infrastructure
resource modeling and source-of-truth platform for DCIM and IPAM, using its
official container image.

## Features

- Official pinned NetBox/netbox-docker image for amd64 and arm64.
- Separate Granian web, RQ worker and housekeeping workloads.
- Maintained PostgreSQL and Redis dependencies plus external-service modes.
- Persistent media with fail-fast multi-replica storage validation.
- Generated, existing and External Secrets identity contracts.
- Ingress, Gateway API, dual-stack Service and product-aware NetworkPolicy.
- Native Prometheus metrics, ServiceMonitor and operational Helm tests.
- Configurable real Granian listener independent from the Service port.

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

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install netbox helmforge/netbox \
  --namespace netbox \
  --create-namespace \
  --wait
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

## Configuration

`containerPorts.http` configures the real Granian HTTP listener through the
server's `--port` command-line option. `service.port` independently controls
the Kubernetes Service-facing port and targets the named `http` container
port. The defaults are `8080` and `80`, respectively.

```yaml
containerPorts:
  http: 8181
service:
  port: 8080
```

This example makes NetBox listen on 8181 while clients connect to the Service
on 8080. Probes follow the named container port. Listener values below 1024 are
rejected because the application runs without root or added capabilities.

| Value | Default | Purpose |
| --- | ---: | --- |
| `containerPorts.http` | `8080` | Granian process listener |
| `service.port` | `80` | Kubernetes Service-facing port |
| `web.replicaCount` | `1` | NetBox web replicas |
| `worker.replicaCount` | `1` | RQ worker replicas |
| `persistence.enabled` | `true` | Persist uploaded media |
| `database.mode` | `auto` | Select bundled or external PostgreSQL |
| `cache.mode` | `auto` | Select bundled or external Redis |
| `networkPolicy.enabled` | `false` | Enable application traffic isolation |
| `networkPolicy.ingressFrom` | `[]` | Explicit HTTP ingress peers; empty permits IPv4 and IPv6 clients to the listener |

See [values.yaml](values.yaml) and [values.schema.json](values.schema.json) for
the complete validated contract.

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

## Security

All NetBox containers run without root or added capabilities, block privilege
escalation, use RuntimeDefault seccomp and receive no Kubernetes API token.
Application identity and credentials belong in retained Kubernetes Secrets or
External Secrets, never ConfigMaps. Restrict the bootstrap administrator,
terminate public traffic with HTTPS and treat Redis database 0 as a trusted
job-execution boundary.

NetworkPolicy is opt-in. When egress enforcement is enabled, explicitly allow
DNS, PostgreSQL, Redis and every private identity, email, webhook or plugin
destination. Enabling ingress isolation alone leaves egress unrestricted.

## Security Scan

### Security Scan: `netbox`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **85.43%** |

Security posture acceptable.

Local details:

- Tool: Kubescape v4.0.13
- Command: `kubescape scan framework mitre,nsa,soc2 .tmp/netbox-render.yaml`
- Result: 0 critical failed resources, resource summary score 85.43%.

## Examples

- [Simple](examples/simple.yaml)
- [External services](examples/external-services.yaml)
- [Production](examples/production.yaml)

## Troubleshooting

- If web startup is slow, inspect migration logs before restarting the pod.
- If workers remain in init, verify the web migration completed and PostgreSQL
  is reachable.
- If probes return HTTP 400, include the public hostname in
  `netbox.allowedHosts`; probes always send `Host: localhost`.
- If a custom listener fails, confirm the rendered Granian `--port` argument
  and the named `http` container port both match `containerPorts.http`.
- If multiple replicas are rejected, use ReadWriteMany media or an external
  media backend instead of bypassing the storage guard.

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
