<!-- SPDX-License-Identifier: Apache-2.0 -->
# Automatisch Helm Chart

Deploy [Automatisch](https://automatisch.io), an open-source business
automation platform, on Kubernetes with the official
[`automatischio/automatisch`](https://hub.docker.com/r/automatischio/automatisch)
image. The chart provides the required web and worker processes and supports
bundled or external PostgreSQL and Redis.

## Features

- Separate web and worker Deployments using the supported upstream process model.
- Official, pinned Automatisch image with a configurable HTTP listener.
- HelmForge PostgreSQL and Redis subcharts enabled by default.
- External PostgreSQL and Redis configuration for production platforms.
- Stable generated application keys preserved across Helm upgrades.
- Ingress, resource, scheduling, ServiceAccount, and extra-manifest controls.
- Restricted inbound NetworkPolicy with integration-friendly outbound access.
- Non-root containers, read-only root filesystems, dropped capabilities,
  runtime-default seccomp, and disabled service account token mounts.
- Startup, readiness, and liveness probes for the web process.
- Unit, schema, static, and k3d behavioral validation in the HelmForge gates.

## Architecture

Automatisch requires two processes from the same image. The web Deployment
runs migrations and serves the API and UI. The worker Deployment sets
`WORKER=true` and consumes queued workflow executions from Redis. Both use the
same PostgreSQL database and cryptographic keys. The Kubernetes Service selects
only the web pods, so HTTP traffic cannot be routed to workers.

PostgreSQL contains workflows, connections, encrypted credentials, and
execution history. Redis carries the job queue. The application Secret contains
the stable encryption, session, and webhook keys. See [DESIGN.md](DESIGN.md) for
the complete boundary and decision record.

## Installation

Install from the HTTPS repository:

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install automatisch helmforge/automatisch --namespace automatisch --create-namespace
```

Or install from OCI:

```bash
helm install automatisch oci://ghcr.io/helmforgedev/helm/automatisch \
  --namespace automatisch \
  --create-namespace
```

Inspect every value before production use:

```bash
helm show values helmforge/automatisch
```

## Configuration Example

The default values are suitable for evaluation and deploy bundled PostgreSQL
and Redis. Set the public URL and explicit resources for a durable environment:

```yaml
automatisch:
  webAppUrl: https://automatisch.example.com
  containerPorts:
    http: 3000

worker:
  enabled: true
  replicaCount: 2
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      memory: 512Mi

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    memory: 512Mi

ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: automatisch.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - automatisch.example.com
      secretName: automatisch-tls
```

Changing `automatisch.containerPorts.http` changes both the container port and
the upstream `PORT` environment variable. It does not change `service.port`,
which is the client-facing Service port.

## External PostgreSQL and Redis Example

Disable the bundled subcharts when using managed datastores. PostgreSQL
credentials should be supplied through an existing Secret:

```yaml
postgresql:
  enabled: false

redis:
  enabled: false

database:
  external:
    host: postgres.example.com
    port: "5432"
    name: automatisch
    username: automatisch
    existingSecret: automatisch-db-credentials
    existingSecretPasswordKey: password

redis_config:
  external:
    host: redis.example.com
    port: "6379"
    existingSecret: automatisch-redis-credentials
    existingSecretPasswordKey: password
```

Create both referenced Secrets before installation. Supply secure values that
match the external services rather than copying a placeholder:

```bash
read -rsp 'PostgreSQL password: ' POSTGRES_PASSWORD && echo
kubectl create secret generic automatisch-db-credentials \
  --namespace automatisch \
  --from-literal=password="$POSTGRES_PASSWORD"
unset POSTGRES_PASSWORD

read -rsp 'Redis password: ' REDIS_PASSWORD && echo
kubectl create secret generic automatisch-redis-credentials \
  --namespace automatisch \
  --from-literal=password="$REDIS_PASSWORD"
unset REDIS_PASSWORD
```

The chart rejects an external database without a host or password source and
rejects an external Redis configuration without a host.

## Security

By default, web and worker containers run as UID/GID 1000, privilege escalation
is disabled, all Linux capabilities are dropped, the root filesystem is
read-only, and runtime-default seccomp is enabled. Pods do not receive
Kubernetes API tokens by default. Operators can override these settings; the
bundled datastore charts retain their own security contracts.

The default NetworkPolicy accepts inbound traffic only on the named HTTP port.
Outbound traffic remains open because workflows must reach arbitrary external
integration APIs. Restrictive environments can replace `networkPolicy.egress`
with explicit DNS, PostgreSQL, Redis, proxy, and destination rules.

The generated application Secret must be backed up. Changing
`ENCRYPTION_KEY`, `APP_SECRET_KEY`, or `WEBHOOK_SECRET_KEY` after data exists can
invalidate stored credentials, sessions, or webhook verification. Kubernetes
Secret encryption at rest and least-privilege RBAC remain cluster operator
responsibilities. See [docs/security.md](docs/security.md).

## Operations

The web process performs database migrations during startup, so the chart keeps
one web replica. Scale workflow capacity through `worker.replicaCount`. Back up
PostgreSQL and the application Secret together, monitor Redis capacity, and
test restore procedures outside production.

With Ingress disabled, access the UI through a port-forward:

```bash
kubectl port-forward --namespace automatisch svc/automatisch-automatisch 3000:80
```

Review application and worker status separately:

```bash
kubectl get pods --namespace automatisch \
  -l app.kubernetes.io/instance=automatisch
kubectl logs --namespace automatisch deployment/automatisch-automatisch
kubectl logs --namespace automatisch deployment/automatisch-automatisch-worker
```

For backup, upgrade, and recovery guidance, see
[docs/operations.md](docs/operations.md). For every value and deployment mode,
see [docs/configuration.md](docs/configuration.md).

## Troubleshooting

If the web pod remains in `Init`, inspect PostgreSQL readiness and the
`wait-for-db` init container. If the UI is ready but workflows do not execute,
inspect the worker Deployment and Redis connectivity. A worker must contain
`WORKER=true`; the chart sets it automatically.

If a custom listener port is unreachable, confirm that `PORT`,
`containerPort`, and the named Service target all reflect
`automatisch.containerPorts.http`:

```bash
kubectl get deployment automatisch-automatisch --namespace automatisch -o yaml
kubectl get service automatisch-automatisch --namespace automatisch -o yaml
```

For upgrade failures, inspect web logs for migration errors before rolling
back. Restore PostgreSQL and the matching application Secret as one recovery
unit when encrypted credentials are involved.

## Key Values

| Key | Default | Description |
|---|---:|---|
| `image.repository` | `docker.io/automatischio/automatisch` | Official image repository. |
| `image.tag` | `0.15.0` | Pinned Automatisch image tag. |
| `automatisch.webAppUrl` | `http://localhost:3000` | Public application URL. |
| `automatisch.host` | `0.0.0.0` | HTTP bind address inside the pod. |
| `automatisch.appEnv` | `production` | Application environment. |
| `automatisch.containerPorts.http` | `3000` | HTTP listener and `PORT` value. |
| `automatisch.extraEnv` | `[]` | Extra environment variables for web and worker. |
| `worker.enabled` | `true` | Run the required background worker. |
| `worker.replicaCount` | `1` | Number of worker replicas. |
| `worker.resources` | `{}` | Worker resource requests and limits. |
| `postgresql.enabled` | `true` | Deploy the HelmForge PostgreSQL subchart. |
| `redis.enabled` | `true` | Deploy the HelmForge Redis subchart. |
| `database.external.host` | `""` | External PostgreSQL host. |
| `database.external.existingSecret` | `""` | Secret containing the database password. |
| `redis_config.external.host` | `""` | External Redis host. |
| `redis_config.external.existingSecret` | `""` | Secret containing the external Redis password. |
| `service.port` | `80` | Client-facing Service port. |
| `ingress.enabled` | `false` | Create an Ingress. |
| `ingress.ingressClassName` | `traefik` | Ingress class name. |
| `serviceAccount.create` | `false` | Create a dedicated ServiceAccount. |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount an API token in pods. |
| `networkPolicy.enabled` | `true` | Create the application NetworkPolicy. |
| `resources` | `{}` | Web resource requests and limits. |
| `podSecurityContext.runAsNonRoot` | `true` | Require a non-root process. |
| `securityContext.readOnlyRootFilesystem` | `true` | Use a read-only root filesystem. |

## More Information

- [Automatisch documentation](https://automatisch.io/docs)
- [Automatisch source](https://github.com/automatisch/automatisch)
- [HelmForge chart source](https://github.com/helmforgedev/charts/tree/main/charts/automatisch)
- [Configuration guide](docs/configuration.md)
- [Operations guide](docs/operations.md)
- [Security guide](docs/security.md)

### Security Scan: `automatisch`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **88.93939%** |

> Security posture acceptable.

<!-- @AI-METADATA
type: chart-readme
title: Automatisch Helm Chart
description: Production-oriented README for the Automatisch web and worker Helm chart

keywords: automatisch, automation, workflow, worker, postgresql, redis, helm, kubernetes

purpose: Document installation, architecture, configuration, security, and operations
scope: Chart

relations:
  - charts/automatisch/values.yaml
  - charts/automatisch/DESIGN.md
  - charts/automatisch/docs/configuration.md
  - charts/automatisch/docs/operations.md
  - charts/automatisch/docs/security.md
path: charts/automatisch/README.md
version: 2.0
date: 2026-10-24
-->
