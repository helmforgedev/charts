<!-- SPDX-License-Identifier: Apache-2.0 -->
# Flowise

A production-oriented Helm chart for deploying
[Flowise](https://flowiseai.com/) with a simple standalone topology or scalable
queue workers backed by PostgreSQL, Redis, and S3-compatible storage.

## Features

- Official `docker.io/flowiseai/flowise` image pinned to version 3.1.3.
- Standalone SQLite mode with persistent local data for small installations.
- Queue mode with independently scalable main and worker Deployments.
- Optional HelmForge PostgreSQL and Redis subcharts or external services.
- Local and S3-compatible blob storage.
- Ingress and Gateway API exposure with a named Service targetPort.
- Configurable Flowise process port, verified in a behavioral k3d scenario.
- Default non-root execution, read-only root filesystem, RuntimeDefault seccomp,
  dropped capabilities, disabled API token mounting, and NetworkPolicy.
- Existing Secret support for application, database, Redis, storage, and backup
  credentials, plus External Secrets Operator integration.
- Scheduled PostgreSQL backups to S3-compatible object storage.
- JSON Schema validation, Helm unit tests, examples, and runtime smoke tests.

## Installation

From the HTTPS repository:

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install flowise helmforge/flowise
```

From the OCI registry:

```bash
helm install flowise oci://ghcr.io/helmforgedev/helm/flowise
```

Wait for the server and test the upstream health endpoint:

```bash
kubectl wait --for=condition=available deployment/flowise --timeout=300s
kubectl port-forward service/flowise 3000:3000
curl -fsS http://127.0.0.1:3000/api/v1/ping
```

Resource names include the Helm release name when it differs from the chart
name. Use `kubectl get deploy,service -l app.kubernetes.io/instance=flowise` to
discover the exact names.

## Architecture

### Standalone mode

Standalone is the default. One Flowise server uses SQLite and local blob storage
on a PVC mounted at `/home/node/.flowise`. SQLite or local storage restricts the
main Deployment to one replica. This topology is suitable for evaluation,
personal use, and smaller installations where a single availability zone is
acceptable.

### Queue mode

Queue mode separates HTTP handling from asynchronous prediction work. Main pods
enqueue work in Redis and worker pods process it. Main and worker pods share
PostgreSQL state and S3-compatible blob storage. The chart rejects queue mode
unless all required services are configured and local persistence is disabled.

Upstream recommends queue mode for production. See
[`examples/queue-s3.yaml`](examples/queue-s3.yaml) and the
[architecture guide](docs/architecture.md).

## Configuration

The following values describe the primary decisions. The complete contract,
including types and constraints, is in [`values.yaml`](values.yaml) and
[`values.schema.json`](values.schema.json).

| Key | Default | Description |
|---|---|---|
| `architecture.mode` | `standalone` | `standalone` or `queue` topology |
| `flowise.replicaCount` | `1` | Number of main Flowise replicas |
| `flowise.containerPort` | `3000` | Port listened on by the Flowise process |
| `flowise.logPath` | `/home/node/.flowise/logs` | Writable application log directory |
| `database.mode` | `auto` | Resolve SQLite, external DB, or bundled PostgreSQL |
| `postgresql.enabled` | `false` | Deploy the HelmForge PostgreSQL dependency |
| `redis.enabled` | `false` | Deploy the HelmForge Redis dependency |
| `queue.worker.replicaCount` | `1` | Worker replicas in queue mode |
| `storage.type` | `local` | `local` or `s3` blob storage |
| `persistence.enabled` | `true` | Create a PVC for local Flowise data |
| `persistence.mountPath` | `/home/node/.flowise` | Writable Flowise data mount |
| `service.port` | `3000` | Kubernetes Service port, independent of process port |
| `networkPolicy.enabled` | `true` | Create main and worker isolation policies |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount a Kubernetes API token |
| `backup.enabled` | `false` | Schedule PostgreSQL backups to object storage |

Do not set `service.port` when the intent is to change the Flowise listener.
Set `flowise.containerPort`; the Service continues to target the named `http`
port. See the [configuration guide](docs/configuration.md) for external database,
Secret, networking, and port examples.

## Examples

Standalone with an Ingress:

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: flowise.example.com
      paths:
        - path: /
          pathType: Prefix
auth:
  existingSecret: flowise-auth
```

Queue mode with bundled datastores and an existing S3 Secret:

```yaml
architecture:
  mode: queue
flowise:
  replicaCount: 2
queue:
  worker:
    replicaCount: 4
postgresql:
  enabled: true
redis:
  enabled: true
persistence:
  enabled: false
storage:
  type: s3
  s3:
    bucketName: flowise
    endpointUrl: https://s3.example.com
    existingSecret: flowise-s3
```

Reusable files are available in [`examples/`](examples/):

- [`standalone.yaml`](examples/standalone.yaml)
- [`queue-s3.yaml`](examples/queue-s3.yaml)
- [`production.yaml`](examples/production.yaml)

## Security

The official 3.1.3 image defaults to root, but contains the `node` user as UID
and GID 1000. The chart deliberately runs it as that non-root identity. The root
filesystem is read-only; writable application data and `/tmp` are explicit
volumes. A dedicated ServiceAccount is created without an automatically mounted
API token.

The main NetworkPolicy admits the configured Flowise listener and the worker
policy denies all inbound traffic. Egress is open by default because Flowise
connects to operator-selected model providers, databases, Redis, and object
storage. Restrict `networkPolicy.egress` only after enumerating those endpoints.

Flowise includes nodes that can execute code or invoke external tools. Treat
administrative access as privileged, keep upstream HTTP and custom MCP security
checks enabled, and do not inject cluster-wide or cloud-admin credentials into
the pod. Read the [security guide](docs/security.md) before public exposure.

### Security Scan: `flowise`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **90.91%** |

> Security posture acceptable.

## Operations

Use `/api/v1/ping` for external monitoring. Probe timings are independently
configurable. Logs are available through `kubectl logs` and are also written to
the persistent data path. Queue mode requires monitoring both the main and
worker Deployments as well as PostgreSQL, Redis, and object storage.

PostgreSQL backups use a CronJob and S3-compatible target. Extra `pg_dump`
arguments are an array so the shell never evaluates operator input. Restoration
is intentionally manual. See [backup and restore](docs/backup-and-restore.md)
and [operations](docs/operations.md).

## Troubleshooting

Inspect all Flowise resources and recent logs:

```bash
kubectl get all,pvc,networkpolicy -l app.kubernetes.io/instance=flowise
kubectl describe deployment -l app.kubernetes.io/instance=flowise
kubectl logs deployment/flowise --all-containers --tail=200
```

If the default pod is not writable, confirm the storage class honors `fsGroup`
and that any existing volume content is accessible to UID/GID 1000. Queue mode
validation failures normally identify the missing database, Redis, S3, or
persistence setting directly. For application-level startup failures, verify
that external service hostnames are resolvable from the namespace.

## Documentation

- [Configuration reference](docs/configuration.md)
- [Architecture](docs/architecture.md)
- [Operations](docs/operations.md)
- [Security](docs/security.md)
- [Backup and restore](docs/backup-and-restore.md)
- [Chart design decisions](DESIGN.md)

<!-- @AI-METADATA
type: chart-readme
title: Flowise
description: Installation, architecture, security, and operations for the Flowise Helm chart
keywords: flowise, ai, llm, agents, redis, postgresql, sqlite, s3, helm
purpose: User-facing chart documentation and entrypoint to detailed guides
scope: Chart
relations:
  - charts/flowise/DESIGN.md
  - charts/flowise/docs/architecture.md
  - charts/flowise/docs/configuration.md
  - charts/flowise/docs/operations.md
  - charts/flowise/docs/security.md
  - charts/flowise/docs/backup-and-restore.md
path: charts/flowise/README.md
version: 2.0
date: 2026-10-24
-->
