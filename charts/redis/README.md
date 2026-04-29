# Redis

Redis for Kubernetes with support for `standalone`, `replication`, `sentinel`, and `cluster` architectures.

## Install

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install redis helmforge/redis -f values.yaml
```

### OCI registry

```bash
helm install redis oci://ghcr.io/helmforgedev/helm/redis -f values.yaml
```

## What this chart covers

- explicit architecture selection through `architecture`
- password authentication managed by the chart or through `existingSecret`
- persistence by topology
- optional metrics with `redis_exporter`
- optional `ServiceMonitor` for Prometheus Operator
- availability objects such as `PodDisruptionBudget`
- examples and CI scenarios separated by operational mode

## Supported architectures

| Architecture | When to use | Document |
|-------------|-------------|----------|
| `standalone` | development, simple environments, or workloads without HA requirements | [docs/standalone.md](docs/standalone.md) |
| `replication` | fixed primary with read replicas, without Sentinel failover | [docs/replication.md](docs/replication.md) |
| `sentinel` | automatic failover with primary discovery through Sentinel | [docs/sentinel.md](docs/sentinel.md) |
| `cluster` | native sharding and high availability through Redis Cluster protocol | [docs/cluster.md](docs/cluster.md) |

## How to choose the architecture

- use `standalone` when operational simplicity matters more than HA
- use `replication` when you need separate write and read roles, but automatic primary promotion is not required
- use `sentinel` when the client can talk to Redis Sentinel and you need primary discovery and failover
- use `cluster` when the client supports Redis Cluster and you need real horizontal sharding

Recommended reading before installation:

- [Standalone](docs/standalone.md)
- [Replication](docs/replication.md)
- [Sentinel](docs/sentinel.md)
- [Cluster](docs/cluster.md)

## Official product references

- Redis Sentinel: <https://redis.io/docs/latest/operate/oss_and_stack/management/sentinel/>
- Redis Cluster: <https://redis.io/docs/latest/operate/oss_and_stack/management/scaling/>

## Features

- password authentication with `existingSecret`
- persistence by architecture
- topology-specific services
- dedicated `StatefulSet` resources for stateful modes
- cluster bootstrap through `Job`
- optional metrics with `redis_exporter`
- optional `ServiceMonitor` integration

## Operational requirements

- a valid storage class for environments with persistence
- clients compatible with the selected architecture
- `existingSecret` when credentials are managed outside the chart
- careful affinity and pod distribution in HA modes

## Quick start

Minimal example with a secret-managed password:

```yaml
architecture: standalone

auth:
  enabled: true
  existingSecret: redis-auth
  existingSecretPasswordKey: redis-password

standalone:
  persistence:
    enabled: true
    size: 8Gi
```

Apply:

```bash
helm install redis helmforge/redis -f redis-values.yaml
```

## Best practices

### Security

- prefer `auth.enabled=true`
- in production, use `auth.existingSecret` instead of inline passwords
- enable TLS only when certificate material is already defined
- restrict port exposure to the minimum necessary

### Persistence

- use persistent volumes for all relevant stateful architectures
- treat `cluster` and `sentinel` as production topologies, not ephemeral test modes
- align volume sizing with real retention and load expectations

### Scheduling

- enable anti-affinity for `replication`, `sentinel`, and `cluster`
- enable `pdb.enabled=true` in HA modes
- spread pods with `topologySpreadConstraints` when supported by the cluster

### Observability

- enable `metrics.enabled=true` in monitored environments
- enable `metrics.serviceMonitor.enabled=true` with Prometheus Operator
- monitor latency, memory usage, replication lag, and cluster state

## Security patterns

- prefer `auth.existingSecret` in production
- avoid exposing Redis outside the cluster network without a strong reason
- use external `NetworkPolicy` or equivalent cluster controls when applicable
- combine requests/limits, anti-affinity, and PDB for better maintenance resilience

## Operations by architecture

- `standalone`: lowest operational cost, no failover
- `replication`: one fixed primary with read replicas
- `sentinel`: automatic failover for Sentinel-compatible clients
- `cluster`: sharding and high availability through Redis Cluster

Each mode has different client, failover, discovery, and scaling contracts. Choose the topology for the application behavior you need, not just for the desire to have HA.

## Main values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `architecture` | `standalone`, `replication`, `sentinel`, `cluster` | `standalone` |
| `image.repository` | Redis image repository | `redis` |
| `image.tag` | Redis image tag | `8.6.0` |
| `auth.enabled` | Enable password auth | `true` |
| `auth.password` | Redis password | `""` |
| `auth.existingSecret` | Existing auth secret | `""` |
| `auth.existingSecretPasswordKey` | Secret key used for the password | `redis-password` |
| `tls.enabled` | Enable TLS | `false` |
| `standalone.persistence.enabled` | Enable persistence for standalone | `true` |
| `replication.replicaCount` | Number of replica pods | `2` |
| `sentinel.replicaCount` | Number of Sentinel pods | `3` |
| `sentinel.quorum` | Sentinel quorum | `2` |
| `cluster.nodes` | Number of Redis Cluster nodes | `6` |
| `cluster.replicasPerMaster` | Replicas per master in cluster bootstrap | `1` |
| `metrics.enabled` | Enable redis exporter sidecar | `false` |
| `metrics.serviceMonitor.enabled` | Enable ServiceMonitor | `false` |
| `pdb.enabled` | Enable PodDisruptionBudget | `false` |

## CI scenarios

The `ci/` scenarios validate specific behaviors:

- `standalone.yaml`
- `replication.yaml`
- `sentinel.yaml`
- `cluster.yaml`
- `existing-secret.yaml`
- `metrics.yaml`

## Examples

See `examples/`:

- `standalone-simple.yaml`
- `replication-production.yaml`
- `cluster.yaml`

## Important notes

- `replication` and `sentinel` are different operational contracts
- `cluster` requires a Redis Cluster-compatible client
- if `auth.password` is not set and `auth.existingSecret` is not used, the chart generates a password automatically
- for production operation, read the architecture document before installing

<!-- @AI-METADATA
type: chart-readme
title: Redis Helm Chart
description: Redis chart with standalone, replication, sentinel, cluster architectures

keywords: redis, cache, in-memory, replication, sentinel, cluster

purpose: Usage guide for the Redis Helm chart with standalone, replication, sentinel, and cluster modes
scope: Chart

relations:
  - charts/redis/DESIGN.md
  - charts/redis/docs/standalone.md
  - charts/redis/docs/replication.md
  - charts/redis/docs/sentinel.md
  - charts/redis/docs/cluster.md
path: charts/redis/README.md
version: 1.0
date: 2026-03-20
-->
